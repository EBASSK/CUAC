class AppConfig {
  // API Configuration
  static const String apiBaseUrl = 'http://192.168.1.100:8000'; // Cambiar IP según tu backend
  static const String apiTimeout = '30'; // segundos
  
  // ML Model Configuration
  static const String modelPath = 'assets/models/instrument_model.tflite';
  static const String labelsPath = 'assets/models/labels.txt';
  static const int modelInputSize = 224; // MobileNetV2 input
  static const String modelVersion = '1.0.0';

  // Database Configuration
  static const String databaseName = 'lab_instruments.db';
  static const int databaseVersion = 1;

  // Camera Configuration
  static const int cameraFpsTarget = 30;
  static const bool useFlash = false;

  // Image Processing
  static const int maxImageSizeBytes = 5242880; // 5 MB
  static const int imageQuality = 85;
  static const String imageFormat = 'jpg';

  // Confidence Thresholds
  static const double confidenceThreshold = 0.5; // 50% mínimo
  static const double highConfidenceThreshold = 0.8; // 80% alto
  
  // App Info
  static const String appName = 'CUAC';
  static const String appVersion = '1.0.0';
  static const String appAuthor = 'EBASSK';
  static const String appDescription = 'Identifica instrumentos de laboratorio en tiempo real';
  
  // Feature Flags
  static const bool enableBackendAPI = false; // Cambiar a true si usas FastAPI
  static const bool enableAnalytics = false;
  static const bool enableDebugLogging = true;

  /// Inicialización de configuración
  static Future<void> initialize() async {
    // Aquí puedes agregar lógica de inicialización
    // por ejemplo cargar settings de SharedPreferences
    // o verificar permisos
  }

  /// Endpoints de API (si se habilita backend)
  static const String predictEndpoint = '/api/v1/predict';
  static const String historyEndpoint = '/api/v1/history';
  static const String healthEndpoint = '/api/v1/health';
}

/// Constantes de la aplicación
class AppConstants {
  // Strings
  static const String appTitle = 'CUAC';
  static const String appDescription = 'Identifica instrumentos de laboratorio en tiempo real';

  // Routes
  static const String routeHome = '/';
  static const String routeCamera = '/camera';
  static const String routeResults = '/results';
  static const String routeHistory = '/history';
  static const String routeDetail = '/detail';
  static const String routeSettings = '/settings';

  // Duration
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration loadingTimeout = Duration(seconds: 30);
  static const Duration debounceDelay = Duration(milliseconds: 500);

  // Cache
  static const int maxCacheSize = 100; // máximo de escaneos en cache
  static const Duration cacheDuration = Duration(days: 30);

  // Error Messages (español)
  static const String errorCameraPermission = 'Se requiere permiso de cámara';
  static const String errorStoragePermission = 'Se requiere acceso al almacenamiento';
  static const String errorModelLoading = 'Error al cargar el modelo de ML';
  static const String errorImageProcessing = 'Error al procesar la imagen';
  static const String errorDatabaseError = 'Error de base de datos';
  static const String errorNetworkError = 'Error de conectividad';
  static const String errorUnknownError = 'Error desconocido';

  // Success Messages
  static const String successImageCaptured = 'Imagen capturada correctamente';
  static const String successIdentified = 'Instrumento identificado';
  static const String successHistorySaved = 'Historial guardado';
  static const String successHistoryCleared = 'Historial borrado';

  // Validation
  static const int minPasswordLength = 8;
  static const int maxImageWidth = 2560;
  static const int maxImageHeight = 1920;
}

/// Configuración de Logging
class LogConfig {
  static const bool enableLog = true;
  static const bool logToFile = false;
  static const String logDir = 'logs';
}

/// Configuración de Testing
class TestConfig {
  static const bool enableMockAPI = false;
  static const bool enableMockCamera = false;
  static const String mockModelPath = 'assets/test/mock_model.tflite';
}
