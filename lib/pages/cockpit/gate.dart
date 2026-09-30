import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '/services/provider.dart';
import '/types/preferences.dart';

/// 中控模式（横屏看板）的进入判定与手动退出抑制。
///
/// 用户在横屏下主动退出后置位抑制标志，直到观察到竖屏才清除——
/// 即"手动退出后不再自动进入，转回竖屏再转横屏才重新进入"。
class CockpitGate {
  static const String routePath = '/cockpit';

  static final CockpitGate instance = CockpitGate._();

  CockpitGate._();

  bool _suppressed = false;

  /// 仅手机/平板支持，桌面三平台不触发
  static bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  bool get isSuppressed => _suppressed;

  void suppress() => _suppressed = true;

  void clearSuppression() => _suppressed = false;

  /// 仅横屏时抑制；竖屏自动退出不应抑制
  void suppressIfLandscape(BuildContext context) {
    if (MediaQuery.orientationOf(context) == Orientation.landscape) {
      suppress();
    }
  }

  /// 现读设置不缓存，避免与设置页状态不同步；旧数据无该键时默认开启
  bool get isEnabledInSettings {
    final prefs = ServiceProvider.instance.storeService
        .getPref<AppSettings>('app_settings', AppSettings.fromJson);
    return prefs?.cockpitMode ?? true;
  }
}
