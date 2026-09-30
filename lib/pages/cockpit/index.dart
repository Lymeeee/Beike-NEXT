import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/services/library/service.dart';
import '/services/provider.dart';
import '/types/courses.dart';
import '/types/library.dart';
import '/types/preferences.dart';
import '/utils/reservation_view.dart';
import 'data.dart';
import 'gate.dart';
import 'zones.dart';

/// 中控模式：首页横屏时自动进入的全屏看板。
/// 数据全部本地缓存优先，转回竖屏自动退出。
class CockpitPage extends StatefulWidget {
  const CockpitPage({super.key});

  @override
  State<CockpitPage> createState() => _CockpitPageState();
}

class _CockpitPageState extends State<CockpitPage> with WidgetsBindingObserver {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;
  final LibraryService _libraryService = LibraryService();

  CurriculumIntegratedData? _curriculum;
  List<LibzwReservation> _reservations = const [];
  List<ExamInfo> _exams = const [];
  bool _holidayMode = false;
  bool _examMode = false;
  bool _libraryLoggedIn = false;

  DateTime _now = DateTime.now();
  late int _lastDay;
  DateTime _lastPrefsRead = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastReservationsFetch = DateTime.fromMillisecondsSinceEpoch(0);
  bool _reservationsFetching = false;
  bool _popping = false;
  Orientation? _lastOrientation;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastDay = _now.day;
    _readPrefs(notify: false);
    _applyImmersive();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadReservations();
    });
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _restoreSystemUi();
    // 手动退出（含返回手势）时抑制，直到观察到竖屏
    if (_lastOrientation == Orientation.landscape) {
      CockpitGate.instance.suppress();
    }
    _libraryService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 后台回来系统栏可能复现，重进沉浸；顺带刷新预约
      _applyImmersive();
      _loadReservations();
    }
  }

  void _onTick() {
    final now = DateTime.now();
    if (now.day != _lastDay) {
      _lastDay = now.day;
      _readPrefs();
      _loadReservations();
    } else {
      if (now.difference(_lastPrefsRead).inSeconds >= 60) _readPrefs();
      if (now.difference(_lastReservationsFetch).inSeconds >= 300) {
        _loadReservations();
      }
    }
    if (mounted) setState(() => _now = now);
  }

  void _readPrefs({bool notify = true}) {
    final store = _serviceProvider.storeService;
    final prefs =
        store.getPref<AppSettings>('app_settings', AppSettings.fromJson);
    final exams =
        store.getPref<CachedExamList>('cached_exams', CachedExamList.fromJson);
    final merged = readMergedCurriculum(store);
    _lastPrefsRead = DateTime.now();

    if (notify && mounted) {
      setState(() {
        _holidayMode = prefs?.holidayMode ?? false;
        _examMode = prefs?.examMode ?? false;
        _exams = exams?.exams ?? const [];
        _curriculum = merged;
      });
    } else {
      _holidayMode = prefs?.holidayMode ?? false;
      _examMode = prefs?.examMode ?? false;
      _exams = exams?.exams ?? const [];
      _curriculum = merged;
    }
  }

  /// 缓存优先（复刻首页）：先上屏缓存，再联网刷新，失败保留缓存
  Future<void> _loadReservations() async {
    if (_reservationsFetching) return;
    final saved = _serviceProvider.storeService
        .getConfig<LibzwSession>(LibzwSession.storeKey, LibzwSession.fromJson);
    if (saved == null || !saved.isValid) {
      if (mounted && (_libraryLoggedIn || _reservations.isNotEmpty)) {
        setState(() {
          _libraryLoggedIn = false;
          _reservations = const [];
        });
      }
      return;
    }

    _reservationsFetching = true;
    try {
      final cached =
          filterUpcomingReservations(_libraryService.readCachedReservations());
      if (mounted) {
        setState(() {
          _libraryLoggedIn = true;
          _reservations = cached;
        });
      }

      _libraryService.applySession(saved);
      final list = await _libraryService.getMyReservations(
        beginDateDash: _dashYmd(DateTime.now()),
        endDateDash: _dashYmd(DateTime.now().add(const Duration(days: 1))),
      );
      if (mounted) {
        setState(() => _reservations = filterUpcomingReservations(list));
      }
    } catch (_) {
      // 登录过期/网络异常：保留缓存展示
    } finally {
      _reservationsFetching = false;
      _lastReservationsFetch = DateTime.now();
    }
  }

  void _exit() {
    CockpitGate.instance.suppressIfLandscape(context);
    Navigator.of(context).maybePop();
  }

  Future<void> _applyImmersive() async {
    try {
      if (Platform.isAndroid) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else if (Platform.isIOS) {
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: [SystemUiOverlay.bottom],
        );
      }
    } catch (_) {}
  }

  Future<void> _restoreSystemUi() async {
    try {
      if (Platform.isAndroid) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } else if (Platform.isIOS) {
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        );
      }
    } catch (_) {}
  }

  static String _dashYmd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.orientationOf(context);
    _lastOrientation = orientation;
    if (orientation == Orientation.portrait && !_popping) {
      _popping = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }

    final snapshot = buildCockpitSnapshot(
      now: _now,
      merged: _curriculum,
      coursesOnline: _serviceProvider.coursesService.isOnline,
      holidayMode: _holidayMode,
      examMode: _examMode,
      libraryLoggedIn: _libraryLoggedIn,
      reservations: _reservations,
      exams: _exams,
    );

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) CockpitGate.instance.suppressIfLandscape(context);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final metrics = CockpitMetrics.of(size);
              final leftW = metrics.compact
                  ? (size.width * 0.25).clamp(150.0, 230.0)
                  : (size.width * 0.24).clamp(240.0, 380.0);
              var rightW = metrics.compact
                  ? (size.width * 0.28).clamp(170.0, 280.0)
                  : (size.width * 0.30).clamp(300.0, 460.0);
              // 狭窄时先缩右区再缩左区，保证中区始终可用且不溢出
              final middleW = size.width -
                  metrics.pagePadding * 2 -
                  metrics.gap * 2 -
                  leftW -
                  rightW;
              if (middleW < 240) {
                rightW = (rightW - (240 - middleW)).clamp(120.0, rightW);
              }

              return Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.all(metrics.pagePadding),
                    child: Row(
                      children: [
                        SizedBox(
                          width: leftW,
                          child: CockpitClockPane(
                            snapshot: snapshot,
                            metrics: metrics,
                          ),
                        ),
                        SizedBox(width: metrics.gap),
                        Expanded(
                          child: CockpitSchedulePane(
                            snapshot: snapshot,
                            metrics: metrics,
                          ),
                        ),
                        SizedBox(width: metrics.gap),
                        SizedBox(
                          width: rightW,
                          child: CockpitAgendaPane(
                            snapshot: snapshot,
                            metrics: metrics,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: metrics.pagePadding - 6,
                    right: metrics.pagePadding - 6,
                    child: IconButton(
                      tooltip: '退出中控模式',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _exit,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
