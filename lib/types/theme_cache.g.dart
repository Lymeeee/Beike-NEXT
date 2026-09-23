// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_cache.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CachedDynamicScheme _$CachedDynamicSchemeFromJson(Map<String, dynamic> json) =>
    CachedDynamicScheme(
        light:
            (json['light'] as Map<String, dynamic>?)?.map(
              (k, e) => MapEntry(k, (e as num).toInt()),
            ) ??
            const {},
        dark:
            (json['dark'] as Map<String, dynamic>?)?.map(
              (k, e) => MapEntry(k, (e as num).toInt()),
            ) ??
            const {},
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$CachedDynamicSchemeToJson(
  CachedDynamicScheme instance,
) => <String, dynamic>{
  r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
    instance.$lastUpdateTime,
    const UTCConverter().toJson,
  ),
  'light': instance.light,
  'dark': instance.dark,
};

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);
