// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models_instrument.dart';

Instrument _$InstrumentFromJson(Map<String, dynamic> json) => Instrument(
      id: json['id'] as int,
      name: json['name'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      usage: json['usage'] as String,
      safetyInfo: json['safetyInfo'] as String,
      imageUrl: json['imageUrl'] as String?,
      lastUpdated: json['lastUpdated'] == null
          ? null
          : DateTime.parse(json['lastUpdated'] as String),
    );

Map<String, dynamic> _$InstrumentToJson(Instrument instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'category': instance.category,
      'description': instance.description,
      'usage': instance.usage,
      'safetyInfo': instance.safetyInfo,
      'imageUrl': instance.imageUrl,
      'lastUpdated': instance.lastUpdated?.toIso8601String(),
    };
