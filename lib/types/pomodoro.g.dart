// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pomodoro.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PomodoroSettings _$PomodoroSettingsFromJson(Map<String, dynamic> json) =>
    PomodoroSettings(
        focusMinutes: (json['focusMinutes'] as num?)?.toInt() ?? 25,
        shortBreakMinutes: (json['shortBreakMinutes'] as num?)?.toInt() ?? 5,
        longBreakMinutes: (json['longBreakMinutes'] as num?)?.toInt() ?? 15,
        selectedNoiseId: json['selectedNoiseId'] as String? ?? 'white',
        volume: (json['volume'] as num?)?.toDouble() ?? 0.6,
        autoPlayNoise: json['autoPlayNoise'] as bool? ?? false,
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$PomodoroSettingsToJson(PomodoroSettings instance) =>
    <String, dynamic>{
      r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
        instance.$lastUpdateTime,
        const UTCConverter().toJson,
      ),
      'focusMinutes': instance.focusMinutes,
      'shortBreakMinutes': instance.shortBreakMinutes,
      'longBreakMinutes': instance.longBreakMinutes,
      'selectedNoiseId': instance.selectedNoiseId,
      'volume': instance.volume,
      'autoPlayNoise': instance.autoPlayNoise,
    };

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);

PomodoroDayStat _$PomodoroDayStatFromJson(Map<String, dynamic> json) =>
    PomodoroDayStat(
        count: (json['count'] as num?)?.toInt() ?? 0,
        minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$PomodoroDayStatToJson(PomodoroDayStat instance) =>
    <String, dynamic>{
      r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
        instance.$lastUpdateTime,
        const UTCConverter().toJson,
      ),
      'count': instance.count,
      'minutes': instance.minutes,
    };

PomodoroStats _$PomodoroStatsFromJson(Map<String, dynamic> json) =>
    PomodoroStats(
        days: (json['days'] as Map<String, dynamic>?)?.map(
          (k, e) =>
              MapEntry(k, PomodoroDayStat.fromJson(e as Map<String, dynamic>)),
        ),
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$PomodoroStatsToJson(PomodoroStats instance) =>
    <String, dynamic>{
      r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
        instance.$lastUpdateTime,
        const UTCConverter().toJson,
      ),
      'days': instance.days,
    };
