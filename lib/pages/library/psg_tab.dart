import 'dart:math' as math;

import 'package:flutter/material.dart';

import '/services/library/service.dart';
import '/types/library.dart';
import '/utils/haptic.dart';
import 'timeline.dart';
import 'widgets.dart';

/// 研修间：类型 → 房间列表 → 选时段预约
class PsgTab extends StatefulWidget {
  const PsgTab({super.key, required this.service});

  final LibraryService service;

  @override
  State<PsgTab> createState() => _PsgTabState();
}

class _PsgTabState extends State<PsgTab> {
  List<LibzwPsgKind> _kinds = const [];
  LibzwPsgKind? _kind;
  List<LibzwDevice> _rooms = const [];

  int _dayOffset = 0;
  /// 可选日期上限（0=仅今天）。依据房间 resvRule.earliestResvTime（分钟）推导，研修间实测=2880 → 可约到后天
  int _maxDayOffset = 2;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  static const List<String> _dayLabels = ['今天', '明天', '后天', '第四天', '第五天', '第六天'];

  @override
  void initState() {
    super.initState();
    _loadKinds();
  }

  DateTime get _day {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(Duration(days: _dayOffset));
  }

  String get _ymd =>
      '${_day.year}${_day.month.toString().padLeft(2, '0')}${_day.day.toString().padLeft(2, '0')}';

  String get _dateDash =>
      '${_day.year}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}';

  Future<void> _loadKinds() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final kinds = await widget.service.getPsgKinds();
      if (!mounted) return;
      setState(() {
        _kinds = kinds;
        _kind = kinds.isNotEmpty ? kinds.first : null;
      });
      await _loadRooms();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadRooms() async {
    final kind = _kind;
    if (kind == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rooms = await widget.service.queryPsgRooms(kind.kindId, _ymd);
      if (!mounted) return;
      final rule = rooms.isNotEmpty ? rooms.first.resvRule : null;
      setState(() {
        _rooms = rooms;
        if (rule != null && rule.earliestResvTime > 0) {
          _maxDayOffset = (rule.earliestResvTime ~/ 1440).clamp(1, 6);
          if (_dayOffset > _maxDayOffset) _dayOffset = _maxDayOffset;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---- 时段选择 ----

  static int _toMin(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  static String _fmt(int min) =>
      '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';

  static int _ceilTo30(int min) => ((min + 29) ~/ 30) * 30;

  int get _nowMin {
    final now = DateTime.now();
    return now.hour * 60 + now.minute;
  }

  /// 该房间在所选日期的逐时段占用（绿=空闲 黄=被占用 灰=不可约）
  List<SlotState> _roomSlotStates(LibzwDevice room, int openStart, int openEnd) {
    final blockedBefore = _dayOffset == 0 ? _ceilTo30(_nowMin + 5) : -1;
    final states = <SlotState>[];
    for (var t = openStart; t + 30 <= openEnd; t += 30) {
      if (t < blockedBefore) {
        states.add(SlotState.blocked);
        continue;
      }
      final begin = DateTime(_day.year, _day.month, _day.day, t ~/ 60, t % 60);
      final end = begin.add(const Duration(minutes: 30));
      final busy = room.resvInfo.any((i) =>
          (i.resvStatus & 128) == 0 &&
          i.end.isAfter(begin) &&
          i.start.isBefore(end));
      states.add(busy ? SlotState.busy : SlotState.free);
    }
    return states;
  }

  Future<(int, int)?> _pickWindow(LibzwDevice room) async {
    final openStartRaw = room.openTimes.isNotEmpty
        ? room.openTimes.first.openStartTime
        : (room.openStart.isNotEmpty ? room.openStart : '07:00');
    final openEndRaw = room.openTimes.isNotEmpty
        ? room.openTimes.first.openEndTime
        : (room.openEnd.isNotEmpty ? room.openEnd : '22:00');
    final openStart = _toMin(openStartRaw.replaceAll(':', '').length == 4
        ? '${openStartRaw.replaceAll(':', '').substring(0, 2)}:${openStartRaw.replaceAll(':', '').substring(2)}'
        : openStartRaw);
    final openEnd = _toMin(openEndRaw.replaceAll(':', '').length == 4
        ? '${openEndRaw.replaceAll(':', '').substring(0, 2)}:${openEndRaw.replaceAll(':', '').substring(2)}'
        : openEndRaw);

    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final first = _dayOffset == 0
        ? math.max(openStart, _ceilTo30(nowMin + 5))
        : openStart;

    // 单次最长预约时长（研修间实测 maxResvTime=180 分钟）
    final maxResv = math.max(30, room.resvRule?.maxResvTime ?? 180);

    final starts = <int>[];
    for (var t = first; t + 30 <= openEnd; t += 30) {
      starts.add(t);
    }
    if (starts.isEmpty) {
      _snack('该房间当前时段不可预约，换个日期或房间试试');
      return null;
    }

    var startMin = starts.first;
    var endMin = math.min(math.min(openEnd, startMin + 120), startMin + maxResv);

    return showModalBottomSheet<(int, int)>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final ends = <int>[];
            for (var t = startMin + 30;
                t <= math.min(openEnd, startMin + maxResv);
                t += 30) {
              ends.add(t);
            }
            if (!ends.contains(endMin)) {
              endMin = ends.isNotEmpty ? ends.first : openEnd;
            }
            final states = _roomSlotStates(room, openStart, openEnd);
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '选择时段 · ${room.devName}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  if (states.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    AvailabilityTimeline(
                      states: states,
                      selStartIndex: ((startMin - openStart) / 30)
                          .round()
                          .clamp(0, states.length),
                      selEndIndex: ((endMin - openStart) / 30)
                          .round()
                          .clamp(0, states.length),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(_fmt(openStart),
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.outline)),
                        const Spacer(),
                        Text(_fmt(openEnd),
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.outline)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const TimelineLegend(),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    '时间',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      DropdownButton<int>(
                        value: startMin,
                        items: starts
                            .map((m) => DropdownMenuItem(
                                value: m, child: Text(_fmt(m))))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setSheetState(() => startMin = v);
                        },
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('至'),
                      ),
                      DropdownButton<int>(
                        value: ends.contains(endMin) ? endMin : ends.firstOrNull,
                        items: ends
                            .map((m) => DropdownMenuItem(
                                value: m, child: Text(_fmt(m))))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setSheetState(() => endMin = v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pop((startMin, endMin)),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text('下一步'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _bookRoom(LibzwDevice room) async {
    setState(() => _busy = true);
    try {
      final window = await _pickWindow(room);
      if (window == null || !mounted) return;
      final (startMin, endMin) = window;
      final timeText =
          '${_dayOffset == 0 ? "今天" : "明天"} ${_day.month}/${_day.day} ${_fmt(startMin)} - ${_fmt(endMin)}';

      final message = await showReserveConfirmSheet(
        context,
        service: widget.service,
        icon: Icons.meeting_room_outlined,
        title: room.devName,
        subtitle: '${room.kindName} · ${room.labName} · 可容纳 ${room.minUser}-${room.maxUser} 人',
        timeText: timeText,
        sysKind: 1,
        devId: room.devId,
        beginTime: '$_dateDash ${_fmt(startMin)}:00',
        endTime: '$_dateDash ${_fmt(endMin)}:00',
        resvProperty: 32,
        resvKind: 2,
      );

      if (message != null && mounted) {
        await showReserveSuccessDialog(
          context,
          headline: '研修间预约成功',
          place: '${room.devName}\n${room.labName} · ${room.kindName}',
          timeText: timeText,
          serverMessage: message,
        );
        if (mounted) _loadRooms();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(theme, '选择研修室'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kinds.map((kind) {
                  return ChoiceChip(
                    label: Text(kind.kindName),
                    selected: kind.kindId == _kind?.kindId,
                    onSelected: (_) {
                      Haptics.selection();
                      setState(() => _kind = kind);
                      _loadRooms();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              _sectionTitle(theme, '日期'),
              Wrap(
                spacing: 8,
                children: List.generate(_maxDayOffset + 1, (offset) {
                  return ChoiceChip(
                    label: Text(_dayLabels[offset]),
                    selected: _dayOffset == offset,
                    onSelected: (_) {
                      Haptics.selection();
                      setState(() => _dayOffset = offset);
                      _loadRooms();
                    },
                  );
                }),
              ),
            ],
          ),
        ),
        Expanded(child: _buildRooms(theme)),
      ],
    );
  }

  Widget _buildRooms(ThemeData theme) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () { Haptics.light(); _loadKinds(); },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_rooms.isEmpty) {
      return const Center(child: Text('这段时间没有可预约的研修间'));
    }

    return RefreshIndicator(
      onRefresh: _loadRooms,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _rooms.length,
        itemBuilder: (context, index) {
          final room = _rooms[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.devName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${room.labName} · 可容纳 ${room.minUser}-${room.maxUser} 人',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (room.openTimes.isNotEmpty)
                          Text(
                            '开放 ${room.openTimes.first.openStartTime} - ${room.openTimes.first.openEndTime}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _busy ? null : () { Haptics.medium(); _bookRoom(room); },
                    child: const Text('预约'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
