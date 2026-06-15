// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_history.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScanHistory _$ScanHistoryFromJson(Map<String, dynamic> json) => ScanHistory(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      imagePath: json['imagePath'] as String,
      predictedInstrument: json['predictedInstrument'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      top3Predictions: (json['top3Predictions'] as List<dynamic>)
          .map((e) => Prediction.fromJson(e as Map<String, dynamic>))
          .toList(),
      userNotes: json['userNotes'] as String?,
      location: json['location'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );

Map<String, dynamic> _$ScanHistoryToJson(ScanHistory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'timestamp': instance.timestamp.toIso8601String(),
      'imagePath': instance.imagePath,
      'predictedInstrument': instance.predictedInstrument,
      'confidence': instance.confidence,
      'top3Predictions': instance.top3Predictions,
      'userNotes': instance.userNotes,
      'location': instance.location,
      'isFavorite': instance.isFavorite,
    };
