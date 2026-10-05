import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '/types/pomodoro.dart';
import '/utils/app_bar.dart';
import '/utils/haptic.dart';
import '/utils/page_mixins.dart';

enum _Phase { focus, shortBreak, longBreak }

enum _RunStatus { idle, running, paused }

enum _NoiseSound {
  white('white', '白噪音', Icons.graphic_eq, 'audio/noise_white.wav'),
  pink('pink', '粉噪音', Icons.blur_on, 'audio/noise_pink.wav'),
  brown('brown', '棕噪音', Icons.terrain, 'audio/noise_brown.wav'),
  rain('rain', '雨声', Icons.water_drop_outlined, 'audio/noise_rain.wav'),
  wave('wave', '海浪', Icons.waves, 'audio/noise_wave.wav'),
  stream('stream', '流水', Icons.water, 'audio/noise_stream.wav');

  const _NoiseSound(this.id, this.label, this.icon, this.asset);

  final String id;
  final String label;
  final IconData icon;
  final String asset;

  static _NoiseSound fromId(String id) =>
      values.firstWhere((s) => s.id == id, orElse: () => white);
}

class PomodoroPage extends StatefulWidget {
  const PomodoroPage({super.key});

  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage>
    with PageStateMixin, WidgetsBindingObserver {
  static const _noBorderShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );
  static const _settingsKey = 'pomodoro_settings';
  static const _statsKey = 'pomodoro_stats';
  static const _longBreakEvery = 4;
  static const _weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];
  // 休息时音效降低后的音量系数
  static const _breakDuckFactor = 0.4;

  late PomodoroSettings _settings;
  late PomodoroStats _stats;
  final AudioPlayer _noisePlayer = AudioPlayer();

  Timer? _tickTimer;
  _Phase _phase = _Phase.focus;
  _RunStatus _status = _RunStatus.idle;
  int _remaining = 0;
  // 运行中剩余时间以结束时间戳为准（墙钟），避免 Timer 卡顿累积漂移
  DateTime? _endTime;
  int _phaseMinutes = 25;
  int _cycleFocus = 0;
  bool _noisePlaying = false;
  // 设置类弹窗打开时不算"离开页面"，计时与白噪音继续
  bool _dialogOpen = false;
  // 因为离开页面/切后台而暂停时置位，回到页面后弹一次提醒
  bool _remindOnReturn = false;

  _NoiseSound get _selectedNoise =>
      _NoiseSound.fromId(_settings.selectedNoiseId);

  @override
  void onServiceInit() {
    _settings = serviceProvider.storeService.getPref<PomodoroSettings>(
          _settingsKey,
          PomodoroSettings.fromJson,
        ) ??
        PomodoroSettings.defaultSettings;
    _stats = serviceProvider.storeService.getPref<PomodoroStats>(
          _statsKey,
          PomodoroStats.fromJson,
        ) ??
        PomodoroStats();
    _phaseMinutes = _settings.focusMinutes;
    _remaining = _phaseMinutes * 60;
    WidgetsBinding.instance.addObserver(this);
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tickTimer?.cancel();
    _noisePlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // inactive 只是失焦（桌面切窗口），不打断；真正离开（挂起/隐藏）才暂停
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pauseAndStopNoise();
    }
  }

  void _onTick() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent && !_dialogOpen) {
      // 页面被其他路由盖住：按"离开即不专注"处理（设置弹窗除外）
      _pauseAndStopNoise();
      return;
    }
    if (_remindOnReturn) {
      _remindOnReturn = false;
      if (_status == _RunStatus.paused) _showReturnReminder();
    }
    if (_status != _RunStatus.running) {
      // 未计时也刷新，保证统计区的日期标签跨零点后正确
      setState(() {});
      return;
    }
    final endTime = _endTime;
    if (endTime == null) return;
    final remaining = _secondsUntil(endTime);
    if (remaining <= 0) {
      _completeCurrentPhase();
    } else if (remaining != _remaining) {
      setState(() => _remaining = remaining);
    }
  }

  static int _secondsUntil(DateTime endTime) =>
      (endTime.difference(DateTime.now()).inMilliseconds / 1000).ceil();

  void _pauseAndStopNoise() {
    final wasRunning = _status == _RunStatus.running;
    if (!wasRunning && !_noisePlaying) return;
    if (_noisePlaying) {
      _noisePlayer.stop();
    }
    if (!mounted) return;
    setState(() {
      _noisePlaying = false;
      if (wasRunning) {
        _freezeRemaining();
        _status = _RunStatus.paused;
        _remindOnReturn = true;
      }
    });
  }

  /// 暂停时把墙钟剩余时间冻回 _remaining
  void _freezeRemaining() {
    final endTime = _endTime;
    _endTime = null;
    if (endTime == null) return;
    final remaining = _secondsUntil(endTime);
    if (remaining > 0) _remaining = remaining;
  }

  void _toggleRun() {
    Haptics.selection();
    setState(() {
      if (_status == _RunStatus.running) {
        _freezeRemaining();
        _status = _RunStatus.paused;
      } else {
        _endTime = DateTime.now().add(Duration(seconds: _remaining));
        _status = _RunStatus.running;
      }
    });
    _syncNoiseWithTimer();
  }

  void _resetPhase() {
    Haptics.selection();
    setState(() {
      _remaining = _phaseMinutes * 60;
      _endTime = null;
      _status = _RunStatus.idle;
    });
    _syncNoiseWithTimer();
  }

  void _completeCurrentPhase() {
    Haptics.medium();
    if (_phase == _Phase.focus) {
      _recordFocusDone();
      _cycleFocus++;
      _enterPhase(
        _cycleFocus % _longBreakEvery == 0
            ? _Phase.longBreak
            : _Phase.shortBreak,
        run: true,
      );
    } else if (_phase == _Phase.shortBreak) {
      _enterPhase(_Phase.focus, run: true);
    } else {
      _cycleFocus = 0;
      _enterPhase(_Phase.focus, run: true);
    }
    _syncNoiseWithTimer();
  }

  void _enterPhase(_Phase phase, {required bool run}) {
    setState(() {
      _phase = phase;
      _phaseMinutes = _minutesFor(phase);
      _remaining = _phaseMinutes * 60;
      _endTime = run
          ? DateTime.now().add(Duration(seconds: _remaining))
          : null;
      _status = run ? _RunStatus.running : _RunStatus.idle;
    });
  }

  int _minutesFor(_Phase phase) => switch (phase) {
    _Phase.focus => _settings.focusMinutes,
    _Phase.shortBreak => _settings.shortBreakMinutes,
    _Phase.longBreak => _settings.longBreakMinutes,
  };

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _recordFocusDone() {
    final key = _dateKey(DateTime.now());
    final before = _stats.statFor(key);
    _stats.days[key] = PomodoroDayStat(
      count: before.count + 1,
      minutes: before.minutes + _phaseMinutes,
    );
    serviceProvider.storeService.putPref<PomodoroStats>(_statsKey, _stats);
  }

  void _setDurationValue(_Phase target, int value) {
    setState(() {
      switch (target) {
        case _Phase.focus:
          _settings.focusMinutes = value;
        case _Phase.shortBreak:
          _settings.shortBreakMinutes = value;
        case _Phase.longBreak:
          _settings.longBreakMinutes = value;
      }
      // 计时未开始时立即生效；否则下一轮加载时生效
      if (_phase == target && _status == _RunStatus.idle) {
        _phaseMinutes = value;
        _remaining = value * 60;
      }
    });
  }

  void _saveSettings() {
    serviceProvider.storeService.putPref<PomodoroSettings>(
      _settingsKey,
      _settings,
    );
  }

  /// 播放音量：休息阶段自动降低
  double get _currentNoiseVolume {
    final base = _settings.volume;
    final isBreak =
        _phase == _Phase.shortBreak || _phase == _Phase.longBreak;
    return isBreak ? base * _breakDuckFactor : base;
  }

  /// 选择音效：只改选中项；正在播放时无缝切到新音效
  Future<void> _selectNoise(_NoiseSound sound) async {
    Haptics.selection();
    if (sound == _selectedNoise) return;
    setState(() => _settings.selectedNoiseId = sound.id);
    _saveSettings();
    if (_noisePlaying) await _playNoise();
  }

  Future<void> _playNoise() async {
    try {
      await _noisePlayer.stop();
      await _noisePlayer.setReleaseMode(ReleaseMode.loop);
      await _noisePlayer.play(
        AssetSource(_selectedNoise.asset),
        volume: _currentNoiseVolume,
      );
      if (mounted) setState(() => _noisePlaying = true);
    } catch (_) {
      if (mounted) setState(() => _noisePlaying = false);
    }
  }

  void _stopNoise() {
    if (!_noisePlaying) return;
    _noisePlayer.stop();
    setState(() => _noisePlaying = false);
  }

  /// 以"番茄钟是否在走"为界同步声音：计时中播放（休息时降低音量），停下就静音
  Future<void> _syncNoiseWithTimer() async {
    final shouldPlay =
        _settings.autoPlayNoise && _status == _RunStatus.running;
    if (shouldPlay) {
      if (_noisePlaying) {
        await _noisePlayer.setVolume(_currentNoiseVolume);
      } else {
        await _playNoise();
      }
    } else {
      _stopNoise();
    }
  }

  void _setVolume(double value) {
    setState(() => _settings.volume = value);
    _noisePlayer.setVolume(_currentNoiseVolume);
  }

  String _formatSeconds(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _phaseLabel => switch (_phase) {
    _Phase.focus => '专注',
    _Phase.shortBreak => '短休息',
    _Phase.longBreak => '长休息',
  };

  Color _phaseColor(ColorScheme scheme) => switch (_phase) {
    _Phase.focus => scheme.primary,
    _Phase.shortBreak => scheme.tertiary,
    _Phase.longBreak => scheme.secondary,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: '专注时刻',
        actions: [
          _buildBarButton(
            icon: Icons.tune,
            tooltip: '时长设置',
            onPressed: _showDurationDialog,
          ),
          _buildBarButton(
            icon: _noisePlaying ? Icons.volume_up : Icons.graphic_eq,
            tooltip: '背景声音',
            onPressed: _showNoiseDialog,
          ),
          _buildBarButton(
            icon: Icons.insights,
            tooltip: '专注统计',
            onPressed: _showStatsDialog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [_buildTimerCard(context)],
      ),
    );
  }

  Widget _buildBarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: tooltip,
        child: FilledButton(
          onPressed: () {
            Haptics.light();
            onPressed();
          },
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: const Size(40, 40),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }

  Widget _buildTimerCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = _phaseColor(scheme);
    final total = _phaseMinutes * 60;
    final progress = total == 0 ? 0.0 : 1 - _remaining / total;
    return Card.filled(
      shape: _noBorderShape,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _phaseLabel,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.12),
                    ),
                  ),
                  Text(
                    _formatSeconds(_remaining),
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w300,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$_phaseLabel $_phaseMinutes 分钟',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _longBreakEvery; i++)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _cycleFocus
                          ? color
                          : color.withValues(alpha: 0.2),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$_cycleFocus / $_longBreakEvery 个番茄',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (_settings.autoPlayNoise) ...[
              const SizedBox(height: 10),
              Text(
                '背景声音已开启',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _toggleRun,
                  icon: Icon(
                    _status == _RunStatus.running
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  label: Text(
                    _status == _RunStatus.running ? '暂停' : '开始',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _resetPhase,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重置'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReturnReminder() {
    Haptics.medium();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('提示'),
        titleTextStyle: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        content: const Text('不管怎样，你都切出去看别的了喵～要专心喵～'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _toggleRun();
            },
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDurationDialog() async {
    _dialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final scheme = Theme.of(dialogContext).colorScheme;
            final textTheme = Theme.of(dialogContext).textTheme;
            return AlertDialog(
              title: const Text('时长设置'),
              titleTextStyle: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDurationRow(
                        '专注时长',
                        _Phase.focus,
                        _settings.focusMinutes,
                        5,
                        90,
                        5,
                        () => setDialogState(() {}),
                      ),
                      _buildDurationRow(
                        '短休息',
                        _Phase.shortBreak,
                        _settings.shortBreakMinutes,
                        1,
                        15,
                        1,
                        () => setDialogState(() {}),
                      ),
                      _buildDurationRow(
                        '长休息',
                        _Phase.longBreak,
                        _settings.longBreakMinutes,
                        5,
                        30,
                        5,
                        () => setDialogState(() {}),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '修改在当前阶段未开始时立即生效，否则下一轮生效',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    } finally {
      _dialogOpen = false;
    }
  }

  Widget _buildDurationRow(
    String label,
    _Phase target,
    int value,
    int min,
    int max,
    int step,
    VoidCallback onAfterChange,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                '$value 分钟',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: ((max - min) / step).round(),
            label: '$value 分钟',
            onChanged: (v) {
              _setDurationValue(target, v.round());
              onAfterChange();
            },
            onChangeEnd: (_) {
              Haptics.selection();
              _saveSettings();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showNoiseDialog() async {
    _dialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final scheme = Theme.of(dialogContext).colorScheme;
            final textTheme = Theme.of(dialogContext).textTheme;
            return AlertDialog(
              title: const Text('背景声音'),
              titleTextStyle: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        title: const Text('启用背景声音'),
                        subtitle: Text(
                          '想要更加专注？',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        value: _settings.autoPlayNoise,
                        onChanged: (value) {
                          Haptics.selection();
                          setState(() => _settings.autoPlayNoise = value);
                          _saveSettings();
                          _syncNoiseWithTimer();
                          setDialogState(() {});
                        },
                      ),
                      const Divider(height: 12),
                      for (final sound in _NoiseSound.values)
                        _buildNoiseRow(
                          sound,
                          onTap: () {
                            _selectNoise(sound).then((_) {
                              if (dialogContext.mounted) {
                                setDialogState(() {});
                              }
                            });
                          },
                        ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.volume_down,
                              size: 20,
                              color: scheme.onSurfaceVariant,
                            ),
                            Expanded(
                              child: Slider(
                                value: _settings.volume,
                                onChanged: (value) {
                                  _setVolume(value);
                                  setDialogState(() {});
                                },
                                onChangeEnd: (_) => _saveSettings(),
                              ),
                            ),
                            Icon(
                              Icons.volume_up,
                              size: 20,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    } finally {
      _dialogOpen = false;
    }
  }

  Widget _buildNoiseRow(_NoiseSound sound, {required VoidCallback onTap}) {
    return RadioGroup<bool>(
      groupValue: sound == _selectedNoise,
      onChanged: (_) => onTap(),
      child: RadioListTile<bool>(
        value: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
        title: Text(sound.label),
      ),
    );
  }

  Future<void> _showStatsDialog() async {
    _dialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final scheme = Theme.of(dialogContext).colorScheme;
          final textTheme = Theme.of(dialogContext).textTheme;
          final now = DateTime.now();
          final todayStat = _stats.statFor(_dateKey(now));
          return AlertDialog(
            title: const Text('专注统计'),
            titleTextStyle: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '今日 ${todayStat.count} 个番茄 · 专注 ${todayStat.minutes} 分钟',
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Divider(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '最近 7 天',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (var i = 0; i < 7; i++)
                      _buildStatDayRow(
                        DateTime(now.year, now.month, now.day - i),
                        i,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } finally {
      _dialogOpen = false;
    }
  }

  Widget _buildStatDayRow(DateTime day, int offset) {
    final scheme = Theme.of(context).colorScheme;
    final stat = _stats.statFor(_dateKey(day));
    final label = offset == 0
        ? '今天'
        : offset == 1
        ? '昨天'
        : '${day.month}月${day.day}日 周${_weekdayNames[day.weekday - 1]}';
    final empty = stat.count == 0 && stat.minutes == 0;
    final color = empty
        ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
        : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: color))),
          Text(
            '${stat.count} 个 · ${stat.minutes} 分钟',
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}
