import 'package:json_annotation/json_annotation.dart';

part 'instrument.g.dart';

@JsonSerializable()
class Instrument {
  final int id;
  final String name;
  final String category;
  final String description;
  final String usage;
  final String safetyInfo;
  final String? imageUrl;
  final DateTime? lastUpdated;

  Instrument({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.usage,
    required this.safetyInfo,
    this.imageUrl,
    this.lastUpdated,
  });

  factory Instrument.fromJson(Map<String, dynamic> json) =>
      _$InstrumentFromJson(json);
  Map<String, dynamic> toJson() => _$InstrumentToJson(this);
}
