import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../config/app_config.dart';

// Servicio principal para integración con TensorFlow Lite
// Gestiona la carga del modelo de IA, preprocesamiento de imágenes
// y ejecución de inferencias para clasificación de instrumentos
class TFLiteService {
  // Singleton pattern: una sola instancia para toda la aplicación
  // Evita cargar múltiples modelos en memoria
  static final TFLiteService _instance = TFLiteService._internal();

  // Referencia al intérprete de TensorFlow Lite
  // Es el objeto principal que ejecuta el modelo
  Interpreter? _interpreter;

  // Lista de etiquetas/clases que el modelo puede predecir
  // Se mapean con los índices de salida del modelo
  List<String> _labels = [];

  // Flag para saber si el servicio está listo para usar
  bool _isInitialized = false;

  // Logger para debugging y monitoreo
  final Logger _logger = Logger();

  // Etiquetas en orden alfabético (coinciden con labels.txt y el modelo)
  // IMPORTANTE: El orden DEBE coincidir con el modelo entrenado
  static const List<String> _defaultLabels = [
    'Buretas',              // Dosificación volumétrica (índice 0)
    'Crisoles',             // Calentamiento y fusión (índice 1)
    'Embudos',              // Transferencia de líquidos (índice 2)
    'Gradillas',            // Organización y soporte (índice 3)
    'Matraces',             // Contenedores volumétricos (índice 4)
    'Microscopio',          // Instrumentos ópticos (índice 5)
    'Pinzas',               // Sujeción y manipulación (índice 6)
    'Pipetas',              // Medición precisa de líquidos (índice 7)
    'Probeta',              // Medición de volúmenes (índice 8)
    'Vasos de precipitado', // Contenedores de reacción (índice 9)
  ];

  // Constructor factory para singleton
  factory TFLiteService() {
    return _instance;
  }

  // Constructor privado para singleton
  TFLiteService._internal();

  // Getters públicos para acceder al estado
  bool get isInitialized => _isInitialized;
  List<String> get labels => _labels;

  /// Inicializa el servicio de TensorFlow Lite
  /// Carga el modelo, configura el intérprete y prepara las etiquetas
  /// Este método es asíncrono porque la carga del modelo puede tomar tiempo
  Future<void> initialize() async {
    // Evita inicialización duplicada
    if (_isInitialized) {
      _logger.i('TFLite ya está inicializado');
      return;
    }

    try {
      _logger.i('Inicializando TensorFlow Lite...');

      // Configuración del intérprete con opciones optimizadas
      // Estas opciones mejoran el rendimiento en dispositivos móviles
      final interpreterOptions = InterpreterOptions();

      // Cargar el modelo desde los assets de Flutter
      // El modelo debe estar en assets/models/instrument_model.tflite
      _interpreter = await Interpreter.fromAsset(AppConfig.modelPath, options: interpreterOptions);

      // Verificar que el modelo se cargó correctamente
      _logger.i('Modelo cargado, verificando forma de entrada...');
      final inputShape = _interpreter!.getInputTensors()[0].shape;
      _logger.i('Forma de entrada del modelo: $inputShape');

      // Cargar etiquetas
      await _loadLabels();

      _isInitialized = true;
      _logger.i('✅ TFLite inicializado con ${_labels.length} clases');
    } catch (e, stackTrace) {
      _logger.e('❌ Error inicializando TFLite: $e');
      _logger.e('Stack trace: $stackTrace');

      // Fallback: usar etiquetas por defecto
      _labels = _defaultLabels;
      _isInitialized = true;
      _logger.w('⚠️  Usando etiquetas por defecto');
      rethrow; // Re-lanzar el error para que el splash lo maneje
    }
  }

  /// Carga etiquetas desde archivo
  Future<void> _loadLabels() async {
    try {
      // Cargar desde el archivo configurado en AppConfig
      final labelsContent = await rootBundle.loadString(AppConfig.labelsPath);
      final labelsList = labelsContent.trim().split('\n');
      
      // Capitalizar correctamente (primera letra mayúscula del instrumento)
      _labels = labelsList
          .map((label) => _capitalizeLabel(label.trim()))
          .toList();
      
      _logger.i('✅ Etiquetas cargadas desde archivo: ${_labels.length}');
      for (int i = 0; i < _labels.length; i++) {
        _logger.d('  [$i] ${_labels[i]}');
      }
    } catch (e) {
      _logger.w('⚠️  No se pudieron cargar etiquetas desde archivo: $e');
      _logger.i('Usando etiquetas por defecto');
      _labels = _defaultLabels;
    }
  }

  /// Capitaliza correctamente los nombres de instrumentos
  /// Convierte "vasos_precipitado" → "Vasos de precipitado"
  String _capitalizeLabel(String label) {
    return label
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty 
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : word)
        .join(' ');
  }

  /// Realiza predicción en una imagen usando el modelo de IA
  /// Este es el método principal que ejecuta la clasificación
  /// Recibe bytes de imagen y devuelve lista de predicciones ordenadas por confianza
  Future<List<PredictionResult>> predict(Uint8List imageBytes) async {
    // Validación: asegurar que el servicio esté inicializado
    if (!_isInitialized || _interpreter == null) {
      throw Exception('TFLite no está inicializado');
    }

    try {
      _logger.i('🔍 Iniciando predicción...');
      _logger.i('   📊 Tamaño de imagen: ${imageBytes.length} bytes');
      _logger.i('   🏷️  Clases disponibles: ${_labels.length}');

      // Paso 1: Preprocesar la imagen para el modelo
      // Convierte la imagen al formato esperado por la red neuronal
      _logger.i('   ⚙️  Preprocesando imagen...');
      final input = _prepareInput(imageBytes);

      // Paso 2: Preparar el buffer de salida
      // El modelo devuelve un vector de probabilidades (una por clase)
      // Creamos un array 2D: [1][número_de_clases]
      var output = List<List<double>>.generate(
        1, // batch size = 1 (una imagen a la vez)
        (index) => List<double>.filled(_labels.length, 0.0), // vector de probabilidades
      );

      // Paso 3: Ejecutar la inferencia
      // El modelo procesa la imagen y llena el vector output con probabilidades
      _logger.i('   🧠 Ejecutando modelo...');
      _interpreter!.run(input, output);

      // Paso 4: Procesar los resultados crudos
      // Convertir probabilidades en objetos PredictionResult ordenados
      _logger.i('   📈 Procesando resultados...');
      final predictions = _processOutput(output[0]);

      _logger.i('✅ Predicción completada exitosamente');

      return predictions;
    } catch (e, stackTrace) {
      _logger.e('❌ Error en predicción: $e');
      _logger.e('Stack trace: $stackTrace');
      rethrow; // Re-lanzar para que el caller maneje el error
    }
  }

  /// Prepara la imagen para el modelo de IA
  /// Convierte la imagen al formato esperado por la red neuronal
  /// El modelo espera: [1, 224, 224, 3] (batch, height, width, channels)
  List<List<List<List<double>>>> _prepareInput(Uint8List imageBytes) {
    try {
      // Decodificar la imagen desde bytes a objeto Image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('No se pudo decodificar la imagen');
      }

      _logger.d('Imagen original: ${image.width}x${image.height}');

      // Paso 1: Mejorar el redimensionamiento manteniendo aspect ratio
      // Calcular el tamaño manteniendo proporciones
      final aspectRatio = image.width / image.height;
      int targetWidth = 224;
      int targetHeight = 224;

      if (aspectRatio > 1) {
        // Imagen más ancha que alta
        targetHeight = (224 / aspectRatio).round();
      } else {
        // Imagen más alta que ancha
        targetWidth = (224 * aspectRatio).round();
      }

      // Redimensionar manteniendo proporciones
      img.Image resizedImage = img.copyResize(
        image,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.cubic, // Mejor interpolación
      );

      // Crear canvas de 224x224 y centrar la imagen
      img.Image canvas = img.Image(width: 224, height: 224);
      img.fill(canvas, color: img.ColorRgb8(128, 128, 128)); // Fondo gris

      // Calcular posición para centrar
      final x = ((224 - targetWidth) / 2).round();
      final y = ((224 - targetHeight) / 2).round();

      // Copiar imagen redimensionada al centro del canvas
      img.compositeImage(canvas, resizedImage, dstX: x, dstY: y);

      _logger.d('Imagen procesada: ${canvas.width}x${canvas.height}');

      // Paso 2: Convertir a RGB si es necesario
      if (canvas.numChannels < 3) {
        canvas = img.Image.from(canvas);
      }

      // Paso 3: Normalización correcta para MobileNetV2
      // MobileNetV2 espera valores entre -1 y 1, no 0-1
      final input = List<List<List<List<double>>>>.generate(
        1, // batch size = 1
        (b) => List<List<List<double>>>.generate(
          224, // height
          (h) => List<List<double>>.generate(
            224, // width
            (w) {
              final pixel = canvas.getPixelSafe(w, h);

              // Normalización MobileNetV2: (pixel/127.5) - 1
              // Esto convierte 0-255 a -1 a 1
              return [
                (pixel.r / 127.5) - 1.0,  // Canal Rojo
                (pixel.g / 127.5) - 1.0,  // Canal Verde
                (pixel.b / 127.5) - 1.0,  // Canal Azul
              ];
            },
          ),
        ),
      );

      _logger.d('Tensor preparado con normalización MobileNetV2');

      return input;
    } catch (e) {
      _logger.e('Error preparando input: $e');
      rethrow;
    }
  }

  /// Procesa la salida cruda del modelo y la convierte en predicciones útiles
  /// El modelo devuelve un vector de probabilidades, una por cada clase
  /// Esta función valida que sea correcto y lo convierte en objetos PredictionResult
  List<PredictionResult> _processOutput(List<double> output) {
    try {
      final results = <PredictionResult>[];

      // Log detallado del output bruto para debugging
      _logger.d('Output bruto del modelo (primeros 5 valores):');
      for (int i = 0; i < output.length && i < 5; i++) {
        _logger.d('  [$i] ${output[i]}');
      }

      // Validar que tengamos valores válidos
      if (output.isEmpty) {
        throw Exception('Output del modelo está vacío');
      }

      // Calcular suma para verificar normalización
      final sum = output.fold<double>(0.0, (a, b) => a + b.abs());
      _logger.d('Suma de valores de confianza: $sum');

      // Si la suma es muy pequeña (<0.1), probablemente necesita softmax
      bool needsSoftmax = sum < 0.1;
      if (needsSoftmax) {
        _logger.w('⚠️  Output parece no normalizado. Aplicando softmax...');
      }

      // Paso 1: Aplicar softmax si es necesario
      // Softmax convierte cualquier vector a probabilidades que suman 1
      final normalized = needsSoftmax ? _applySoftmax(output) : output;

      // Paso 2: Convertir cada valor en un objeto PredictionResult
      for (int i = 0; i < normalized.length && i < _labels.length; i++) {
        results.add(PredictionResult(
          label: _labels[i],                         // Nombre de la clase
          confidence: normalized[i].clamp(0.0, 1.0), // Probabilidad entre 0-1
          index: i,                                  // Índice de la clase
        ));
      }

      // Paso 3: Ordenar por confianza descendente
      results.sort((a, b) => b.confidence.compareTo(a.confidence));

      // Log con mejor formato
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

  /// Aplica la función softmax a un vector de números
  /// Softmax: e^x / sum(e^x) - convierte a probabilidades que suman 1
  List<double> _applySoftmax(List<double> input) {
    try {
      // Paso 1: Encontrar el máximo para estabilidad numérica
      final maxVal = input.reduce((a, b) => a > b ? a : b);

      // Paso 2: Calcular e^(x - max) y sumar
      final expValues = input.map((x) => math.exp(x - maxVal)).toList();
      final sum = expValues.fold<double>(0.0, (a, b) => a + b);

      // Paso 3: Dividir cada valor por la suma
      return expValues.map((x) => x / sum).toList();
    } catch (e) {
      _logger.e('Error en softmax: $e');
      // Si falla, devolver el input normalizado simple
      final sum = input.fold<double>(0.0, (a, b) => a + b.abs());
      if (sum > 0) {
        return input.map((x) => x.abs() / sum).toList();
      }
      return input;
    }
  }

  /// Filtra y obtiene las mejores N predicciones
  /// Útil para mostrar solo las predicciones más relevantes al usuario
  List<PredictionResult> getTopPredictions(
    List<PredictionResult> predictions, {
    int topN = 3,                    // Número máximo de predicciones a devolver
    double confidenceThreshold = 0.0, // Umbral mínimo de confianza
  }) {
    return predictions
        .where((p) => p.confidence >= confidenceThreshold) // Filtrar por confianza
        .take(topN)                                       // Tomar solo las primeras N
        .toList();
  }

  /// Libera los recursos del modelo
  /// IMPORTANTE: Llamar cuando la app se cierre para evitar memory leaks
  void dispose() {
    _interpreter?.close();  // Cerrar el intérprete de TFLite
    _interpreter = null;
    _isInitialized = false;
    _logger.i('TFLite disposed - Recursos liberados');
  }
}

/// Modelo de datos para el resultado de una predicción individual
/// Representa una clasificación con su nivel de confianza
class PredictionResult {
  final String label;      // Nombre del instrumento identificado
  final double confidence; // Probabilidad entre 0.0 y 1.0
  final int index;         // Índice de la clase en el modelo

  const PredictionResult({
    required this.label,
    required this.confidence,
    required this.index,
  });

  /// Confianza como porcentaje (0-100)
  int get confidencePercentage => (confidence * 100).toInt();

  /// Nivel de confianza
  String get confidenceLevel {
    if (confidence >= 0.8) return 'Alta';
    if (confidence >= 0.5) return 'Media';
    return 'Baja';
  }

  /// Emoji de confianza
  String get confidenceEmoji {
    if (confidence >= 0.8) return '✅';
    if (confidence >= 0.5) return '⚠️';
    return '❌';
  }

  @override
  String toString() {
    return '$label: ${(confidence * 100).toStringAsFixed(1)}% ($confidenceLevel)';
  }
}

/// Excepciones personalizadas
class TFLiteException implements Exception {
  final String message;
  TFLiteException(this.message);

  @override
  String toString() => 'TFLiteException: $message';
}