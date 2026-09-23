import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'base.dart';

part 'theme_cache.g.dart';

/// 上次解析到的系统动态配色缓存。
///
/// 动态配色要异步走平台通道，冷启动首帧拿不到，先用这份缓存顶上，
/// 让首帧就是上次系统配色的样子，避免闪一下默认色。
@JsonSerializable()
class CachedDynamicScheme extends BaseDataClass {
  Map<String, int> light;
  Map<String, int> dark;

  CachedDynamicScheme({this.light = const {}, this.dark = const {}});

  static CachedDynamicScheme fromSchemes(ColorScheme light, ColorScheme dark) =>
      CachedDynamicScheme(light: _flatten(light), dark: _flatten(dark));

  /// 还原配色；缓存里缺的角色退回种子推导值
  ColorScheme? schemeFor(Brightness brightness) {
    final values = brightness == Brightness.dark ? dark : light;
    final seed = values['primary'];
    if (seed == null) return null;
    Color? role(String name) =>
        values[name] == null ? null : Color(values[name]!);
    return ColorScheme.fromSeed(
      seedColor: Color(seed),
      brightness: brightness,
    ).copyWith(
      primary: role('primary'),
      onPrimary: role('onPrimary'),
      primaryContainer: role('primaryContainer'),
      onPrimaryContainer: role('onPrimaryContainer'),
      primaryFixed: role('primaryFixed'),
      primaryFixedDim: role('primaryFixedDim'),
      onPrimaryFixed: role('onPrimaryFixed'),
      onPrimaryFixedVariant: role('onPrimaryFixedVariant'),
      secondary: role('secondary'),
      onSecondary: role('onSecondary'),
      secondaryContainer: role('secondaryContainer'),
      onSecondaryContainer: role('onSecondaryContainer'),
      secondaryFixed: role('secondaryFixed'),
      secondaryFixedDim: role('secondaryFixedDim'),
      onSecondaryFixed: role('onSecondaryFixed'),
      onSecondaryFixedVariant: role('onSecondaryFixedVariant'),
      tertiary: role('tertiary'),
      onTertiary: role('onTertiary'),
      tertiaryContainer: role('tertiaryContainer'),
      onTertiaryContainer: role('onTertiaryContainer'),
      tertiaryFixed: role('tertiaryFixed'),
      tertiaryFixedDim: role('tertiaryFixedDim'),
      onTertiaryFixed: role('onTertiaryFixed'),
      onTertiaryFixedVariant: role('onTertiaryFixedVariant'),
      error: role('error'),
      onError: role('onError'),
      errorContainer: role('errorContainer'),
      onErrorContainer: role('onErrorContainer'),
      surface: role('surface'),
      onSurface: role('onSurface'),
      surfaceDim: role('surfaceDim'),
      surfaceBright: role('surfaceBright'),
      surfaceContainerLowest: role('surfaceContainerLowest'),
      surfaceContainerLow: role('surfaceContainerLow'),
      surfaceContainer: role('surfaceContainer'),
      surfaceContainerHigh: role('surfaceContainerHigh'),
      surfaceContainerHighest: role('surfaceContainerHighest'),
      onSurfaceVariant: role('onSurfaceVariant'),
      outline: role('outline'),
      outlineVariant: role('outlineVariant'),
      shadow: role('shadow'),
      scrim: role('scrim'),
      inverseSurface: role('inverseSurface'),
      onInverseSurface: role('onInverseSurface'),
      inversePrimary: role('inversePrimary'),
      surfaceTint: role('surfaceTint'),
    );
  }

  @override
  Map<String, dynamic> getEssentials() => {
    'light': _canonical(light),
    'dark': _canonical(dark),
  };

  // Map 没有值相等语义，比较与哈希统一走规范化字符串
  static String _canonical(Map<String, int> values) =>
      (values.entries.map((e) => '${e.key}=${e.value}').toList()..sort())
          .join(',');

  static Map<String, int> _flatten(ColorScheme s) => {
    'primary': s.primary.toARGB32(),
    'onPrimary': s.onPrimary.toARGB32(),
    'primaryContainer': s.primaryContainer.toARGB32(),
    'onPrimaryContainer': s.onPrimaryContainer.toARGB32(),
    'primaryFixed': s.primaryFixed.toARGB32(),
    'primaryFixedDim': s.primaryFixedDim.toARGB32(),
    'onPrimaryFixed': s.onPrimaryFixed.toARGB32(),
    'onPrimaryFixedVariant': s.onPrimaryFixedVariant.toARGB32(),
    'secondary': s.secondary.toARGB32(),
    'onSecondary': s.onSecondary.toARGB32(),
    'secondaryContainer': s.secondaryContainer.toARGB32(),
    'onSecondaryContainer': s.onSecondaryContainer.toARGB32(),
    'secondaryFixed': s.secondaryFixed.toARGB32(),
    'secondaryFixedDim': s.secondaryFixedDim.toARGB32(),
    'onSecondaryFixed': s.onSecondaryFixed.toARGB32(),
    'onSecondaryFixedVariant': s.onSecondaryFixedVariant.toARGB32(),
    'tertiary': s.tertiary.toARGB32(),
    'onTertiary': s.onTertiary.toARGB32(),
    'tertiaryContainer': s.tertiaryContainer.toARGB32(),
    'onTertiaryContainer': s.onTertiaryContainer.toARGB32(),
    'tertiaryFixed': s.tertiaryFixed.toARGB32(),
    'tertiaryFixedDim': s.tertiaryFixedDim.toARGB32(),
    'onTertiaryFixed': s.onTertiaryFixed.toARGB32(),
    'onTertiaryFixedVariant': s.onTertiaryFixedVariant.toARGB32(),
    'error': s.error.toARGB32(),
    'onError': s.onError.toARGB32(),
    'errorContainer': s.errorContainer.toARGB32(),
    'onErrorContainer': s.onErrorContainer.toARGB32(),
    'surface': s.surface.toARGB32(),
    'onSurface': s.onSurface.toARGB32(),
    'surfaceDim': s.surfaceDim.toARGB32(),
    'surfaceBright': s.surfaceBright.toARGB32(),
    'surfaceContainerLowest': s.surfaceContainerLowest.toARGB32(),
    'surfaceContainerLow': s.surfaceContainerLow.toARGB32(),
    'surfaceContainer': s.surfaceContainer.toARGB32(),
    'surfaceContainerHigh': s.surfaceContainerHigh.toARGB32(),
    'surfaceContainerHighest': s.surfaceContainerHighest.toARGB32(),
    'onSurfaceVariant': s.onSurfaceVariant.toARGB32(),
    'outline': s.outline.toARGB32(),
    'outlineVariant': s.outlineVariant.toARGB32(),
    'shadow': s.shadow.toARGB32(),
    'scrim': s.scrim.toARGB32(),
    'inverseSurface': s.inverseSurface.toARGB32(),
    'onInverseSurface': s.onInverseSurface.toARGB32(),
    'inversePrimary': s.inversePrimary.toARGB32(),
    'surfaceTint': s.surfaceTint.toARGB32(),
  };

  factory CachedDynamicScheme.fromJson(Map<String, dynamic> json) =>
      _$CachedDynamicSchemeFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$CachedDynamicSchemeToJson(this);
}
