import 'dart:async';
import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import '/utils/page_mixins.dart';
import '/services/empty_classroom/service.dart';
import '/types/empty_classroom.dart';

@RoutePage(name: 'EmptyClassroomRoute')
class EmptyClassroomPage extends StatefulWidget {
  const EmptyClassroomPage({super.key});

  @override
  State<EmptyClassroomPage> createState() => _EmptyClassroomPageState();
}

class _EmptyClassroomPageState extends State<EmptyClassroomPage>
    with PageStateMixin, LoadingStateMixin {
  final EmptyClassroomService _service = EmptyClassroomService();
  Timer? _clockTimer;
  String _currentTime = '';

  static const _timeFilterIcons = {
    4: Icons.view_list,
    0: Icons.wb_sunny,
    1: Icons.wb_twilight,
    2: Icons.wb_cloudy,
    3: Icons.nights_stay,
  };

  static const _timeFilterLabels = {
    4: '节次',
    0: '全天',
    1: '上午',
    2: '下午',
    3: '晚上',
  };

  @override
  void onServiceInit() {
    _updateClock();
    _clockTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    _service.addListener(_onServiceChanged);
    _service.init();
  }

  @override
  void onServiceStatusChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _service.removeListener(_onServiceChanged);
    _service.dispose();
    super.dispose();
  }

  void _updateClock() {
    final now = DateTime.now();
    final weekDays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    final w = weekDays[now.weekday % 7];
    setState(() {
      _currentTime =
          '${now.year}年${now.month.toString().padLeft(2, '0')}月${now.day.toString().padLeft(2, '0')}日 '
          '$w '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('无课教室'),
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
      ),
      body: Column(
        children: [
          _buildHeader(theme),
          _buildFilters(theme),
          Expanded(child: _buildContent(theme)),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_service.selectedDate} 无课教室',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _currentTime,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // --- Filter bar ---

  Widget _buildFilters(ThemeData theme) {
    final buildingName = _service.buildings
        .where((b) => b.id == _service.selectedBuildingId)
        .map((b) => b.name)
        .firstOrNull ??
        '教学楼';

    final nodeName = _service.selectedNodeId == '-1'
        ? '全部节次'
        : _service.nodes
                .where((n) => n.id == _service.selectedNodeId)
                .map((n) => n.name)
                .firstOrNull ??
            '节次';

    final dateLabel = _service.selectedDate;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Building selector
            _FilterChip(
              icon: Icons.apartment,
              label: buildingName,
              onTap: _service.isLoading
                  ? null
                  : (ctx) => _showPopupMenu(
                        ctx,
                        theme,
                        _service.buildings
                            .map((b) => (b.id, b.name))
                            .toList(),
                        _service.selectedBuildingId,
                        (id) => _service.selectBuilding(id),
                      ),
            ),
            const SizedBox(width: 8),
            // Node selector (only in node search mode)
            if (_service.isSearchByNode)
              _FilterChip(
                icon: Icons.access_time,
                label: nodeName,
                onTap: _service.isLoading
                    ? null
                    : (ctx) => _showPopupMenu(ctx,
                          theme,
                          [('-1', '全部节次'), ..._service.nodes.map((n) => (n.id, n.name))],
                          _service.selectedNodeId,
                          (id) => _service.selectNode(id),
                        ),
              ),
            if (_service.isSearchByNode) const SizedBox(width: 8),
            // Date button
            _FilterChip(
              icon: Icons.calendar_today,
              label: dateLabel,
              onTap: _service.isLoading
                  ? null
                  : (_) async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        _service.selectDate(picked);
                      }
                    },
            ),
            const SizedBox(width: 8),
            // Time filter: segmented chips
            ..._timeFilterLabels.entries.map((entry) {
              final id = entry.key;
              final label = entry.value;
              final selected = _service.timeFilterId == id;
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: FilterChip(
                  label: Text(label, style: const TextStyle(fontSize: 13)),
                  selected: selected,
                  showCheckmark: false,
                  onSelected: _service.isLoading
                      ? null
                      : (_) => _service.selectTimeFilter(id),
                  avatar: Icon(
                    _timeFilterIcons[id],
                    size: 16,
                    color: selected
                        ? theme.colorScheme.onSecondaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showPopupMenu(
    BuildContext chipContext,
    ThemeData theme,
    List<(String, String)> items,
    String? currentValue,
    void Function(String) onSelected,
  ) {
    final renderBox = chipContext.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height + 4,
        offset.dx + size.width,
        offset.dy + size.height + 300,
      ),
      items: items.map((item) {
        final (id, name) = item;
        return PopupMenuItem<String>(
          value: id,
          child: Row(
            children: [
              if (id == currentValue)
                Icon(Icons.check, size: 18, color: theme.colorScheme.primary)
              else
                const SizedBox(width: 18),
              const SizedBox(width: 8),
              Text(name),
            ],
          ),
        );
      }).toList(),
    ).then((value) {
      if (value != null) onSelected(value);
    });
  }

  // --- Content ---

  Widget _buildContent(ThemeData theme) {
    if (!_service.isInitialized && _service.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_service.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('加载失败', style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => _service.refresh(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_service.isSearchByNode) {
      return _buildNodeBasedList(theme);
    } else {
      return _buildTimeBasedList(theme);
    }
  }

  Widget _buildNodeBasedList(ThemeData theme) {
    final rooms = _service.freeRoomsByNode;
    if (rooms.isEmpty) {
      return _buildEmptyState(theme);
    }

    final isSingleNode = _service.selectedNodeId != null &&
        _service.selectedNodeId != '-1';

    return RefreshIndicator(
      onRefresh: () => _service.refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: rooms.length,
        itemBuilder: (context, index) {
          final node = rooms[index];
          return _buildNodeCard(theme, node, isSingleNode);
        },
      ),
    );
  }

  Widget _buildNodeCard(
    ThemeData theme,
    FreeClassroomNode node,
    bool isSingleNode,
  ) {
    final isCurrent = _isCurrentTimeRange(node.startTime, node.endTime);

    return Card(
      elevation: isCurrent ? 3 : 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCurrent
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header — uses primaryContainer for MD3 accent
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule,
                      size: 18, color: theme.colorScheme.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Text(
                    node.nodeName,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_formatTime(node.startTime)} - ${_formatTime(node.endTime)}',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer
                          .withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Classroom grid
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: node.classroomItems.map((room) {
                return _buildRoomChip(theme, room, node);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomChip(
    ThemeData theme, ClassroomItem room, FreeClassroomNode node) {
    final timeStatus = _getTimeStatusForNode(node.startTime, node.endTime);
    final (Color bgColor, Color textColor) = switch (timeStatus) {
      _TimeStatus.past => (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurfaceVariant
        ),
      _TimeStatus.current => (
          theme.colorScheme.primary,
          theme.colorScheme.onPrimary
        ),
      _TimeStatus.future => (
          theme.colorScheme.primaryContainer,
          theme.colorScheme.onPrimaryContainer
        ),
    };

    return Container(
      width: 100,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            room.classroomName,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '空座率:${room.noSeatRate != null ? '${(room.noSeatRate! * 100).toInt()}%' : '--'}',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.8),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBasedList(ThemeData theme) {
    final rooms = _service.freeRoomsByTime;
    if (rooms.isEmpty) {
      return _buildEmptyState(theme);
    }

    return RefreshIndicator(
      onRefresh: () => _service.refresh(),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: rooms.map((room) {
            return Container(
              width: 100,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    room.classroomName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.meeting_room_outlined,
              size: 120,
              color: theme.colorScheme.outline.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            '暂无无课教室数据',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // --- Helpers ---

  String _formatTime(String isoTime) {
    if (isoTime.length >= 16) return isoTime.substring(11, 16);
    return isoTime;
  }

  bool _isCurrentTimeRange(String startTime, String endTime) {
    final start = _timeStrToMinutes(_formatTime(startTime));
    final end = _timeStrToMinutes(_formatTime(endTime));
    final now = DateTime.now();
    final current = now.hour * 60 + now.minute;
    return current >= start && current < end;
  }

  int _timeStrToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  _TimeStatus _getTimeStatusForNode(String startTime, String endTime) {
    final start = _timeStrToMinutes(_formatTime(startTime));
    final end = _timeStrToMinutes(_formatTime(endTime));
    final now = DateTime.now();
    final current = now.hour * 60 + now.minute;
    if (current < start) return _TimeStatus.future;
    if (current > end) return _TimeStatus.past;
    return _TimeStatus.current;
  }
}

enum _TimeStatus { past, current, future }

/// A compact filter button with icon + label.
class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final void Function(BuildContext chipContext)? onTap;

  const _FilterChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onTap?.call(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
