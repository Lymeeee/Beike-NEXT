// Copyright (c) 2025, Harry Huang

import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'services/provider.dart';
import 'types/preferences.dart';
import 'utils/meta_info.dart';
import 'router.dart';

void main() async {
  // Initialize services before running the GUI
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize app info first (meta information like version, platform, device)
  await MetaInfo.instance.initialize();
  // Initialize service provider
  await ServiceProvider.instance.initializeServices();
  // Run the GUI application
  runApp(const Main());
}

class ThemeManager {
  static ThemeMode _currentThemeMode = ThemeMode.system;
  static void Function(ThemeMode)? _updateCallback;

  static ThemeMode get currentThemeMode => _currentThemeMode;

  static void initialize(
    ThemeMode initialMode,
    void Function(ThemeMode) updateCallback,
  ) {
    _currentThemeMode = initialMode;
    _updateCallback = updateCallback;
  }

  static void updateThemeMode(ThemeMode themeMode) {
    _currentThemeMode = themeMode;
    _updateCallback?.call(themeMode);
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

  _MainState() {
    _themeMode =
        _serviceProvider.storeService
            .getPref<AppSettings>('app_settings', AppSettings.fromJson)
            ?.themeMode ??
        ThemeMode.system;

    ThemeManager.initialize(_themeMode, (ThemeMode themeMode) {
      setState(() {
        _themeMode = themeMode;
      });
      final appSettings = AppSettings(themeMode: themeMode);
      _serviceProvider.storeService.putPref<AppSettings>(
        'app_settings',
        appSettings,
      );
    });
  }

  static const Color _seedColor = Color.fromRGBO(0, 91, 148, 1.0);

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    return ThemeData(
      colorScheme: colorScheme,
      fontFamily: 'SourceHanSansSC',
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final lightScheme = lightDynamic ??
            ColorScheme.fromSeed(
              seedColor: _seedColor,
              brightness: Brightness.light,
              dynamicSchemeVariant: DynamicSchemeVariant.rainbow,
            );
        final darkScheme = darkDynamic ??
            ColorScheme.fromSeed(
              seedColor: _seedColor,
              brightness: Brightness.dark,
              dynamicSchemeVariant: DynamicSchemeVariant.rainbow,
            );

        return MaterialApp.router(
          title: 'TheBeike',
          theme: _buildTheme(lightScheme),
          darkTheme: _buildTheme(darkScheme),
          themeMode: _themeMode,
          routerConfig: AppRouter.router.config(),
        );
      },
    );
  }
}
