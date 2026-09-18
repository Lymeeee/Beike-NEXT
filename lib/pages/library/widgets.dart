import 'package:flutter/material.dart';

import '/services/library/service.dart';
import '/utils/haptic.dart';

/// 预约确认弹层：展示预约信息，确认后提交。
/// 成功返回服务端提示语（String）；用户取消返回 null。
/// 注：学校 resvCode=0 表示无需验证码（官方网页同样不弹），captcha 照发空值。
Future<String?> showReserveConfirmSheet(
  BuildContext context, {
  required LibraryService service,
  required IconData icon,
  required String title,
  required String subtitle,
  required String timeText,
  required int sysKind,
  required int devId,
  required String beginTime,
  required String endTime,
  int resvProperty = 0,
  int resvKind = 0,
  String appUrl = '',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ReserveConfirmSheet(
      service: service,
      icon: icon,
      title: title,
      subtitle: subtitle,
      timeText: timeText,
      sysKind: sysKind,
      devId: devId,
      beginTime: beginTime,
      endTime: endTime,
      resvProperty: resvProperty,
      resvKind: resvKind,
      appUrl: appUrl,
    ),
  );
}

class _ReserveConfirmSheet extends StatefulWidget {
  const _ReserveConfirmSheet({
    required this.service,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.timeText,
    required this.sysKind,
    required this.devId,
    required this.beginTime,
    required this.endTime,
    required this.resvProperty,
    required this.resvKind,
    required this.appUrl,
  });

  final LibraryService service;
  final IconData icon;
  final String title;
  final String subtitle;
  final String timeText;
  final int sysKind;
  final int devId;
  final String beginTime;
  final String endTime;
  final int resvProperty;
  final int resvKind;
  final String appUrl;

  @override
  State<_ReserveConfirmSheet> createState() => _ReserveConfirmSheetState();
}

class _ReserveConfirmSheetState extends State<_ReserveConfirmSheet> {
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final message = await widget.service.submitReserve(
        sysKind: widget.sysKind,
        devId: widget.devId,
        beginTime: widget.beginTime,
        endTime: widget.endTime,
        resvProperty: widget.resvProperty,
        resvKind: widget.resvKind,
        appUrl: widget.appUrl,
      );
      if (mounted) Navigator.of(context).pop(message);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(widget.icon, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule,
                      size: 16, color: theme.colorScheme.onPrimaryContainer),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.timeText,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _submitting ? null : () { Haptics.medium(); _submit(); },
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: Text(_submitting ? '正在提交…' : '确认预约'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 预约成功提示（显示座位号与位置）
Future<void> showReserveSuccessDialog(
  BuildContext context, {
  required String headline,
  required String place,
  required String timeText,
  String? serverMessage,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        icon: Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 44),
        title: Text(headline, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(place,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(timeText,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            if (serverMessage != null && serverMessage.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                serverMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Haptics.light(); Navigator.of(context).pop(); },
            child: const Text('知道了'),
          ),
        ],
      );
    },
  );
}
