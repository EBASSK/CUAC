import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tflite_service.dart';
import '../services/camera_service.dart';
import '../services/database_service.dart';
import '../services/image_processing_service.dart';
import '../models/scan_history.dart';
import '../models/prediction.dart';

// ========== SERVICIOS ==========
// Estos providers crean y gestionan las instancias de los servicios principales
// Se usan Provider (no StateNotifier) porque son servicios stateless que no cambian

/// Provider para el servicio de TensorFlow Lite
/// Gestiona la carga y ejecución del modelo de machine learning
/// Se crea una nueva instancia por cada acceso (stateless)
final tfliteServiceProvider = Provider<TFLiteService>((ref) {
  return TFLiteService();
});

/// Provider para el servicio de cámara
/// Maneja la inicialización y control de la cámara del dispositivo
/// Abstrae la complejidad del plugin de cámara nativo
final cameraServiceProvider = Provider<CameraService>((ref) {
  return CameraService();
});

/// Provider para el servicio de base de datos
/// Gestiona todas las operaciones CRUD con SQLite
/// Centraliza el acceso a datos persistentes
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

/// Provider para el servicio de procesamiento de imágenes
/// Maneja carga, compresión, redimensionamiento y guardado de imágenes
/// Optimiza imágenes para análisis de IA y almacenamiento eficiente
final imageProcessingServiceProvider = Provider<ImageProcessingService>((ref) {
  return ImageProcessingService();
});

// ========== STATE PROVIDERS ==========
// Estos providers gestionan el estado global de la aplicación
// Usan StateProvider para estados simples y StateNotifier para lógica compleja

/// Provider para el estado de inicialización de la aplicación
/// Coordina la inicialización asíncrona de servicios críticos (TFLite, Cámara)
/// FutureProvider porque representa una operación asíncrona única
final initializationProvider = FutureProvider<void>((ref) async {
  // Obtiene referencias a los servicios necesarios
  final tflite = ref.watch(tfliteServiceProvider);
  final camera = ref.watch(cameraServiceProvider);

  // Inicializa servicios en paralelo para mejor performance
  await tflite.initialize();
  await camera.initialize();
});

/// Provider para el estado de la cámara
/// Gestiona los diferentes estados de la cámara (idle, loading, ready, error)
/// StateProvider porque es un estado simple que cambia frecuentemente
final cameraStateProvider = StateProvider<CameraState>((ref) {
  return const CameraState.idle();
});

/// Provider para el estado de predicción de IA
/// Gestiona el flujo de análisis de imágenes con IA
/// StateProvider para estados de carga, éxito y error
final predictionStateProvider = StateProvider<PredictionState>((ref) {
  return const PredictionState.idle();
});

/// Provider para estado de historial
final historyStateProvider = StateProvider<HistoryState>((ref) {
  return const HistoryState.idle();
});

// ========== COMPUTED PROVIDERS ==========

/// Provider para obtener último escaneo
final lastScanProvider = FutureProvider<ScanHistory?>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  final scans = await db.getAllScans();
  return scans.isNotEmpty ? scans.first : null;
});

/// Provider para obtener todas las predicciones actuales
final topPredictionsProvider = StateProvider<List<Prediction>>((ref) {
  return [];
});

/// Provider para obtener historial completo
final allScansProvider = FutureProvider<List<ScanHistory>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getAllScans();
});

/// Provider para obtener escaneos favoritos
final favoritesProvider = FutureProvider<List<ScanHistory>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getFavoritesScans();
});

/// Provider para estadísticas
final statisticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getStatistics();
});

/// Provider para contador de escaneos
final scanCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getScanCount();
});

// ========== NOTIFIERS ==========

/// StateNotifier para manejo de predicción
class PredictionNotifier extends StateNotifier<PredictionState> {
  final Ref ref;

  PredictionNotifier(this.ref) : super(const PredictionState.idle());

  Future<void> predict(String imagePath) async {
  state = const PredictionState.loading();
  try {
      state = const PredictionState.loading();

      final imageProc = ref.read(imageProcessingServiceProvider);
      final tflite = ref.read(tfliteServiceProvider);

      // Validar imagen
      final validation = await imageProc.validateImage(imagePath);
      if (!validation.isValid) {
        state = PredictionState.error(validation.message);
        return;
      }

      // Procesar imagen
      final imageBytes = await imageProc.loadAndProcessImage(imagePath);
      if (imageBytes == null) {
        state = const PredictionState.error('No se pudo procesar la imagen');
        return;
      }

      // Realizar predicción
      final results = await tflite.predict(imageBytes);

      if (results.isEmpty) {
        state = const PredictionState.error('No se obtuvieron predicciones');
        return;
      }

      // Convertir resultados
      final predictions = results
          .map((r) => Prediction(
                name: r.label,
                confidence: r.confidence,
                category: _getCategoryForLabel(r.label),
              ))
          .toList();

      state = PredictionState.success(predictions);

      // Guardar en BD
      await _saveScan(imagePath, results.first, predictions);
    } catch (e) {
      state = PredictionState.error('Error en predicción: $e');
    }
  }

  Future<void> _saveScan(
    String imagePath,
    PredictionResult topResult,
    List<Prediction> allPredictions,
  ) async {
    try {
      final db = ref.read(databaseServiceProvider);
      final imageProc = ref.read(imageProcessingServiceProvider);

      // Guardar imagen
      final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final imageBytes = await imageProc.loadAndProcessImage(imagePath);
      if (imageBytes == null) return;

      final savedPath = await imageProc.saveImage(
        imageBytes,
        fileName,
      );

      if (savedPath != null) {
        final scanHistory = ScanHistory(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          imagePath: imagePath,
          predictedInstrument: topResult.label,
          confidence: topResult.confidence,
          top3Predictions: allPredictions,
          userNotes: null,
          location: null,
          isFavorite: false,
        );

        // Guardar en BD
        await db.insertScan(scanHistory);
      }
    } catch (e) {
      // Log pero no afecta la predicción
      print('Error guardando escaneo: $e');
    }
  }

  String _getCategoryForLabel(String label) {
    final categories = {
      'Microscopio': 'Óptica',
      'Probeta': 'Medición',
      'Matraces': 'Contenedores',
      'Pipetas': 'Medición',
      'Vasos de precipitado': 'Contenedores',
      'Buretas': 'Dosificación',
      'Embudos': 'Transferencia',
      'Pinzas': 'Sujeción',
      'Gradillas': 'Organización',
      'Crisoles': 'Calentamiento',
    };
    return categories[label] ?? 'Otros';
  }
}

/// Provider notifier para predicción
final predictionNotifierProvider =
    StateNotifierProvider<PredictionNotifier, PredictionState>((ref) {
  return PredictionNotifier(ref);
});

/// StateNotifier para manejo de historial
class HistoryNotifier extends StateNotifier<HistoryState> {
  final DatabaseService _database = DatabaseService();

  HistoryNotifier() : super(const HistoryState.idle());

  /// Cargar historial desde BD
  Future<void> loadHistory() async {
    state = const HistoryState.loading();
    try {
      final scans = await _database.getAllScans();
      state = HistoryState.success(scans);
    } catch (e) {
      state = HistoryState.error('Error al cargar historial: $e');
    }
  }

  /// Cargar favoritos
  Future<void> loadFavorites() async {
    state = const HistoryState.loading();
    try {
      final scans = await _database.getFavoritesScans();
      state = HistoryState.success(scans);
    } catch (e) {
      state = HistoryState.error('Error al cargar favoritos: $e');
    }
  }

  /// Cargar escaneos de hoy
  Future<void> loadTodayScans() async {
    state = const HistoryState.loading();
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(Duration(days: 1));
      
      final scans = await _database.getScansByDateRange(today, tomorrow);
      state = HistoryState.success(scans);
    } catch (e) {
      state = HistoryState.error('Error al cargar escaneos: $e');
    }
  }

  /// Cargar escaneos de esta semana
  Future<void> loadWeekScans() async {
    state = const HistoryState.loading();
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(Duration(days: 7));
      
      final scans = await _database.getScansByDateRange(weekAgo, now);
      state = HistoryState.success(scans);
    } catch (e) {
      state = HistoryState.error('Error al cargar escaneos: $e');
    }
  }

  /// Eliminar escaneo
  Future<void> deleteScan(String id) async {
    try {
      await _database.deleteScan(id);
      await loadHistory(); // Recargar
    } catch (e) {
      state = HistoryState.error('Error al eliminar: $e');
    }
  }

  /// Toggle favorito
  Future<void> toggleFavorite(String id) async {
    try {
      await _database.toggleFavorite(id);
      await loadHistory(); // Recargar
    } catch (e) {
      state = HistoryState.error('Error al actualizar: $e');
    }
  }

  /// Limpiar historial
  Future<void> clearHistory() async {
    try {
      await _database.clearHistory();
      state = const HistoryState.success([]);
    } catch (e) {
      state = HistoryState.error('Error al limpiar: $e');
    }
  }

  /// Obtener estadísticas
  Future<Map<String, dynamic>> getStatistics() async {
    return await _database.getStatistics();
  }

  /// Exportar como JSON
  Future<String> exportAsJSON() async {
    return await _database.exportHistoryAsJson();
  }

  /// Exportar como CSV
  Future<String> exportAsCSV() async {
    return await _database.exportHistoryAsCSV();
  }
}

/// Provider notifier para historial
final historyNotifierProvider =
    StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  return HistoryNotifier();
});

// ========== STATE CLASSES ==========

/// Estado de predicción
sealed class PredictionState {
  const PredictionState();

  const factory PredictionState.idle() = _PredictionIdle;
  const factory PredictionState.loading() = _PredictionLoading;
  const factory PredictionState.success(List<Prediction> predictions) =
      _PredictionSuccess;
  const factory PredictionState.error(String message) = _PredictionError;
}

class _PredictionIdle extends PredictionState {
  const _PredictionIdle();
}

class _PredictionLoading extends PredictionState {
  const _PredictionLoading();
}

class _PredictionSuccess extends PredictionState {
  final List<Prediction> predictions;
  const _PredictionSuccess(this.predictions);
}

class _PredictionError extends PredictionState {
  final String message;
  const _PredictionError(this.message);
}

/// Estado de cámara
sealed class CameraState {
  const CameraState();

  const factory CameraState.idle() = _CameraIdle;
  const factory CameraState.loading() = _CameraLoading;
  const factory CameraState.ready() = _CameraReady;
  const factory CameraState.error(String message) = _CameraError;
}

class _CameraIdle extends CameraState {
  const _CameraIdle();
}

class _CameraLoading extends CameraState {
  const _CameraLoading();
}

class _CameraReady extends CameraState {
  const _CameraReady();
}

class _CameraError extends CameraState {
  final String message;
  const _CameraError(this.message);
}

/// Estado de historial
sealed class HistoryState {
  const HistoryState();

  const factory HistoryState.idle() = _HistoryIdle;
  const factory HistoryState.loading() = _HistoryLoading;
  const factory HistoryState.success(List<ScanHistory> scans) =
      _HistorySuccess;
  const factory HistoryState.error(String message) = _HistoryError;
}

class _HistoryIdle extends HistoryState {
  const _HistoryIdle();
}

class _HistoryLoading extends HistoryState {
  const _HistoryLoading();
}

class _HistorySuccess extends HistoryState {
  final List<ScanHistory> scans;
  const _HistorySuccess(this.scans);
}

class _HistoryError extends HistoryState {
  final String message;
  const _HistoryError(this.message);
}

extension PredictionStateX on PredictionState {
  T when<T>({
    required T Function() idle,
    required T Function() loading,
    required T Function(List<Prediction> predictions) success,
    required T Function(String message) error,
  }) {
    if (this is _PredictionIdle) return idle();
    if (this is _PredictionLoading) return loading();
    if (this is _PredictionSuccess) {
      return success((this as _PredictionSuccess).predictions);
    }
    if (this is _PredictionError) {
      return error((this as _PredictionError).message);
    }
    throw StateError('Unhandled PredictionState: $this');
  }
}

extension HistoryStateX on HistoryState {
  T when<T>({
    required T Function() idle,
    required T Function() loading,
    required T Function(List<ScanHistory> scans) success,
    required T Function(String message) error,
  }) {
    if (this is _HistoryIdle) return idle();
    if (this is _HistoryLoading) return loading();
    if (this is _HistorySuccess) {
      return success((this as _HistorySuccess).scans);
    }
    if (this is _HistoryError) {
      return error((this as _HistoryError).message);
    }
    throw StateError('Unhandled HistoryState: $this');
  }
}
