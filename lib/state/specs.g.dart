// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'specs.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DerivedDataSpec _$DerivedDataSpecFromJson(Map<String, dynamic> json) =>
    DerivedDataSpec(
      json['name'] as String,
      json['inputSource'] as String,
      json['inputElement'] as String,
      json['inputFormat'] as String,
      json['operation'] as String,
      (json['operand'] as num).toDouble(),
    );

Map<String, dynamic> _$DerivedDataSpecToJson(DerivedDataSpec instance) =>
    <String, dynamic>{
      'name': instance.name,
      'inputSource': instance.inputSource,
      'inputElement': instance.inputElement,
      'inputFormat': instance.inputFormat,
      'operation': instance.operation,
      'operand': instance.operand,
    };

DataPageSpec _$DataPageSpecFromJson(Map<String, dynamic> json) => DataPageSpec(
      json['name'] as String,
      (json['cells'] as List<dynamic>)
          .map((e) => DataCellSpec.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$DataPageSpecToJson(DataPageSpec instance) =>
    <String, dynamic>{
      'name': instance.name,
      'cells': instance.cells.map((e) => e.toJson()).toList(),
    };

DataCellSpec _$DataCellSpecFromJson(Map<String, dynamic> json) => DataCellSpec(
      json['source'] as String,
      json['element'] as String,
      json['format'] as String,
      name: json['name'] as String?,
    );

Map<String, dynamic> _$DataCellSpecToJson(DataCellSpec instance) {
  final val = <String, dynamic>{
    'source': instance.source,
    'element': instance.element,
    'format': instance.format,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  return val;
}
