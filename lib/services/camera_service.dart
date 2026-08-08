import 'package:camera/camera.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

/// Centraliza el acceso a la cámara física y al único controlador activo.
///
/// Se expone como instancia única porque dos controladores abiertos a la vez
/// pueden competir por el mismo recurso del dispositivo. Las pantallas deben
/// consultar [isInitialized] antes de usar [controller].
class CameraService {
  static final CameraService _instance = CameraService._internal();

  final Logger _logger = Logger();

  // El controlador solo se publica cuando terminó de inicializarse. La
  // operación pendiente se conserva para que llamadas simultáneas compartan
  // el mismo Future en lugar de intentar abrir la cámara varias veces.
  CameraController? _controller;
  Future<void>? _initializationFuture;

  factory CameraService() => _instance;

  CameraService._internal();

  /// Controlador actualmente disponible; puede ser nulo antes de [initialize]
  /// o después de [dispose].
  CameraController? get controller => _controller;

  /// Indica si el controlador está listo para mostrar vista previa y capturar.
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  /// Refleja el estado de grabación informado por el plugin de cámara.
  bool get isRecording => _controller?.value.isRecordingVideo ?? false;

  /// Inicializa una sola vez la cámara disponible y comparte el proceso en curso.
  ///
  /// El propio plugin solicita el permiso de Android. Solicitarlo también desde
  /// la aplicación hacía que el ciclo de vida liberara el controlador mientras
  /// el diálogo del sistema seguía visible en algunos dispositivos físicos. Se
  /// prefiere la cámara trasera, pero se usa la primera detectada si no existe.
  Future<void> initialize() async {
    if (isInitialized) return;

    final pendingInitialization = _initializationFuture;
    if (pendingInitialization != null) {
      return pendingInitialization;
    }

    final initialization = _initializeCamera();
    _initializationFuture = initialization;

    try {
      await initialization;
    } finally {
      if (identical(_initializationFuture, initialization)) {
        _initializationFuture = null;
      }
    }
  }

  /// Abre preferentemente la cámara trasera con una resolución compatible.
  ///
  /// Primero descarta cualquier controlador anterior. Cada intento utiliza un
  /// candidato local y solo lo asigna a [_controller] cuando está completamente
  /// listo, evitando que otra parte de la app use un controlador incompleto. Si
  /// no hay cámara trasera, continúa con la primera cámara reportada al sistema.
  Future<void> _initializeCamera() async {
    _logger.i('Inicializando cámara');
    await dispose();

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw StateError('No se encontraron cámaras disponibles');
    }

    final rearCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    Object? lastError;
    StackTrace? lastStackTrace;

    // Algunos dispositivos antiguos no abren de forma estable la resolución
    // alta. La resolución media conserva detalle suficiente para el modelo y
    // funciona como alternativa de compatibilidad.
    for (final preset in const [
      ResolutionPreset.high,
      ResolutionPreset.medium,
    ]) {
      CameraController? candidate;
      try {
        candidate = CameraController(
          rearCamera,
          preset,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );
        await candidate.initialize();
        await candidate.setFlashMode(FlashMode.off);

        _controller = candidate;
        _logger.i('Cámara inicializada con resolución ${preset.name}');
        return;
      } catch (error, stackTrace) {
        await candidate?.dispose();

        if (error is CameraException && _isPermissionError(error)) {
          Error.throwWithStackTrace(error, stackTrace);
        }

        lastError = error;
        lastStackTrace = stackTrace;
        _logger.w(
          'No se pudo usar la resolución ${preset.name}: $error',
        );
      }
    }

    final error =
        lastError ?? StateError('No se pudo inicializar la cámara trasera');
    Error.throwWithStackTrace(error, lastStackTrace ?? StackTrace.current);
  }

  /// Distingue errores que requieren acción del usuario. Estos errores no se
  /// reintentan con otra resolución porque el preset no puede resolverlos.
  bool _isPermissionError(CameraException error) {
    return error.code == 'CameraAccessDenied' ||
        error.code == 'CameraAccessDeniedWithoutPrompt' ||
        error.code == 'CameraAccessRestricted';
  }

  /// Abre los ajustes del sistema para que el usuario pueda conceder permisos.
  /// Devuelve si el sistema pudo abrir dicha pantalla.
  Future<bool> openSettings() => openAppSettings();

  /// Captura una fotografía preparada para el reconocimiento local.
  ///
  /// Antes de disparar desactiva el flash, activa enfoque y exposición
  /// automáticos y concede un breve tiempo al hardware para estabilizarse.
  /// Devuelve `null` si la cámara no está lista o si la captura falla.
  Future<XFile?> takePicture() async {
    final activeController = _controller;
    if (activeController == null || !activeController.value.isInitialized) {
      _logger.w('La cámara no está inicializada');
      return null;
    }

    try {
      await activeController.setFlashMode(FlashMode.off);
      await activeController.setFocusMode(FocusMode.auto);
      await activeController.setExposureMode(ExposureMode.auto);
      await Future<void>.delayed(const Duration(milliseconds: 350));

      final image = await activeController.takePicture();
      _logger.i('Foto capturada: ${image.path}');
      return image;
    } catch (error) {
      _logger.e('Error al capturar la foto: $error');
      return null;
    }
  }

  /// Cambia el modo del flash cuando el controlador está disponible.
  /// Los fallos del hardware se registran sin interrumpir la interfaz.
  Future<void> setFlashMode(FlashMode mode) async {
    final activeController = _controller;
    if (activeController == null || !activeController.value.isInitialized) {
      return;
    }

    try {
      await activeController.setFlashMode(mode);
    } catch (error) {
      _logger.e('Error al cambiar el flash: $error');
    }
  }

  /// Modo de flash informado por el controlador, o [FlashMode.off] si no existe.
  FlashMode get currentFlashMode {
    return _controller?.value.flashMode ?? FlashMode.off;
  }

  /// Alterna entre flash apagado y luz continua.
  Future<void> toggleFlash() async {
    final newMode =
        currentFlashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await setFlashMode(newMode);
  }

  /// Devuelve el zoom al mínimo admitido por la cámara activa.
  Future<void> resetZoom() async {
    final activeController = _controller;
    if (activeController == null || !activeController.value.isInitialized) {
      return;
    }

    try {
      final minZoom = await activeController.getMinZoomLevel();
      await activeController.setZoomLevel(minZoom);
    } catch (error) {
      _logger.e('Error al restablecer el zoom: $error');
    }
  }

  /// Obtiene los límites reales de zoom del dispositivo.
  ///
  /// Si no hay cámara disponible o el plugin falla, devuelve un intervalo
  /// neutro de `1.0` a `1.0` para que la interfaz pueda permanecer operativa.
  Future<Map<String, double>> getZoomLimits() async {
    final activeController = _controller;
    if (activeController == null || !activeController.value.isInitialized) {
      return {'min': 1.0, 'max': 1.0};
    }

    try {
      final minZoom = await activeController.getMinZoomLevel();
      final maxZoom = await activeController.getMaxZoomLevel();
      return {'min': minZoom, 'max': maxZoom};
    } catch (error) {
      _logger.e('Error al obtener los límites de zoom: $error');
      return {'min': 1.0, 'max': 1.0};
    }
  }

  /// Libera el controlador activo y permite una inicialización posterior.
  ///
  /// La referencia se limpia antes de esperar a `dispose`, de modo que ninguna
  /// llamada concurrente pueda reutilizar un controlador que se está cerrando.
  Future<void> dispose() async {
    final activeController = _controller;
    _controller = null;

    if (activeController == null) return;

    try {
      await activeController.dispose();
      _logger.i('Recursos de cámara liberados');
    } catch (error) {
      _logger.e('Error al liberar la cámara: $error');
    }
  }
}
