import 'package:camera/camera.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  CameraController? _controller;
  final Logger _logger = Logger();

  factory CameraService() {
    return _instance;
  }

  CameraService._internal();

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get isRecording => _controller?.value.isRecordingVideo ?? false;

  /// Verifica y solicita permisos de cámara
  Future<bool> requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      _logger.i('Permiso cámara: $status');
      return status.isGranted;
    } catch (e) {
      _logger.e('Error solicitando permiso de cámara: $e');
      return false;
    }
  }

  /// Inicializa la cámara
  Future<void> initialize() async {
    try {
      _logger.i('Inicializando cámara...');

      // Verificar permiso
      final hasPermission = await requestCameraPermission();
      if (!hasPermission) {
        throw Exception('Permiso de cámara denegado');
      }

      // Obtener cámaras disponibles
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No hay cámaras disponibles');
      }

      // Seleccionar cámara trasera
      final rearCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _logger.i('Usando cámara: ${rearCamera.name}');

      // Crear controlador
      _controller = CameraController(
        rearCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      // Inicializar
      await _controller!.initialize();

      // Configurar Flash por defecto
      await setFlashMode(FlashMode.off);

      _logger.i('✅ Cámara inicializada exitosamente');
    } catch (e) {
      _logger.e('❌ Error inicializando cámara: $e');
      rethrow;
    }
  }

  /// Captura una foto con configuración optimizada para ML
  Future<XFile?> takePicture() async {
    if (!isInitialized) {
      _logger.e('Cámara no inicializada');
      return null;
    }

    try {
      _logger.i('Capturando foto optimizada para ML...');

      // Configurar para mejor calidad antes de capturar
      await _controller!.setFlashMode(FlashMode.off); // Evitar flash para colores naturales
      await _controller!.setFocusMode(FocusMode.auto); // Enfoque automático
      await _controller!.setExposureMode(ExposureMode.auto); // Exposición automática

      // Pequeña pausa para que la cámara se ajuste
      await Future.delayed(const Duration(milliseconds: 500));

      final image = await _controller!.takePicture();

      _logger.i('✅ Foto capturada: ${image.path}');
      return image;
    } catch (e) {
      _logger.e('❌ Error capturando foto: $e');
      return null;
    }
  }

  /// Cambia el modo flash
  Future<void> setFlashMode(FlashMode mode) async {
    if (!isInitialized) return;

    try {
      await _controller!.setFlashMode(mode);
      _logger.i('Flash cambiado a: $mode');
    } catch (e) {
      _logger.e('Error cambiando flash: $e');
    }
  }

  /// Obtiene modo flash actual
  FlashMode get currentFlashMode {
    return _controller?.value.flashMode ?? FlashMode.off;
  }

  /// Alterna flash on/off
  Future<void> toggleFlash() async {
    final newMode = currentFlashMode == FlashMode.off 
        ? FlashMode.torch 
        : FlashMode.off;
    await setFlashMode(newMode);
  }

  /// Zoom in
  Future<void> zoomIn() async {
    if (!isInitialized) return;

    try {
      final maxZoom = await _controller!.getMaxZoomLevel();
      final currentZoom = await _controller!.getMinZoomLevel();
      
      if (currentZoom < maxZoom) {
        await _controller!.setZoomLevel(currentZoom + 0.5);
      }
    } catch (e) {
      _logger.e('Error en zoom: $e');
    }
  }

  /// Zoom out
  Future<void> zoomOut() async {
    if (!isInitialized) return;

    try {
      final minZoom = await _controller!.getMinZoomLevel();
      final currentZoom = await _controller!.getMinZoomLevel();
      
      if (currentZoom > minZoom) {
        await _controller!.setZoomLevel(currentZoom - 0.5);
      }
    } catch (e) {
      _logger.e('Error en zoom: $e');
    }
  }

  /// Reinicia zoom
  Future<void> resetZoom() async {
    if (!isInitialized) return;

    try {
      final minZoom = await _controller!.getMinZoomLevel();
      await _controller!.setZoomLevel(minZoom);
    } catch (e) {
      _logger.e('Error reseteando zoom: $e');
    }
  }

  /// Obtiene valores de zoom
  Future<Map<String, double>> getZoomLimits() async {
    if (!isInitialized) return {'min': 1.0, 'max': 1.0};

    try {
      final minZoom = await _controller!.getMinZoomLevel();
      final maxZoom = await _controller!.getMaxZoomLevel();
      return {'min': minZoom, 'max': maxZoom};
    } catch (e) {
      _logger.e('Error obteniendo zoom limits: $e');
      return {'min': 1.0, 'max': 1.0};
    }
  }

  /// Obtiene información de la cámara
  String getCameraInfo() {
    if (_controller == null) return 'Cámara no inicializada';

    final info = _controller!.description;
    return '''
    Cámara: ${info.name}
    Orientación: ${info.sensorOrientation}°
    Dirección: ${info.lensDirection}
    ''';
  }

  /// Libera recursos
  Future<void> dispose() async {
    try {
      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
        _logger.i('Cámara disposed');
      }
    } catch (e) {
      _logger.e('Error en dispose: $e');
    }
  }
}

/// Excepciones personalizadas
class CameraException implements Exception {
  final String message;
  CameraException(this.message);

  @override
  String toString() => 'CameraException: $message';
}
