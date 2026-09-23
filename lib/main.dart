// Copyright (c) 2025, Harry Huang

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'services/provider.dart';
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
    final appSettings = AppSettings(
      themeMode: _themeMode,
      accentColorValue: _accentColor?.toARGB32(),
      secondaryAccentColorValue: _secondaryAccentColor?.toARGB32(),
      holidayMode: existing?.holidayMode ?? false,
      hapticFeedbackEnabled: existing?.hapticFeedbackEnabled ?? true,
      examMode: existing?.examMode ?? false,
    );
    _serviceProvider.storeService.putPref<AppSettings>(
      'app_settings',
      appSettings,
    );
  }

  static const Color _defaultSeedColor = Color.fromRGBO(0, 91, 148, 1.0);

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

  // 双拼预设：副色种子单独推一套方案，只顶替 secondary/tertiary 这一族，
  // 让主色管主体、副色管点缀，保持 M3 的明度关系不被原始色值破坏
  ColorScheme _withSecondaryAccent(ColorScheme scheme, Brightness brightness) {
    final secondarySeed = _secondaryAccentColor;
    if (secondarySeed == null) return scheme;
    final accent = ColorScheme.fromSeed(
      seedColor: secondarySeed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.rainbow,
    );
    return scheme.copyWith(
      secondary: accent.secondary,
      onSecondary: accent.onSecondary,
      secondaryContainer: accent.secondaryContainer,
      onSecondaryContainer: accent.onSecondaryContainer,
      tertiary: accent.tertiary,
      onTertiary: accent.onTertiary,
      tertiaryContainer: accent.tertiaryContainer,
      onTertiaryContainer: accent.onTertiaryContainer,
    );
  }

  /// 动态配色还没回包时用上次缓存顶上，避免冷启动首帧闪默认色
  ColorScheme _pickScheme(
    ColorScheme? dynamic,
    ColorScheme? cached,
    Brightness brightness,
  ) {
    if (_accentColor != null) {
      return ColorScheme.fromSeed(
        seedColor: _effectiveSeedColor,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.rainbow,
      );
    }
    return dynamic ??
        cached ??
        ColorScheme.fromSeed(
          seedColor: _effectiveSeedColor,
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.rainbow,
        );
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

        final lightScheme = _withSecondaryAccent(
          _pickScheme(lightDynamic, _cachedLightScheme, Brightness.light),
          Brightness.light,
        );
        final darkScheme = _withSecondaryAccent(
          _pickScheme(darkDynamic, _cachedDarkScheme, Brightness.dark),
          Brightness.dark,
        );

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
