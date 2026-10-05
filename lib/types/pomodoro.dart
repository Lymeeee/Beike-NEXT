import 'package:json_annotation/json_annotation.dart';
import 'base.dart';

part 'pomodoro.g.dart';

@JsonSerializable()
class PomodoroSettings extends BaseDataClass {
  int focusMinutes;
  int shortBreakMinutes;
  int longBreakMinutes;
  String selectedNoiseId;
  double volume;

  /// 开启后声音跟随计时：开始计时自动播放选中音效，休息时音量自动降低
  bool autoPlayNoise;

  PomodoroSettings({
    this.focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.selectedNoiseId = 'white',
    this.volume = 0.6,
    this.autoPlayNoise = false,
  });

  @override
  Map<String, dynamic> getEssentials() => {
    'focusMinutes': focusMinutes,
    'shortBreakMinutes': shortBreakMinutes,
    'longBreakMinutes': longBreakMinutes,
    'selectedNoiseId': selectedNoiseId,
    'volume': volume,
    'autoPlayNoise': autoPlayNoise,
  };

  static final PomodoroSettings defaultSettings = PomodoroSettings();

  factory PomodoroSettings.fromJson(Map<String, dynamic> json) =>
      _$PomodoroSettingsFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$PomodoroSettingsToJson(this);
}

@JsonSerializable()
class PomodoroDayStat extends BaseDataClass {
  int count;
  int minutes;

  PomodoroDayStat({this.count = 0, this.minutes = 0});

  @override
  Map<String, dynamic> getEssentials() => {'count': count, 'minutes': minutes};

  factory PomodoroDayStat.fromJson(Map<String, dynamic> json) =>
      _$PomodoroDayStatFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$PomodoroDayStatToJson(this);
}

@JsonSerializable()
class PomodoroStats extends BaseDataClass {
  /// key 为本地日期 'yyyy-MM-dd'
  Map<String, PomodoroDayStat> days;

  PomodoroStats({Map<String, PomodoroDayStat>? days}) : days = days ?? {};

  PomodoroDayStat statFor(String key) => days[key] ?? PomodoroDayStat();

  @override
  Map<String, dynamic> getEssentials() => {
    // Map 相等是引用相等，这里用稳定字符串保证 == 语义正确
    'days': (days.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) => '${e.key}:${e.value.count}/${e.value.minutes}')
        .join(';'),
  };

  factory PomodoroStats.fromJson(Map<String, dynamic> json) =>
      _$PomodoroStatsFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$PomodoroStatsToJson(this);
}
