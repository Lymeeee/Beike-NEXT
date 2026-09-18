import 'package:flutter/material.dart';

import '/services/library/service.dart';
import '/types/library.dart';
import '/utils/haptic.dart';

/// 我的预约：列表 + 暂离 / 提前结束 / 取消
class ReservationsTab extends StatefulWidget {
  const ReservationsTab({super.key, required this.service});

  final LibraryService service;

  @override
  State<ReservationsTab> createState() => _ReservationsTabState();
}

class _ReservationsTabState extends State<ReservationsTab> {
  List<LibzwReservation> _items = const [];
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(DateTime? d) {
    if (d == null) return '--';
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final items = await widget.service.getMyReservations(
        beginDateDash: _fmtDate(now.subtract(const Duration(days: 1))),
        endDateDash: _fmtDate(now.add(const Duration(days: 7))),
      );
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirm(String title, String content) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _act(Future<String> Function() action, String confirmText) async {
    if (_busy) return;
    if (!await _confirm('确认操作', confirmText)) return;
    setState(() => _busy = true);
    try {
      final message = await action();
      if (mounted) _snack(message.isEmpty ? '操作成功' : message);
      await _load();
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

  Color _statusColor(ThemeData theme, int status) {
    if ((status & LibzwResvStatus.breached) != 0) {
      return theme.colorScheme.errorContainer;
    }
    if ((status & LibzwResvStatus.ended) != 0) {
      return theme.colorScheme.surfaceContainerHighest;
    }
    if ((status & LibzwResvStatus.tempLeave) != 0) {
      return theme.colorScheme.tertiaryContainer;
    }
    if ((status & LibzwResvStatus.active) != 0) {
      return theme.colorScheme.primaryContainer;
    }
    return theme.colorScheme.secondaryContainer;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              onPressed: () { Haptics.light(); _load(); },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Icon(Icons.event_available_outlined,
                size: 96, color: theme.colorScheme.outline.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Center(child: Text('暂无预约记录')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        itemBuilder: (context, index) => _buildCard(theme, _items[index]),
      ),
    );
  }

  Widget _buildCard(ThemeData theme, LibzwReservation item) {
    final statusColor = _statusColor(theme, item.resvStatus);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    LibzwResvStatus.describe(item.resvStatus),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_fmtTime(item.begin)} — ${_fmtTime(item.end)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Builder(builder: (_) {
              final title = [item.kindLabel, item.place]
                  .where((s) => s.isNotEmpty)
                  .join(' · ');
              return Text(
                title.isEmpty ? '（地点未知）' : title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              );
            }),
            if ((item.memo ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '备注：${item.memo}',
                style: TextStyle(
                    fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            if (!item.isEnded) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (item.canTempLeave)
                    FilledButton.tonalIcon(
                      onPressed: _busy
                          ? null
                          : () => _act(
                              () => widget.service.tempLeave(item.resvId),
                              '确定要暂时离开吗？'),
                      icon: const Icon(Icons.pause_circle_outline, size: 18),
                      label: const Text('暂时离开'),
                    ),
                  if (item.canEndEarly && (item.uuid ?? '').isNotEmpty)
                    FilledButton.tonalIcon(
                      onPressed: _busy
                          ? null
                          : () => _act(
                              () => widget.service.endAhaed(item.uuid!),
                              '确定要提前结束本次预约吗？'),
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: const Text('提前结束'),
                    ),
                  if (item.canCancel && (item.uuid ?? '').isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _act(
                              () => widget.service.deleteReservation(item.uuid!),
                              '确定要取消这条预约吗？'),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('取消预约'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
