import 'package:json_annotation/json_annotation.dart';
import 'prediction.dart';

part 'scan_history.g.dart';

@JsonSerializable()
class ScanHistory {
  final String id;
  final DateTime timestamp;
  final String imagePath;
  final String predictedInstrument;
  final double confidence;
  final List<Prediction> top3Predictions;
  final String? userNotes;
  final String? location;
  final bool isFavorite;

  ScanHistory({
    required this.id,
    required this.timestamp,
    required this.imagePath,
    required this.predictedInstrument,
    required this.confidence,
    required this.top3Predictions,
    this.userNotes,
    this.location,
    this.isFavorite = false,
  });

  /// Convierte confianza a porcentaje
  int getConfidencePercent() {
    return (confidence * 100).toInt();
  }

  /// Formatea fecha de forma legible
  String getFormattedDate() {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Hace unos segundos';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} minutos';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} horas';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  String get formattedDate => getFormattedDate();

  int get confidencePercentage => getConfidencePercent();

  /// Crea copia con cambios
  ScanHistory copyWith({
    String? id,
    DateTime? timestamp,
    String? imagePath,
    String? predictedInstrument,
    double? confidence,
    List<Prediction>? top3Predictions,
    String? userNotes,
    String? location,
    bool? isFavorite,
  }) {
    return ScanHistory(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      imagePath: imagePath ?? this.imagePath,
      predictedInstrument: predictedInstrument ?? this.predictedInstrument,
      confidence: confidence ?? this.confidence,
      top3Predictions: top3Predictions ?? this.top3Predictions,
      userNotes: userNotes ?? this.userNotes,
      location: location ?? this.location,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  factory ScanHistory.fromJson(Map<String, dynamic> json) =>
      _$ScanHistoryFromJson(json);
  Map<String, dynamic> toJson() => _$ScanHistoryToJson(this);
}
