import 'dart:math' as math;

import 'package:flutter/material.dart';

import '/services/library/seat_tags.dart';
import '/services/library/service.dart';
import '/types/library.dart';
import '/utils/haptic.dart';
import 'widgets.dart';

/// 选座：按馆区 + 日期 + 开始时间随机挑一个空座位。
///
/// 预约终点固定为闭馆；开始时间可选，首个选项为「现在」（明天从开馆起），之后按 30 分钟递增。
/// 只有窗口内**整段空闲**的座位才算候选（半空闲视为被占用），因此「现在」选项保证选到的座位
/// 立刻可用。馆区芯片上的「空 N」随所选开始时间联动，不使用 seatMenu 的 remainCount
/// （服务端会把半空闲座位算作可用）。
class SeatTab extends StatefulWidget {
  const SeatTab({super.key, required this.service});

  final LibraryService service;

  @override
  State<SeatTab> createState() => _SeatTabState();
}

class _SeatTabState extends State<SeatTab> {
  List<LibzwArea> _labs = const [];
  LibzwArea? _lab;
  LibzwArea? _room;

  bool _loadingMenu = true;
  String? _loadError;

  int _dayOffset = 0; // 0=今天, 1=明天
  String _roomOpenStart = '07:00';
  String _roomOpenEnd = '22:00';

  /// 所选开始时间（当天分钟数）；null = 取默认（今天=现在之后最近的可选时间，明天=开馆）
  int? _startMin;

  /// 是否有电源插座：1=是（要求带插座） 2=否（要求不带插座），默认 否
  int _powerFilter = 2;
  bool _busy = false;

  /// 当前楼层各馆区「整段空闲」座位数；未统计出（加载中/失败）的馆区不在表中
  Map<int, int>? _freeCounts;
  bool _counting = false;
  final Map<String, List<LibzwDevice>> _seatCache = {};
  int _countReq = 0;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  // ---- 数据加载 ----

  Future<void> _loadMenu() async {
    setState(() {
      _loadingMenu = true;
      _loadError = null;
    });
    try {
      final labs = await widget.service.getSeatMenu();
      if (!mounted) return;
      setState(() {
        _labs = labs;
        _lab = labs.isNotEmpty ? labs.first : null;
        _room = (_lab?.children.isNotEmpty ?? false) ? _lab!.children.first : null;
        _loadingMenu = false;
      });
      await _syncTimes();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = '$e';
          _loadingMenu = false;
        });
      }
    }
  }

  Future<void> _syncTimes() async {
    final room = _room;
    if (room == null) return;
    try {
      final open = await widget.service.getRoomOpenTimes(room.id, _dateDash);
      if (!mounted) return;
      setState(() {
        _roomOpenStart = open?.$1 ?? '07:00';
        _roomOpenEnd = open?.$2 ?? '22:00';
      });
    } catch (_) {
      // 取不到开放时间时沿用默认值
    }
    if (mounted) await _refreshCounts();
  }

  // ---- 空位数统计 ----

  /// 统计当前楼层各馆区的「整段空闲」座位数，口径与随机选座一致（半空闲视为占用）。
  Future<void> _refreshCounts({bool force = false}) async {
    final lab = _lab;
    if (lab == null || lab.children.isEmpty) return;

    // 固化发起时的日期：请求在途期间用户切换日期/馆区时，旧数据不得进入新键
    final ymd = _ymd;
    String keyOf(int roomId) => '$roomId-$ymd';
    if (!force &&
        lab.children.every((r) => _seatCache.containsKey(keyOf(r.id)))) {
      setState(() {
        _freeCounts = {
          for (final r in lab.children)
            r.id: _freeCountOf(_seatCache[keyOf(r.id)]!),
        };
      });
      return;
    }

    final req = ++_countReq;
    setState(() {
      _freeCounts = {};
      _counting = true;
    });
    for (final room in lab.children) {
      try {
        final cached = force ? null : _seatCache[keyOf(room.id)];
        final seats = cached ?? await widget.service.querySeats(room.id, ymd);
        if (!mounted || req != _countReq) return;
        final count = _freeCountOf(seats);
        _seatCache[keyOf(room.id)] = seats;
        setState(() {
          _freeCounts = {..._freeCounts!, room.id: count};
        });
      } catch (_) {
        // 单个馆区统计失败不影响其他馆区；该馆区回退显示服务端 remainCount
        if (!mounted || req != _countReq) return;
      }
    }
    if (!mounted || req != _countReq) return;
    setState(() => _counting = false);
  }

  int _freeCountOf(List<LibzwDevice> seats) {
    var n = 0;
    for (final s in seats) {
      if (!s.reservable) continue;
      final window = _windowFromOpen(s.openStart, s.openEnd);
      if (window == null) continue;
      final (begin, end) = window;
      if (end.isAfter(begin) && s.isFreeBetween(begin, end)) n++;
    }
    return n;
  }

  String _roomCountText(LibzwArea room) {
    final counts = _freeCounts;
    if (counts != null && counts.containsKey(room.id)) {
      return '${counts[room.id]}';
    }
    return _counting ? '…' : '${room.remainCount}';
  }

  // ---- 时间工具 ----

  DateTime get _day {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(Duration(days: _dayOffset));
  }

  String get _ymd =>
      '${_day.year}${_day.month.toString().padLeft(2, '0')}${_day.day.toString().padLeft(2, '0')}';

  String get _dateDash =>
      '${_day.year}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}';

  String get _dayLabel =>
      '${_dayOffset == 0 ? "今天" : "明天"} ${_day.month}/${_day.day}';

  static int _toMin(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  static String _fmt(int min) =>
      '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';

  static int _ceilTo5(int min) => ((min + 4) ~/ 5) * 5;

  static int _ceilTo30(int min) => ((min + 29) ~/ 30) * 30;

  /// 开始时间候选：首个 = 最早可约（今天已开馆时即「现在 +5 分钟」向上取整到 5 分钟，
  /// 与 resvRule.timeInterval=5 一致；明天或未开馆 = 开馆时间），之后按 30 分钟粒度递增；
  /// 最晚到距闭馆 30 分钟（最短预约时长）
  List<int> _startOptions() {
    final openStart = _toMin(_roomOpenStart);
    final openEnd = _toMin(_roomOpenEnd);
    var first = openStart;
    if (_dayOffset == 0) {
      final now = DateTime.now();
      first = math.max(openStart, _ceilTo5(now.hour * 60 + now.minute + 5));
    }
    if (first + 30 > openEnd) return const [];
    return [
      first,
      for (var t = _ceilTo30(first + 1); t + 30 <= openEnd; t += 30) t,
    ];
  }

  /// 当前生效的开始时间；所选时间已不在候选内（时间流逝/换了馆区）时回退到最早可选
  int? get _effectiveStart {
    final options = _startOptions();
    if (options.isEmpty) return null;
    final sel = _startMin;
    return sel != null && options.contains(sel) ? sel : options.first;
  }

  /// 预约窗口：起点 = 所选开始时间（不早于座位自身开放时间），终点 = 闭馆
  (DateTime, DateTime)? _windowFromOpen(String openStartHm, String openEndHm) {
    final startMin = _effectiveStart;
    if (startMin == null) return null;
    final seatOpen =
        _toMin(openStartHm.isEmpty ? _roomOpenStart : openStartHm);
    final beginMin = math.max(startMin, seatOpen);
    final endMin = _toMin(openEndHm.isEmpty ? _roomOpenEnd : openEndHm);
    return (
      DateTime(_day.year, _day.month, _day.day, beginMin ~/ 60, beginMin % 60),
      DateTime(_day.year, _day.month, _day.day, endMin ~/ 60, endMin % 60),
    );
  }

  (DateTime, DateTime)? _bookingWindow() {
    if (_room == null) return null;
    return _windowFromOpen(_roomOpenStart, _roomOpenEnd);
  }

  /// 今天已无任何可选开始时间（已闭馆或距闭馆不足 30 分钟）
  bool get _closedToday {
    if (_dayOffset != 0) return false;
    return _toMin(_roomOpenEnd) <=
        DateTime.now().hour * 60 + DateTime.now().minute;
  }

  // ---- 随机选座 ----

  Future<void> _pick() async {
    final room = _room;
    final window = _bookingWindow();
    if (room == null || window == null) return;
    final (begin, end) = window;
    setState(() => _busy = true);
    try {
      final seats = await widget.service.querySeats(room.id, _ymd);

      // 整段空闲才算候选：窗口内任何时段被占（半空闲）都视为被占用
      final candidates = seats
          .where((s) =>
              s.reservable &&
              s.isFreeBetween(begin, end) &&
              LibrarySeatTags.matches(
                s.devName,
                powerMode: _powerFilter,
              ))
          .toList();

      if (!mounted) return;
      if (candidates.isEmpty) {
        _snack('没有整段空闲且符合「是否有电源插座」选择的座位，试试切换选项、换馆区或明天');
        return;
      }

      final seat = candidates[math.Random().nextInt(candidates.length)];
      final beginMin = begin.hour * 60 + begin.minute;
      final endMin = end.hour * 60 + end.minute;
      final timeText = '$_dayLabel ${_fmt(beginMin)} - ${_fmt(endMin)}';
      final message = await showReserveConfirmSheet(
        context,
        service: widget.service,
        icon: Icons.event_seat,
        title: '座位 ${seat.devName}',
        subtitle: '${seat.labName} · ${seat.roomName}'
            '${candidates.length > 1 ? "（另有 ${candidates.length - 1} 个可选空位）" : ""}',
        timeText: timeText,
        sysKind: 8,
        devId: seat.devId,
        beginTime: '$_dateDash ${_fmt(beginMin)}:00',
        endTime: '$_dateDash ${_fmt(endMin)}:00',
      );

      if (message != null && mounted) {
        await showReserveSuccessDialog(
          context,
          headline: '预约成功',
          place: '座位号 ${seat.devName}\n${seat.labName} · ${seat.roomName}',
          timeText: timeText,
          serverMessage: message,
        );
        if (mounted) _refreshCounts(force: true);
      }
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loadingMenu) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () { Haptics.light(); _loadMenu(); },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final window = _bookingWindow();
    final startOptions = _startOptions();
    final startMin = _effectiveStart;
    // 首个候选在「今天且馆区已开放」时即「现在」，否则是开馆时间
    final firstIsNow = _dayOffset == 0 &&
        startOptions.isNotEmpty &&
        startOptions.first > _toMin(_roomOpenStart);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle(theme, '选择馆区'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _labs.map((lab) {
            return ChoiceChip(
              label: Text(lab.name),
              selected: lab.id == _lab?.id,
              onSelected: (_) {
                Haptics.selection();
                setState(() {
                  _lab = lab;
                  _room = lab.children.isNotEmpty ? lab.children.first : null;
                });
                _syncTimes();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        if (_lab != null)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _lab!.children.map((room) {
              return ChoiceChip(
                label: Text('${room.name}（空 ${_roomCountText(room)}）'),
                selected: room.id == _room?.id,
                onSelected: (_) {
                  Haptics.selection();
                  setState(() => _room = room);
                  _syncTimes();
                },
              );
            }).toList(),
          ),
        const SizedBox(height: 16),
        _sectionTitle(theme, '日期'),
        Wrap(
          spacing: 8,
          children: [0, 1].map((offset) {
            return ChoiceChip(
              label: Text(offset == 0 ? '今天' : '明天'),
              selected: _dayOffset == offset,
              onSelected: (_) {
                Haptics.selection();
                setState(() => _dayOffset = offset);
                _syncTimes();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _sectionTitle(theme, '开始时间（结束至闭馆）'),
        // 「现在」= 最早可约时间（5 分钟粒度），其余 30 分钟粒度
        if (startOptions.isEmpty)
          Text(
            '今天已无可选时段',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < startOptions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                        i == 0 && firstIsNow ? '现在' : _fmt(startOptions[i])),
                    selected: startOptions[i] == startMin,
                    onSelected: (_) {
                      Haptics.selection();
                      setState(() => _startMin =
                          i == 0 && firstIsNow ? null : startOptions[i]);
                      _refreshCounts();
                    },
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 16),
        _sectionTitle(theme, '是否有电源插座'),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('是'),
              selected: _powerFilter == 1,
              onSelected: (_) {
                Haptics.selection();
                setState(() => _powerFilter = 1);
              },
            ),
            ChoiceChip(
              label: const Text('否'),
              selected: _powerFilter == 2,
              onSelected: (_) {
                Haptics.selection();
                setState(() => _powerFilter = 2);
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _busy || _room == null || window == null
              ? null
              : () { Haptics.medium(); _pick(); },
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
          icon: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.casino_outlined),
          label: Text(_busy ? '正在挑选座位…' : '随机选座并预约'),
        ),
        const SizedBox(height: 10),
        Text(
          _closedToday
              ? '今日已闭馆（$_roomOpenEnd），明天再来吧'
              : startMin == null
              ? '距闭馆不足 30 分钟，现在无法预约，明天再来吧'
              : '将随机挑选一个 $_dayLabel ${_fmt(startMin)} - $_roomOpenEnd 整段空闲的座位',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
        ),
      ],
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
