import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/services/provider.dart';
import '/services/widget_updater.dart';
import '/main.dart';
import '/types/preferences.dart';
import '/utils/haptic.dart';
import '/types/courses.dart';

const _accentPresets = [
  null,
  Color(0xFF005B94), // 北科蓝
  Color(0xFF9BABB8), // 灰蓝
  Color(0xFFA3B0A1), // 鼠尾草绿
  Color(0xFFC2AEA6), // 烟灰粉
  Color(0xFFB4ADBC), // 薰衣草灰
  Color(0xFFBBAFA0), // 暖灰褐
  Color(0xFF9AB5AF), // 雾蓝绿
  Color(0xFFAEA3B9), // 紫藤灰
  Color(0xFFABB09B), // 橄榄灰
  Color(0xFF93AAB5), // 雾霾蓝
  Color(0xFFC59D90), // 陶土粉
];

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _noBorderShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );

  final ServiceProvider _serviceProvider = ServiceProvider.instance;
  bool _isClearingCache = false;
  bool _isClearingPrefs = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildThemeModeRow(),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildAccentColorPicker(),
          ),
          const SizedBox(height: 24),
          _buildExamModeToggle(),
          const SizedBox(height: 16),
          _buildHolidayToggle(),
          const SizedBox(height: 16),
          _buildHapticToggle(),
          if (Platform.isAndroid) ...[
            const SizedBox(height: 16),
            _buildBatteryOptimizationTile(),
          ],
          const SizedBox(height: 24),
          _buildDataSection(),
          if (kDebugMode) _buildServiceSection(),
        ],
      ),
    );
  }

  Widget _buildThemeModeRow() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('配色方案', style: Theme.of(context).textTheme.bodyLarge),
              Text(
                ThemeManager.currentThemeMode.displayName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(_getThemeIcon(ThemeManager.currentThemeMode)),
          onPressed: () {
            Haptics.selection();
            ThemeManager.updateThemeMode(
              _getNextThemeMode(ThemeManager.currentThemeMode),
            );
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildAccentColorPicker() {
    final currentColor = ThemeManager.currentAccentColor;
    final theme = Theme.of(context);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _accentPresets.map((color) {
        final isSelected =
            (color == null && currentColor == null) ||
            (color != null &&
                currentColor != null &&
                color.toARGB32() == currentColor.toARGB32());

        return GestureDetector(
          onTap: () {
            Haptics.selection();
            ThemeManager.updateAccentColor(color);
            setState(() {});
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: theme.colorScheme.primary, width: 3)
                  : Border.all(
                      color: theme.colorScheme.outlineVariant,
                      width: 1.5,
                    ),
              color: color,
            ),
            child: color == null
                ? Icon(Icons.auto_awesome, size: 20, color: theme.colorScheme.primary)
                : null,
          ),
        );
      }).toList(),
    );
  }

  bool _getExamModeEnabled() {
    final prefs = _serviceProvider.storeService
        .getPref<AppSettings>('app_settings', AppSettings.fromJson);
    return prefs?.examMode ?? false;
  }

  void _setExamModeEnabled(bool value) {
    final existing = _serviceProvider.storeService
        .getPref<AppSettings>('app_settings', AppSettings.fromJson);
    final updated = AppSettings(
      themeMode: existing?.themeMode ?? ThemeManager.currentThemeMode,
      accentColorValue:
          existing?.accentColorValue ?? ThemeManager.currentAccentColor?.toARGB32(),
      holidayMode: existing?.holidayMode ?? false,
      hapticFeedbackEnabled: existing?.hapticFeedbackEnabled ?? true,
      examMode: value,
    );
    _serviceProvider.storeService.putPref<AppSettings>(
      'app_settings',
      updated,
    );

    if (value) {
      _serviceProvider.storeService.delConfig('curriculum_data');
      _updateWidgetForExamMode();
    } else {
      WidgetUpdater().updateFromCurriculum(null);
    }
    _serviceProvider.notifySettingsChanged();
    setState(() {});
  }

  void _updateWidgetForExamMode() {
    final cached = _serviceProvider.storeService.getPref<CachedExamList>(
      'cached_exams',
      CachedExamList.fromJson,
    );
    if (cached != null && cached.exams.isNotEmpty) {
      WidgetUpdater().updateExams(cached.exams);
    }
  }

  Widget _buildExamModeToggle() {
    final enabled = _getExamModeEnabled();

    return Card.filled(
      shape: _noBorderShape,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '考试模式',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '清除课表，首页与小组件显示考试信息',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Switch(
              value: enabled,
              onChanged: (value) {
                Haptics.selection();
                _setExamModeEnabled(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _getHolidayMode() {
    final prefs = _serviceProvider.storeService
        .getPref<AppSettings>('app_settings', AppSettings.fromJson);
    return prefs?.holidayMode ?? false;
  }

  void _setHolidayMode(bool value) {
    final existing = _serviceProvider.storeService
        .getPref<AppSettings>('app_settings', AppSettings.fromJson);
    final updated = AppSettings(
      themeMode: existing?.themeMode ?? ThemeManager.currentThemeMode,
      accentColorValue:
          existing?.accentColorValue ?? ThemeManager.currentAccentColor?.toARGB32(),
      holidayMode: value,
    );
    _serviceProvider.storeService.putPref<AppSettings>(
      'app_settings',
      updated,
    );

    if (value) {
      _serviceProvider.storeService.delConfig('curriculum_data');
      WidgetUpdater().updateHoliday();
    } else {
      WidgetUpdater().updateFromCurriculum(null);
    }
    _serviceProvider.notifySettingsChanged();
    setState(() {});
  }

  Widget _buildHolidayToggle() {
    final enabled = _getHolidayMode();

    return Card.filled(
      shape: _noBorderShape,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '假期模式',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '清除课表，小组件显示假期祝福',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Switch(
              value: enabled,
              onChanged: (value) {
                Haptics.selection();
                _setHolidayMode(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _getHapticEnabled() {
    final prefs = _serviceProvider.storeService
        .getPref<AppSettings>('app_settings', AppSettings.fromJson);
    return prefs?.hapticFeedbackEnabled ?? true;
  }

  void _setHapticEnabled(bool value) {
    final existing = _serviceProvider.storeService
        .getPref<AppSettings>('app_settings', AppSettings.fromJson);
    final updated = AppSettings(
      themeMode: existing?.themeMode ?? ThemeManager.currentThemeMode,
      accentColorValue:
          existing?.accentColorValue ?? ThemeManager.currentAccentColor?.toARGB32(),
      holidayMode: existing?.holidayMode ?? false,
      hapticFeedbackEnabled: value,
    );
    _serviceProvider.storeService.putPref<AppSettings>(
      'app_settings',
      updated,
    );
    Haptics.refresh();
    setState(() {});
  }

  Widget _buildHapticToggle() {
    final enabled = _getHapticEnabled();

    return Card.filled(
      shape: _noBorderShape,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '触感反馈',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '按钮点击和手势操作时提供触感反馈',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Switch(
              value: enabled,
              onChanged: (value) {
                Haptics.selection();
                _setHapticEnabled(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  static const _batteryChannel = MethodChannel('com.lyme.beikenext/battery');

  Future<void> _requestBatteryOptimization() async {
    try {
      await _batteryChannel.invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开设置: $e')),
        );
      }
    }
  }

  Widget _buildBatteryOptimizationTile() {
    return Card.filled(
      shape: _noBorderShape,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '电池优化',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '关闭电池优化以确保课程提醒正常送达',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.tonalIcon(
              onPressed: () {
                Haptics.light();
                _requestBatteryOptimization();
              },
              icon: const Icon(Icons.battery_saver, size: 18),
              label: const Text('设置'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSection() {
    return Card.filled(
      shape: _noBorderShape,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '数据',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '除非您在使用本软件时出现问题，或技术支持人员要求您这么做，否则请勿轻易操作。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 16),
            _buildDataItem(
              title: '配置数据',
              subtitle: '清除所有配置数据，包括已登录的账号会话、数据缓存等。',
              isLoading: _isClearingCache,
              onPressed: _clearConfig,
            ),
            const SizedBox(height: 8),
            _buildDataItem(
              title: '偏好设置',
              subtitle: '清除所有偏好设置，包括本地设置等。',
              isLoading: _isClearingPrefs,
              onPressed: _clearPref,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataItem({
    required String title,
    required String subtitle,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyLarge),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          onPressed: isLoading ? null : () {
            Haptics.heavy();
            onPressed();
          },
          icon: isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.clear, size: 18),
          label: const Text('清除'),
        ),
      ],
    );
  }

  Widget _buildServiceSection() {
    return Card.filled(
      shape: _noBorderShape,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('API 配置', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '仅供开发人员调试使用。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 16),
            _buildServiceUrlConfig(
              label: '教务服务',
              defaultValue: _serviceProvider.coursesService.defaultBaseUrl,
              currentValue: _serviceProvider.coursesService.baseUrl,
              onChanged: (value) {
                _serviceProvider.coursesService.baseUrl = value;
                _serviceProvider.saveServiceSettings();
              },
            ),
            const SizedBox(height: 16),
            _buildServiceUrlConfig(
              label: '校园网管理服务',
              defaultValue: _serviceProvider.netService.defaultBaseUrl,
              currentValue: _serviceProvider.netService.baseUrl,
              onChanged: (value) {
                _serviceProvider.netService.baseUrl = value;
                _serviceProvider.saveServiceSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceUrlConfig({
    required String label,
    required String defaultValue,
    required String currentValue,
    required ValueChanged<String> onChanged,
  }) {
    final controller = TextEditingController(text: currentValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(border: const OutlineInputBorder()),
                onSubmitted: (value) {
                  final newUrl = value.trim().isEmpty ? defaultValue : value.trim();
                  onChanged(newUrl);
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '恢复默认',
              onPressed: () {
                Haptics.light();
                controller.clear();
                onChanged(defaultValue);
                setState(() {});
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _clearConfig() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除所有配置数据吗？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () { Haptics.light(); Navigator.of(context).pop(false); }, child: const Text('取消')),
          FilledButton(onPressed: () { Haptics.medium(); Navigator.of(context).pop(true); }, child: const Text('确认')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isClearingCache = true);
    try {
      _serviceProvider.storeService.delAllConfig();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('配置数据已清除')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('清除配置数据失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isClearingCache = false);
    }
  }

  Future<void> _clearPref() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除所有偏好设置吗？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () { Haptics.light(); Navigator.of(context).pop(false); }, child: const Text('取消')),
          FilledButton(onPressed: () { Haptics.medium(); Navigator.of(context).pop(true); }, child: const Text('确认')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isClearingPrefs = true);
    try {
      _serviceProvider.storeService.delAllPref();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('偏好设置已清除')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('清除偏好设置失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isClearingPrefs = false);
    }
  }

  IconData _getThemeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system: return Icons.brightness_auto;
      case ThemeMode.light: return Icons.light_mode;
      case ThemeMode.dark: return Icons.dark_mode;
    }
  }

  ThemeMode _getNextThemeMode(ThemeMode current) {
    switch (current) {
      case ThemeMode.system: return ThemeMode.light;
      case ThemeMode.light: return ThemeMode.dark;
      case ThemeMode.dark: return ThemeMode.system;
    }
  }
}
