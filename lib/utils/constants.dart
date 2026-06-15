// Constantes de la aplicación

// App Info
const String APP_NAME = 'CUAC';
const String APP_VERSION = '1.0.0';
const String APP_BUILD = '1';

// Database
const String DATABASE_NAME = 'lab_instruments.db';
const int DATABASE_VERSION = 1;

// Tablas
const String TABLE_SCAN_HISTORY = 'scan_history';
const String TABLE_INSTRUMENTS = 'instruments';

// Columnas - scan_history
const String COLUMN_SCAN_ID = 'id';
const String COLUMN_SCAN_TIMESTAMP = 'timestamp';
const String COLUMN_SCAN_IMAGE_PATH = 'image_path';
const String COLUMN_SCAN_PREDICTED_INSTRUMENT = 'predicted_instrument';
const String COLUMN_SCAN_CONFIDENCE = 'confidence';
const String COLUMN_SCAN_TOP3_PREDICTIONS = 'top_3_predictions';
const String COLUMN_SCAN_USER_NOTES = 'user_notes';
const String COLUMN_SCAN_LOCATION = 'location';
const String COLUMN_SCAN_IS_FAVORITE = 'is_favorite';

// Columnas - instruments
const String COLUMN_INSTRUMENT_ID = 'id';
const String COLUMN_INSTRUMENT_NAME = 'name';
const String COLUMN_INSTRUMENT_CATEGORY = 'category';
const String COLUMN_INSTRUMENT_DESCRIPTION = 'description';

// ML Model
const String MODEL_PATH = 'assets/models/instrument_model.tflite';
const String LABELS_PATH = 'assets/models/labels.txt';
const int MODEL_INPUT_SIZE = 224;
const double CONFIDENCE_THRESHOLD = 0.5;

// Instrumentos predefinidos (10 clases)
const List<String> INSTRUMENT_CLASSES = [
  'Microscopio',
  'Probeta',
  'Matraces',
  'Pipetas',
  'Vasos de Precipitado',
  'Buretas',
  'Embudos',
  'Pinzas',
  'Gradillas',
  'Crisoles',
];

// Duración de animaciones
const Duration ANIMATION_DURATION_SHORT = Duration(milliseconds: 300);
const Duration ANIMATION_DURATION_MEDIUM = Duration(milliseconds: 500);
const Duration ANIMATION_DURATION_LONG = Duration(milliseconds: 800);

// Timeouts
const Duration REQUEST_TIMEOUT = Duration(seconds: 30);
const Duration IMAGE_PROCESS_TIMEOUT = Duration(seconds: 10);

// Mensajes de error comunes
const String ERROR_CAMERA_PERMISSION = 'Permiso de cámara denegado';
const String ERROR_IMAGE_INVALID = 'Imagen inválida o corrupta';
const String ERROR_MODEL_LOAD = 'Error al cargar el modelo ML';
const String ERROR_DATABASE = 'Error al acceder a la base de datos';
const String ERROR_NETWORK = 'Error de conexión';
const String ERROR_UNKNOWN = 'Error desconocido';

// Rutas de navegación
const String ROUTE_SPLASH = '/';
const String ROUTE_CAMERA = '/camera';
const String ROUTE_RESULTS = '/results';
const String ROUTE_HISTORY = '/history';
const String ROUTE_DETAIL = '/detail/:id';
const String ROUTE_SETTINGS = '/settings';

// Preferencias de usuario (SharedPreferences)
const String PREF_THEME_MODE = 'themeMode'; // light/dark
const String PREF_LANGUAGE = 'language'; // es/en
const String PREF_NOTIFICATIONS = 'notifications'; // true/false
const String PREF_FIRST_RUN = 'firstRun'; // true/false
const String PREF_DEVICE_ID = 'deviceId';

// API (si usas backend en futuro)
const String API_BASE_URL = 'https://api.labidentifier.com';
const int API_TIMEOUT_SECONDS = 30;

// Cache
const String CACHE_DIR = 'app_cache';
const String CACHE_IMAGES_DIR = 'cached_images';
const int CACHE_MAX_AGE_DAYS = 30;
