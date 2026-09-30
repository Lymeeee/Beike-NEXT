// Copyright (c) 2025, Harry Huang

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'services/provider.dart';
import 'services/widget_updater.dart';
import 'types/preferences.dart';
import 'types/theme_cache.dart';
import 'utils/meta_info.dart';
import 'router.dart';

void main() async {
  // Initialize services before running the GUI
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize app info first (meta information like version, platform, device)
  await MetaInfo.instance.initialize();
  // Initialize service provider
  await ServiceProvider.instance.initializeServices();

  // Transparent status bar, let system decide icon brightness
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  runApp(const Main());
}

class ThemeManager {
  static ThemeMode _currentThemeMode = ThemeMode.system;
  static Color? _currentAccentColor;
  static Color? _currentSecondaryAccentColor;
  static void Function(ThemeMode)? _updateCallback;
  static void Function(Color?, Color?)? _accentColorCallback;

  static ThemeMode get currentThemeMode => _currentThemeMode;
  static Color? get currentAccentColor => _currentAccentColor;
  static Color? get currentSecondaryAccentColor => _currentSecondaryAccentColor;

  static void initialize(
    ThemeMode initialMode,
    Color? initialAccentColor,
    Color? initialSecondaryAccentColor,
    void Function(ThemeMode) updateCallback,
    void Function(Color?, Color?) accentColorCallback,
  ) {
    _currentThemeMode = initialMode;
    _currentAccentColor = initialAccentColor;
    _currentSecondaryAccentColor = initialSecondaryAccentColor;
    _updateCallback = updateCallback;
    _accentColorCallback = accentColorCallback;
  }

  static void updateThemeMode(ThemeMode themeMode) {
    _currentThemeMode = themeMode;
    _updateCallback?.call(themeMode);
  }

  static void updateAccentColor(Color? color, Color? secondaryColor) {
    _currentAccentColor = color;
    _currentSecondaryAccentColor = secondaryColor;
    _accentColorCallback?.call(color, secondaryColor);
  }
}

class Main extends StatefulWidget {
  const Main({super.key});

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;
  late ThemeMode _themeMode;
  Color? _accentColor;
  Color? _secondaryAccentColor;
  CachedDynamicScheme? _cachedDynamicScheme;
  ColorScheme? _cachedLightScheme;
  ColorScheme? _cachedDarkScheme;
  String? _pushedWidgetTheme;

  _MainState() {
    final appSettings =
        _serviceProvider.storeService
            .getPref<AppSettings>('app_settings', AppSettings.fromJson);

    _themeMode = appSettings?.themeMode ?? ThemeMode.system;
    _accentColor = appSettings?.accentColor;
    _secondaryAccentColor = appSettings?.secondaryAccentColor;
    _cachedDynamicScheme = _serviceProvider.storeService
        .getConfig<CachedDynamicScheme>(
          'cached_dynamic_scheme',
          CachedDynamicScheme.fromJson,
        );
    _cachedLightScheme = _cachedDynamicScheme?.schemeFor(Brightness.light);
    _cachedDarkScheme = _cachedDynamicScheme?.schemeFor(Brightness.dark);

    _updateStatusBarStyle(_themeMode);

    ThemeManager.initialize(
      _themeMode,
      _accentColor,
      _secondaryAccentColor,
      (ThemeMode themeMode) {
        setState(() => _themeMode = themeMode);
        _updateStatusBarStyle(themeMode);
        _persistSettings();
      },
      (Color? accentColor, Color? secondaryAccentColor) {
        setState(() {
          _accentColor = accentColor;
          _secondaryAccentColor = secondaryAccentColor;
        });
        _persistSettings();
      },
    );
  }

  void _updateStatusBarStyle(ThemeMode mode) {
    final bool isDark = switch (mode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
    };
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));
  }

  void _persistSettings() {
    final existing = _serviceProvider.storeService
        .getPref<AppSettings>('app_settings', AppSettings.fromJson);
    final appSettings = (existing ?? AppSettings.defaultSettings).copyWith(
      themeMode: _themeMode,
      accentColorValue: _accentColor?.toARGB32(),
      secondaryAccentColorValue: _secondaryAccentColor?.toARGB32(),
    );
    _serviceProvider.storeService.putPref<AppSettings>(
      'app_settings',
      appSettings,
    );
  }

  static const Color _defaultSeedColor = Color.fromRGBO(0, 91, 148, 1.0);

  /// 单色预设下背景族向中性色的混合比例：底色浓度轻减（预览 k=0.3）
  static const double _singleColorBackgroundBlend = 0.3;

  Color get _effectiveSeedColor => _accentColor ?? _defaultSeedColor;

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    return ThemeData(
      colorScheme: colorScheme,
      fontFamily: 'MiSans',
      useMaterial3: true,
      // AppBar
      appBarTheme: AppBarTheme(
        centerTitle: false,
        titleSpacing: 8,
        scrolledUnderElevation: 4,
        surfaceTintColor: Colors.transparent,
      ),
      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      // Dialogs
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.04);
          }
          return colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
        }),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      // Navigation
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: colorScheme.primaryContainer,
        // 指示胶囊换成 primaryContainer 后，图标不能再用 M3 默认的
        // onSecondaryContainer：深色种子下两者都深，图标会糊在胶囊里
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      // Dividers
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
      ),
      // Chips
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
        backgroundColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primaryContainer;
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),
      // Progress indicators
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearMinHeight: 4,
      ),
      // Bottom sheet
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      // Tab bar
      tabBarTheme: TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
      ),
      // Snackbar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      // Dropdown
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      // Popup menu
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // 选过预设色：点缀族（primary/secondary/tertiary 及其容器）走种子，
  // 双拼时用副色、单色时用主色，按钮、开关、导航指示就是那个颜色本身；
  // 背景族走主色的 vibrant 中性色——rainbow 的中性色 chroma 固定为 0，
  // 用它推的话不管什么种子，背景都是同一片纯灰。
  // 点缀用 content：调色板取种子自身的色度；rainbow 的 chroma 有 48，
  // tone 90 的容器（导航指示、选中态）会亮成荧光条。
  // 文字、图标、分隔线另用 neutral 取（中性色 chroma 2）：跟 vibrant 的
  // chroma 10 比起来，带色相的灰会糊成脏滤镜，这几族占了界面绝大多数元素。
  ColorScheme _seedScheme(Brightness brightness) {
    final accent = ColorScheme.fromSeed(
      seedColor: _secondaryAccentColor ?? _effectiveSeedColor,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.content,
    );
    final background = ColorScheme.fromSeed(
      seedColor: _effectiveSeedColor,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
    );
    final neutral = ColorScheme.fromSeed(
      seedColor: _effectiveSeedColor,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.neutral,
    );
    // 单色预设：背景族向中性色轻混，降低底色浓度；双拼模式保持原样
    Color backgroundOf(Color vibrantColor, Color neutralColor) =>
        _secondaryAccentColor == null
            ? Color.lerp(vibrantColor, neutralColor, _singleColorBackgroundBlend)!
            : vibrantColor;
    return accent.copyWith(
      surface: backgroundOf(background.surface, neutral.surface),
      onSurface: neutral.onSurface,
      surfaceDim: backgroundOf(background.surfaceDim, neutral.surfaceDim),
      surfaceBright: backgroundOf(background.surfaceBright, neutral.surfaceBright),
      surfaceContainerLowest:
          backgroundOf(background.surfaceContainerLowest, neutral.surfaceContainerLowest),
      surfaceContainerLow:
          backgroundOf(background.surfaceContainerLow, neutral.surfaceContainerLow),
      surfaceContainer:
          backgroundOf(background.surfaceContainer, neutral.surfaceContainer),
      surfaceContainerHigh:
          backgroundOf(background.surfaceContainerHigh, neutral.surfaceContainerHigh),
      surfaceContainerHighest: backgroundOf(
          background.surfaceContainerHighest, neutral.surfaceContainerHighest),
      onSurfaceVariant: neutral.onSurfaceVariant,
      outline: neutral.outline,
      outlineVariant: neutral.outlineVariant,
      inverseSurface: backgroundOf(background.inverseSurface, neutral.inverseSurface),
      onInverseSurface: neutral.onInverseSurface,
    );
  }

  /// 没选过预设色就跟随系统动态取色，动态配色还没回包时用上次缓存顶上，
  /// 避免冷启动首帧闪默认色；平台不支持动态配色时退回默认种子色。
  ColorScheme _resolveScheme(
    ColorScheme? dynamic,
    ColorScheme? cached,
    Brightness brightness,
  ) {
    if (_accentColor != null || _secondaryAccentColor != null) {
      return _seedScheme(brightness);
    }
    return dynamic ?? cached ?? _seedScheme(brightness);
  }

  /// 桌面小组件跟着主题配色走：每个角色给浅色和深色两个值，
  /// 由小组件按系统的日夜模式挑用
  void _pushWidgetTheme(ColorScheme light, ColorScheme dark) {
    List<int> pair(Color Function(ColorScheme) pick) =>
        [pick(light).toARGB32(), pick(dark).toARGB32()];
    final payload = <String, List<int>>{
      'background': pair((scheme) => scheme.surfaceContainerHighest),
      'textPrimary': pair((scheme) => scheme.onSurface),
      'textSecondary': pair((scheme) => scheme.onSurfaceVariant),
      'textTertiary': pair((scheme) => scheme.outline),
    };
    final signature = payload.toString();
    if (signature == _pushedWidgetTheme) return;
    _pushedWidgetTheme = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetUpdater().updateThemeColors(payload);
    });
  }

  void _cacheDynamicSchemes(ColorScheme light, ColorScheme dark) {
    final next = CachedDynamicScheme.fromSchemes(light, dark);
    if (next == _cachedDynamicScheme) return;
    _cachedDynamicScheme = next;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _serviceProvider.storeService.putConfig<CachedDynamicScheme>(
        'cached_dynamic_scheme',
        next,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        if (_accentColor == null && lightDynamic != null && darkDynamic != null) {
          _cacheDynamicSchemes(lightDynamic, darkDynamic);
        }

        final lightScheme = _resolveScheme(
          lightDynamic,
          _cachedLightScheme,
          Brightness.light,
        );
        final darkScheme = _resolveScheme(
          darkDynamic,
          _cachedDarkScheme,
          Brightness.dark,
        );
        _pushWidgetTheme(lightScheme, darkScheme);

        return MaterialApp.router(
          title: 'Beike NEXT',
          theme: _buildTheme(lightScheme),
          darkTheme: _buildTheme(darkScheme),
          themeMode: _themeMode,
          routerConfig: AppRouter.router.config(),
        );
      },
    );
  }
}
