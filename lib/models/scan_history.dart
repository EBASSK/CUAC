import 'package:json_annotation/json_annotation.dart';
import 'prediction.dart';

part 'scan_history.g.dart';

/// Registro persistente de una identificación realizada por el usuario.
///
/// La anotación genera los adaptadores [fromJson] y [toJson] en el archivo
/// `scan_history.g.dart`; ese archivo es código generado y no debe editarse.
@JsonSerializable()
class ScanHistory {
  /// Identificador único del registro dentro de la base de datos.
  final String id;

  /// Instante en que se confirmó y guardó la identificación.
  final DateTime timestamp;

  /// Ruta local de la copia permanente de la fotografía.
  final String imagePath;

  /// Nombre de la predicción con mayor confianza.
  final String predictedInstrument;

  /// Confianza normalizada de la predicción principal.
  final double confidence;

  /// Hasta tres predicciones ordenadas, incluida la predicción principal.
  final List<Prediction> top3Predictions;

  /// Nota libre agregada por el usuario al guardar el resultado.
  final String? userNotes;

  /// Ubicación opcional asociada al registro; actualmente puede quedar vacía.
  final String? location;

  /// Indica si el registro aparece en el filtro de favoritos.
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

  /// Convierte la confianza normalizada a un porcentaje entero.
  int getConfidencePercent() {
    return (confidence * 100).toInt();
  }

  /// Presenta la fecha como tiempo relativo reciente o como fecha calendario.
  ///
  /// Esta conversión se calcula al consultarla para mantener actualizado el
  /// texto «Hace…» aunque el objeto permanezca cargado en memoria.
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

  /// Acceso abreviado usado por widgets y plantillas de presentación.
  String get formattedDate => getFormattedDate();

  /// Acceso abreviado al porcentaje de confianza ya convertido.
  int get confidencePercentage => getConfidencePercent();

  /// Crea una nueva instancia reemplazando únicamente los campos indicados.
  ///
  /// Este patrón mantiene el modelo inmutable al marcar favoritos o editar datos.
  /// En los campos anulables [userNotes] y [location], pasar `null` conserva el
  /// valor anterior; este método no permite reemplazarlos explícitamente por null.
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

  /// Reconstruye un registro desde el mapa producido por la capa de datos.
  factory ScanHistory.fromJson(Map<String, dynamic> json) =>
      _$ScanHistoryFromJson(json);

  /// Convierte el registro a un mapa listo para serializar o almacenar.
  Map<String, dynamic> toJson() => _$ScanHistoryToJson(this);
}
