import 'package:flutter/services.dart';
import '/services/provider.dart';
import '/types/preferences.dart';

class Haptics {
  static bool? _cachedEnabled;

  static bool get _enabled {
    _cachedEnabled ??= _readEnabled();
    return _cachedEnabled!;
  }

  static bool _readEnabled() {
    final prefs = ServiceProvider.instance.storeService
        .getPref<AppSettings>('app_settings', AppSettings.fromJson);
    return prefs?.hapticFeedbackEnabled ?? true;
  }

  /// Call after toggling the haptic setting to invalidate the cache.
  static void refresh() => _cachedEnabled = null;

  static void light() {
    if (_enabled) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (_enabled) HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (_enabled) HapticFeedback.heavyImpact();
  }

  static void selection() {
    if (_enabled) HapticFeedback.selectionClick();
  }
}
