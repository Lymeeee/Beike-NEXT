import 'dart:math' as math;

import 'package:flutter/material.dart';

import '/services/library/seat_tags.dart';
import '/services/library/service.dart';
import '/types/library.dart';
import '/utils/haptic.dart';
import 'widgets.dart';

/// 选座：按馆区 + 日期随机挑一个空座位。
///
/// 预约窗口固定为「现在(+1分钟) → 闭馆」（明天 = 开馆 → 闭馆），无需选择时段；
/// 按用户约定，只有窗口内**整段空闲**的座位才算候选（半空闲视为被占用）。
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

  /// 是否有电源插座：1=是（要求带插座） 2=否（要求不带插座），默认 否
  int _powerFilter = 2;
  bool _busy = false;

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

  /// 预约窗口：今天=现在(+1分钟)→闭馆；明天=开馆→闭馆
  (DateTime, DateTime)? _bookingWindow() {
    final room = _room;
    if (room == null) return null;
    final openStart = _toMin(_roomOpenStart);
    final openEnd = _toMin(_roomOpenEnd);
    DateTime start;
    if (_dayOffset == 0) {
      final s = DateTime.now().add(const Duration(minutes: 1));
      start = DateTime(s.year, s.month, s.day, s.hour, s.minute);
    } else {
      start = DateTime(
          _day.year, _day.month, _day.day, openStart ~/ 60, openStart % 60);
    }
    final end =
        DateTime(_day.year, _day.month, _day.day, openEnd ~/ 60, openEnd % 60);
    return (start, end);
  }

  bool get _windowTooShort {
    if (_dayOffset != 0) return false;
    final w = _bookingWindow();
    if (w == null) return false;
    return !w.$2.isAfter(w.$1.add(const Duration(minutes: 30)));
  }

  // ---- 随机选座 ----

  Future<void> _pick() async {
    final room = _room;
    final window = _bookingWindow();
    if (room == null || window == null) return;
    final (begin, end) = window;
    if (!end.isAfter(begin.add(const Duration(minutes: 30)))) {
      _snack('距闭馆不足 30 分钟，试试选择明天');
      return;
    }
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
        if (mounted) _loadMenuQuietly();
      }
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 预约成功后静默刷新空位统计
  Future<void> _loadMenuQuietly() async {
    try {
      final labs = await widget.service.getSeatMenu();
      if (mounted) {
        setState(() {
          _labs = labs;
          _lab = labs.where((l) => l.id == _lab?.id).firstOrNull ?? _lab;
          _room =
              _lab?.children.where((r) => r.id == _room?.id).firstOrNull ?? _room;
        });
      }
    } catch (_) {}
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
                label: Text('${room.name}（空 ${room.remainCount}）'),
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
          onPressed: _busy || _room == null || _windowTooShort
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
          _windowTooShort
              ? '距闭馆不足 30 分钟，现在无法预约，明天再来吧'
              : (_dayOffset == 0
                  ? '将随机挑选一个从「现在（${window != null ? _fmt(window.$1.hour * 60 + window.$1.minute) : ""}）」一直空到闭馆（$_roomOpenEnd）的座位'
                  : '将随机挑选一个明天开馆（$_roomOpenStart）到闭馆（$_roomOpenEnd）整段空闲的座位'),
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
