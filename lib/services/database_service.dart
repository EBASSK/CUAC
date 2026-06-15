import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/scan_history.dart';
import '../models/prediction.dart';
import 'dart:convert';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'lab_instruments.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Tabla: scan_history
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scan_history (
        id TEXT PRIMARY KEY,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        image_path TEXT NOT NULL,
        predicted_instrument TEXT NOT NULL,
        confidence REAL NOT NULL,
        top_3_predictions TEXT,
        user_notes TEXT,
        location TEXT,
        is_favorite INTEGER DEFAULT 0
      )
    ''');

    // Tabla: instruments (referencia)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS instruments (
        id INTEGER PRIMARY KEY,
        name TEXT UNIQUE NOT NULL,
        category TEXT,
        description TEXT,
        usage TEXT,
        safety_info TEXT,
        image_url TEXT,
        last_updated DATETIME
      )
    ''');

    // Índices para búsquedas rápidas
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_timestamp ON scan_history(timestamp DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_instrument ON scan_history(predicted_instrument)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_favorite ON scan_history(is_favorite)');
  }

  // ========== CRUD OPERATIONS ==========

  /// Insertar nuevo escaneo
  Future<String> insertScan(ScanHistory scan) async {
    final db = await database;
    
    final top3Json = jsonEncode(
      scan.top3Predictions.map((p) => p.toJson()).toList(),
    );

    await db.insert(
      'scan_history',
      {
        'id': scan.id,
        'timestamp': scan.timestamp.toIso8601String(),
        'image_path': scan.imagePath,
        'predicted_instrument': scan.predictedInstrument,
        'confidence': scan.confidence,
        'top_3_predictions': top3Json,
        'user_notes': scan.userNotes,
        'location': scan.location,
        'is_favorite': scan.isFavorite ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return scan.id;
  }

  /// Obtener todos los escaneos
  Future<List<ScanHistory>> getAllScans() async {
    final db = await database;
    final result = await db.query(
      'scan_history',
      orderBy: 'timestamp DESC',
    );

    return result.map((map) => _mapToScanHistory(map)).toList();
  }

  /// Obtener escaneo por ID
  Future<ScanHistory?> getScanById(String id) async {
    final db = await database;
    final result = await db.query(
      'scan_history',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isEmpty) return null;
    return _mapToScanHistory(result.first);
  }

  /// Obtener escaneos de un instrumento específico
  Future<List<ScanHistory>> getScansByInstrument(String instrument) async {
    final db = await database;
    final result = await db.query(
      'scan_history',
      where: 'predicted_instrument = ?',
      whereArgs: [instrument],
      orderBy: 'timestamp DESC',
    );

    return result.map((map) => _mapToScanHistory(map)).toList();
  }

  /// Obtener escaneos favoritos
  Future<List<ScanHistory>> getFavoritesScans() async {
    final db = await database;
    final result = await db.query(
      'scan_history',
      where: 'is_favorite = 1',
      orderBy: 'timestamp DESC',
    );

    return result.map((map) => _mapToScanHistory(map)).toList();
  }

  /// Obtener escaneos en rango de fechas
  Future<List<ScanHistory>> getScansByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final result = await db.query(
      'scan_history',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'timestamp DESC',
    );

    return result.map((map) => _mapToScanHistory(map)).toList();
  }

  /// Actualizar escaneo
  Future<int> updateScan(ScanHistory scan) async {
    final db = await database;

    final top3Json = jsonEncode(
      scan.top3Predictions.map((p) => p.toJson()).toList(),
    );

    return await db.update(
      'scan_history',
      {
        'user_notes': scan.userNotes,
        'location': scan.location,
        'is_favorite': scan.isFavorite ? 1 : 0,
        'top_3_predictions': top3Json,
      },
      where: 'id = ?',
      whereArgs: [scan.id],
    );
  }

  /// Toggle favorito
  Future<int> toggleFavorite(String id) async {
    final db = await database;
    
    final scan = await getScanById(id);
    if (scan == null) return 0;

    return await db.update(
      'scan_history',
      {'is_favorite': scan.isFavorite ? 0 : 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Eliminar escaneo
  Future<int> deleteScan(String id) async {
    final db = await database;
    return await db.delete(
      'scan_history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Limpiar historial completo
  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('scan_history');
  }

  // ========== STATISTICS ==========

  /// Contar total de escaneos
  Future<int> getScanCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM scan_history');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Obtener estadísticas generales
  Future<Map<String, dynamic>> getStatistics() async {
    final db = await database;
    
    final totalCount = await getScanCount();
    
    final uniqueInstruments = await db.rawQuery(
      'SELECT COUNT(DISTINCT predicted_instrument) as count FROM scan_history'
    );
    
    final avgConfidence = await db.rawQuery(
      'SELECT AVG(confidence) as avg FROM scan_history'
    );

    final firstScan = await db.rawQuery(
      'SELECT MIN(timestamp) as first FROM scan_history'
    );

    final lastScan = await db.rawQuery(
      'SELECT MAX(timestamp) as last FROM scan_history'
    );

    return {
      'total_scans': totalCount,
      'unique_instruments': Sqflite.firstIntValue(uniqueInstruments) ?? 0,
      'average_confidence': (avgConfidence.first['avg'] as double?) ?? 0.0,
      'first_scan': firstScan.first['first'],
      'last_scan': lastScan.first['last'],
    };
  }

  /// Obtener escaneos por instrumento (para gráficos)
  Future<Map<String, int>> getScanCountByInstrument() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT predicted_instrument, COUNT(*) as count FROM scan_history GROUP BY predicted_instrument ORDER BY count DESC'
    );

    final map = <String, int>{};
    for (var row in result) {
      map[row['predicted_instrument'] as String] = row['count'] as int;
    }
    return map;
  }

  /// Obtener promedio de confianza por instrumento
  Future<Map<String, double>> getAverageConfidenceByInstrument() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT predicted_instrument, AVG(confidence) as avg_confidence FROM scan_history GROUP BY predicted_instrument'
    );

    final map = <String, double>{};
    for (var row in result) {
      map[row['predicted_instrument'] as String] = 
          (row['avg_confidence'] as double?) ?? 0.0;
    }
    return map;
  }

  // ========== EXPORT ==========

  /// Exportar historial a JSON
  Future<String> exportHistoryAsJson() async {
    final scans = await getAllScans();
    final jsonList = scans.map((s) => {
      'id': s.id,
      'timestamp': s.timestamp.toIso8601String(),
      'instrument': s.predictedInstrument,
      'confidence': s.confidence,
      'notes': s.userNotes,
      'favorite': s.isFavorite,
    }).toList();

    return jsonEncode(jsonList);
  }

  /// Exportar historial a CSV
  Future<String> exportHistoryAsCSV() async {
    final scans = await getAllScans();
    
    final csv = StringBuffer();
    csv.writeln('ID,Timestamp,Instrument,Confidence,Notes,Favorite');
    
    for (var scan in scans) {
      csv.writeln(
        '${scan.id},'
        '${scan.timestamp.toIso8601String()},'
        '${scan.predictedInstrument},'
        '${scan.confidence},'
        '${scan.userNotes ?? ''},'
        '${scan.isFavorite ? 'Yes' : 'No'}',
      );
    }
    
    return csv.toString();
  }

  // ========== HELPERS ==========

  ScanHistory _mapToScanHistory(Map<String, dynamic> map) {
    final top3Json = map['top_3_predictions'] as String?;
    List<Prediction> predictions = [];

    if (top3Json != null && top3Json.isNotEmpty) {
      try {
        final jsonData = jsonDecode(top3Json) as List;
        predictions = jsonData
            .map((p) => Prediction.fromJson(p as Map<String, dynamic>))
            .toList();
      } catch (e) {
        predictions = [];
      }
    }

    return ScanHistory(
      id: map['id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      imagePath: map['image_path'] as String,
      predictedInstrument: map['predicted_instrument'] as String,
      confidence: map['confidence'] as double,
      top3Predictions: predictions,
      userNotes: map['user_notes'] as String?,
      location: map['location'] as String?,
      isFavorite: (map['is_favorite'] as int) == 1,
    );
  }

  /// Cerrar base de datos
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}