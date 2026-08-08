import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:logger/logger.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../config/app_config.dart';
import 'model_image_preprocessor.dart';

/// Coordina el modelo TensorFlow Lite que clasifica instrumentos localmente.
///
/// Carga el intérprete y sus etiquetas, valida que ambos sean compatibles,
/// transforma las imágenes al tensor esperado y ordena las predicciones. Se
/// comparte una sola instancia para no duplicar el modelo en memoria.
class TFLiteService {
  // Instancia única utilizada por toda la aplicación.
  static final TFLiteService _instance = TFLiteService._internal();

  // Motor nativo que ejecuta el modelo; es nulo antes de inicializar o después
  // de liberar el servicio.
  Interpreter? _interpreter;

  // Cada posición debe corresponder al mismo índice del vector de salida.
  List<String> _labels = [];

  // El Future pendiente evita que varias pantallas carguen el modelo a la vez.
  bool _isInitialized = false;
  Future<void>? _initializationFuture;

  // Dependencias internas para diagnóstico y adaptación de las imágenes.
  final Logger _logger = Logger();
  final ModelImagePreprocessor _preprocessor = const ModelImagePreprocessor();

  // Etiquetas en orden alfabético (coinciden con labels.txt y el modelo)
  // IMPORTANTE: El orden DEBE coincidir con el modelo entrenado
  static const List<String> _defaultLabels = [
    'Buretas', // Dosificación volumétrica (índice 0)
    'Crisoles', // Calentamiento y fusión (índice 1)
    'Embudos', // Transferencia de líquidos (índice 2)
    'Gradillas', // Organización y soporte (índice 3)
    'Matraces', // Contenedores volumétricos (índice 4)
    'Microscopio', // Instrumentos ópticos (índice 5)
    'Pinzas', // Sujeción y manipulación (índice 6)
    'Pipetas', // Medición precisa de líquidos (índice 7)
    'Probeta', // Medición de volúmenes (índice 8)
    'Vasos de precipitado', // Contenedores de reacción (índice 9)
  ];

  factory TFLiteService() {
    return _instance;
  }

  TFLiteService._internal();

  /// Indica si el modelo superó la carga y la validación de contrato.
  bool get isInitialized => _isInitialized;

  /// Etiquetas asociadas, en orden, a las posiciones de salida del modelo.
  List<String> get labels => _labels;

  /// Inicializa TensorFlow Lite y comparte una inicialización que ya esté activa.
  ///
  /// No vuelve a cargar un servicio listo. Si la carga falla, el mismo error se
  /// propaga al llamador y una llamada futura podrá volver a intentarlo.
  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.i('TFLite ya está inicializado');
      return;
    }

    final pendingInitialization = _initializationFuture;
    if (pendingInitialization != null) {
      return pendingInitialization;
    }

    final initialization = _initialize();
    _initializationFuture = initialization;

    try {
      await initialization;
    } finally {
      _initializationFuture = null;
    }
  }

  /// Ejecuta la carga real y deja el servicio listo solo al completar cada paso.
  /// Ante un error cierra cualquier intérprete parcial y conserva las etiquetas
  /// predeterminadas como información de respaldo para la interfaz.
  Future<void> _initialize() async {
    try {
      _logger.i('Inicializando TensorFlow Lite...');

      // Punto central para configurar optimizaciones del intérprete móvil.
      final interpreterOptions = InterpreterOptions();

      // La ruta del recurso está centralizada en AppConfig.
      _interpreter = await Interpreter.fromAsset(AppConfig.modelPath,
          options: interpreterOptions);

      // La forma se registra para diagnosticar modelos exportados incorrectamente.
      _logger.i('Modelo cargado, verificando forma de entrada...');
      final inputShape = _interpreter!.getInputTensors()[0].shape;
      _logger.i('Forma de entrada del modelo: $inputShape');

      // Las etiquetas deben cargarse antes de validar el tamaño de la salida.
      await _loadLabels();
      _validateModelContract();

      _isInitialized = true;
      _logger.i('TFLite inicializado con ${_labels.length} clases');
    } catch (e, stackTrace) {
      _logger.e('Error inicializando TFLite: $e');
      _logger.e('Stack trace: $stackTrace');

      _interpreter?.close();
      _interpreter = null;
      _labels = _defaultLabels;
      _isInitialized = false;
      _logger.w('Usando etiquetas por defecto');
      rethrow;
    }
  }

  /// Comprueba el contrato crítico entre la aplicación y el archivo `.tflite`.
  ///
  /// La entrada debe ser un lote RGB `float32` del tamaño configurado y la
  /// última dimensión de salida debe coincidir con el número de etiquetas.
  void _validateModelContract() {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('El intérprete TFLite no está disponible');
    }

    final inputTensor = interpreter.getInputTensors().first;
    final outputTensor = interpreter.getOutputTensors().first;
    final expectedInputShape = [
      1,
      AppConfig.modelInputSize,
      AppConfig.modelInputSize,
      3,
    ];

    if (!_sameShape(inputTensor.shape, expectedInputShape)) {
      throw StateError(
        'Forma de entrada incompatible: ${inputTensor.shape}; '
        'se esperaba $expectedInputShape',
      );
    }

    if (inputTensor.type != TensorType.float32) {
      throw StateError(
        'Tipo de entrada incompatible: ${inputTensor.type}; '
        'se esperaba float32',
      );
    }

    if (outputTensor.shape.isEmpty ||
        outputTensor.shape.last != _labels.length) {
      throw StateError(
        'El modelo produce ${outputTensor.shape} pero existen '
        '${_labels.length} etiquetas',
      );
    }
  }

  /// Compara dimensiones en orden exacto, incluido el tamaño del lote.
  bool _sameShape(List<int> actual, List<int> expected) {
    if (actual.length != expected.length) return false;
    for (var index = 0; index < actual.length; index++) {
      if (actual[index] != expected[index]) return false;
    }
    return true;
  }

  /// Carga y normaliza las etiquetas declaradas en los recursos de Flutter.
  /// Si el recurso no está disponible, usa [_defaultLabels] y no interrumpe la
  /// inicialización; la validación posterior confirmará si su cantidad coincide.
  Future<void> _loadLabels() async {
    try {
      final labelsContent = await rootBundle.loadString(AppConfig.labelsPath);
      final labelsList = labelsContent.trim().split('\n');

      // Convierte el formato técnico del archivo en nombres legibles.
      _labels =
          labelsList.map((label) => _capitalizeLabel(label.trim())).toList();

      _logger.i('Etiquetas cargadas desde archivo: ${_labels.length}');
      for (int i = 0; i < _labels.length; i++) {
        _logger.d('  [$i] ${_labels[i]}');
      }
    } catch (e) {
      _logger.w('No se pudieron cargar etiquetas desde archivo: $e');
      _logger.i('Usando etiquetas por defecto');
      _labels = _defaultLabels;
    }
  }

  /// Convierte una etiqueta técnica a estilo oración para mostrarla al usuario.
  ///
  /// Por ejemplo, transforma `vasos_precipitado` en `Vasos de precipitado`.
  /// Devuelve una cadena vacía si la etiqueta solo contiene espacios.
  String _capitalizeLabel(String label) {
    final normalized = label.replaceAll('_', ' ').trim().toLowerCase();
    if (normalized.isEmpty) return normalized;
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  /// Clasifica una imagen y devuelve todas las predicciones por confianza.
  ///
  /// Requiere haber completado [initialize]. Preprocesa los bytes, ejecuta una
  /// inferencia de lote único y convierte la salida en [PredictionResult]. Los
  /// errores se registran y se propagan para que la interfaz decida cómo actuar.
  Future<List<PredictionResult>> predict(Uint8List imageBytes) async {
    // Evita acceder a un intérprete inexistente o cerrado.
    if (!_isInitialized || _interpreter == null) {
      throw Exception('TFLite no está inicializado');
    }

    try {
      _logger.i('Iniciando predicción');
      _logger.i('Tamaño de imagen: ${imageBytes.length} bytes');
      _logger.i('Clases disponibles: ${_labels.length}');

      // 1. Convertir la imagen al tensor RGB normalizado que espera la red.
      _logger.i('Preprocesando imagen');
      final input = _preprocessor.preprocess(imageBytes);

      // 2. Reservar un vector de salida por cada clase para un lote de una imagen.
      var output = List<List<double>>.generate(
        1, // Tamaño de lote: una imagen a la vez.
        (index) => List<double>.filled(
            _labels.length, 0.0), // Una puntuación por etiqueta.
      );

      // 3. Ejecutar la inferencia; el intérprete escribe sobre `output`.
      _logger.i('Ejecutando modelo');
      _interpreter!.run(input, output);

      // 4. Normalizar y ordenar las puntuaciones producidas por el modelo.
      _logger.i('Procesando resultados');
      final predictions = _processOutput(output[0]);

      _logger.i('Predicción completada exitosamente');

      return predictions;
    } catch (e, stackTrace) {
      _logger.e('Error en predicción: $e');
      _logger.e('Stack trace: $stackTrace');
      rethrow; // La capa que inició el análisis decide el mensaje al usuario.
    }
  }

  /// Convierte la salida cruda del modelo en predicciones utilizables.
  ///
  /// Acepta probabilidades ya normalizadas o puntuaciones libres. En el segundo
  /// caso aplica softmax, limita cada confianza al intervalo válido y ordena de
  /// mayor a menor. Lanza una excepción si el vector está vacío.
  List<PredictionResult> _processOutput(List<double> output) {
    try {
      final results = <PredictionResult>[];

      // Una muestra corta permite diagnosticar el modelo sin saturar el registro.
      _logger.d('Output bruto del modelo (primeros 5 valores):');
      for (int i = 0; i < output.length && i < 5; i++) {
        _logger.d('  [$i] ${output[i]}');
      }

      if (output.isEmpty) {
        throw Exception('Output del modelo está vacío');
      }

      // La suma y el rango revelan si la salida ya representa probabilidades.
      final sum = output.fold<double>(0.0, (a, b) => a + b.abs());
      _logger.d('Suma de valores de confianza: $sum');

      final probabilitySum = output.fold<double>(0.0, (a, b) => a + b);
      final hasValuesOutsideProbabilityRange =
          output.any((value) => value < 0 || value > 1);
      final needsSoftmax = hasValuesOutsideProbabilityRange ||
          (probabilitySum - 1.0).abs() > 0.01;
      if (needsSoftmax) {
        _logger.w('Output no normalizado. Aplicando softmax...');
      }

      // Softmax convierte puntuaciones libres en probabilidades que suman uno.
      final normalized = needsSoftmax ? _applySoftmax(output) : output;

      // Solo se crean resultados con una etiqueta correspondiente.
      for (int i = 0; i < normalized.length && i < _labels.length; i++) {
        results.add(PredictionResult(
          label: _labels[i],
          confidence: normalized[i].clamp(0.0, 1.0),
          index: i,
        ));
      }

      // Este orden permite que `take(topN)` seleccione luego los mejores datos.
      results.sort((a, b) => b.confidence.compareTo(a.confidence));

      // Tabla textual de diagnóstico; no se muestra en la interfaz.
      _logger.i('═══════════════════════════════════════');
      _logger.i('PREDICCIONES (ordenadas por confianza):');
      _logger.i('═══════════════════════════════════════');
      for (int i = 0; i < results.length; i++) {
        final r = results[i];
        final percent = (r.confidence * 100).toStringAsFixed(1);
        final bar = '█' * ((r.confidence * 20).toInt());
        _logger.i('${i + 1}. ${r.label.padRight(20)} $percent% $bar');
      }
      _logger.i('═══════════════════════════════════════');

      return results;
    } catch (e) {
      _logger.e('Error procesando output: $e');
      rethrow;
    }
  }

  /// Aplica softmax a un vector para obtener probabilidades que suman uno.
  ///
  /// Resta el valor máximo antes de exponenciar para evitar desbordamiento
  /// numérico. Si algo falla, usa una normalización absoluta como respaldo.
  List<double> _applySoftmax(List<double> input) {
    try {
      // Restar el máximo mantiene los exponentes en un intervalo estable.
      final maxVal = input.reduce((a, b) => a > b ? a : b);

      final expValues = input.map((x) => math.exp(x - maxVal)).toList();
      final sum = expValues.fold<double>(0.0, (a, b) => a + b);

      return expValues.map((x) => x / sum).toList();
    } catch (e) {
      _logger.e('Error en softmax: $e');
      // Respaldo que también garantiza valores no negativos.
      final sum = input.fold<double>(0.0, (a, b) => a + b.abs());
      if (sum > 0) {
        return input.map((x) => x.abs() / sum).toList();
      }
      return input;
    }
  }

  /// Filtra por confianza mínima y devuelve como máximo las primeras [topN].
  /// Presupone que [predictions] ya está ordenada de mayor a menor confianza.
  List<PredictionResult> getTopPredictions(
    List<PredictionResult> predictions, {
    int topN = 3, // Cantidad máxima de resultados.
    double confidenceThreshold = 0.0, // Confianza mínima aceptada.
  }) {
    return predictions
        .where((p) => p.confidence >= confidenceThreshold)
        .take(topN)
        .toList();
  }

  /// Cierra el intérprete nativo y marca el servicio como no inicializado.
  /// Debe llamarse al terminar su uso para evitar retener memoria del modelo.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    _logger.i('TFLite disposed - Recursos liberados');
  }
}

/// Resultado inmutable de una clase candidata producida por el modelo.
class PredictionResult {
  /// Nombre legible del instrumento identificado.
  final String label;

  /// Probabilidad normalizada entre `0.0` y `1.0`.
  final double confidence;

  /// Posición de esta clase en el vector de salida del modelo.
  final int index;

  const PredictionResult({
    required this.label,
    required this.confidence,
    required this.index,
  });

  /// Confianza truncada como porcentaje entero entre 0 y 100.
  int get confidencePercentage => (confidence * 100).toInt();

  /// Clasificación cualitativa usada por la interfaz.
  String get confidenceLevel {
    if (confidence >= 0.8) return 'Alta';
    if (confidence >= 0.5) return 'Media';
    return 'Baja';
  }

  @override
  String toString() {
    return '$label: ${(confidence * 100).toStringAsFixed(1)}% ($confidenceLevel)';
  }
}

/// Excepción de dominio para comunicar fallos propios de TensorFlow Lite.
class TFLiteException implements Exception {
  /// Descripción legible del fallo.
  final String message;
  TFLiteException(this.message);

  @override
  String toString() => 'TFLiteException: $message';
}
