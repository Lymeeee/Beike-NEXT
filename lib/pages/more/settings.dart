import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '/services/provider.dart';
import '/services/class_reminder_service.dart';
import '/services/widget_updater.dart';
import '/main.dart';
import '/types/preferences.dart';

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
  final ServiceProvider _serviceProvider = ServiceProvider.instance;
  bool _isClearingCache = false;
  bool _isClearingPrefs = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
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
          _buildReminderToggle(),
          const SizedBox(height: 16),
          _buildHolidayToggle(),
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

  bool _getReminderEnabled() {
    final prefs = _serviceProvider.storeService
        .getPref<AppSettings>('app_settings', AppSettings.fromJson);
    return prefs?.classReminderEnabled ?? false;
  }

  void _setReminderEnabled(bool value) {
    final existing = _serviceProvider.storeService
        .getPref<AppSettings>('app_settings', AppSettings.fromJson);
    final updated = AppSettings(
      themeMode: existing?.themeMode ?? ThemeManager.currentThemeMode,
      accentColorValue:
          existing?.accentColorValue ?? ThemeManager.currentAccentColor?.toARGB32(),
      classReminderEnabled: value,
    );
    _serviceProvider.storeService.putPref<AppSettings>(
      'app_settings',
      updated,
    );

    if (value) {
      ClassReminderService.instance.requestPermission();
      ClassReminderService.instance.start();
    } else {
      ClassReminderService.instance.stop();
    }
    setState(() {});
  }

  Widget _buildReminderToggle() {
    final enabled = _getReminderEnabled();

    return Card.filled(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '课程提醒',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '课前25分钟发送通知',
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
              onChanged: _setReminderEnabled,
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
      classReminderEnabled: existing?.classReminderEnabled ?? false,
      holidayMode: value,
    );
    _serviceProvider.storeService.putPref<AppSettings>(
      'app_settings',
      updated,
    );

    if (value) {
      _serviceProvider.storeService.delConfig('curriculum_data');
      ClassReminderService.instance.stop();
      WidgetUpdater().updateHoliday();
    } else {
      ClassReminderService.instance.start();
      WidgetUpdater().updateFromCurriculum(null);
    }
    setState(() {});
  }

  Widget _buildHolidayToggle() {
    final enabled = _getHolidayMode();

    return Card.filled(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
              onChanged: _setHolidayMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSection() {
    return Card.filled(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          onPressed: isLoading ? null : onPressed,
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('确认')),
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
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('确认')),
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
