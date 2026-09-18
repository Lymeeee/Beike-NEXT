import 'package:flutter/material.dart';

/// 单个时段的可用状态
enum SlotState {
  /// 有空位 / 空闲
  free,

  /// 已约满 / 被占用
  busy,

  /// 不可约（已过时间或封闭）
  blocked,
}

/// 可用性时间轴：一格 = 一个时段（默认 30 分钟）
class AvailabilityTimeline extends StatelessWidget {
  const AvailabilityTimeline({
    super.key,
    required this.states,
    this.selStartIndex,
    this.selEndIndex,
    this.height = 26,
  });

  final List<SlotState> states;

  /// 当前选中区间（下标，[selStartIndex, selEndIndex)），用于加深显示
  final int? selStartIndex;
  final int? selEndIndex;
  final double height;

  static const Color freeColor = Color(0xFF66BB6A);
  static const Color busyColor = Color(0xFFFFC107);

  static Color blockedColor(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;

  @override
  Widget build(BuildContext context) {
    if (states.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Row(
        children: [
          for (var i = 0; i < states.length; i++)
            Expanded(
              child: Container(
                height: height,
                margin: EdgeInsets.only(right: i == states.length - 1 ? 0 : 1),
                color: _colorFor(context, i),
              ),
            ),
        ],
      ),
    );
  }

  Color _colorFor(BuildContext context, int i) {
    final base = switch (states[i]) {
      SlotState.free => freeColor,
      SlotState.busy => busyColor,
      SlotState.blocked => blockedColor(context),
    };
    final selected = selStartIndex != null &&
        selEndIndex != null &&
        i >= selStartIndex! &&
        i < selEndIndex!;
    if (!selected) return base;
    return Color.alphaBlend(Colors.black.withValues(alpha: 0.3), base);
  }
}

/// 时间轴图例
class TimelineLegend extends StatelessWidget {
  const TimelineLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget item(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        item(AvailabilityTimeline.freeColor, '可约'),
        item(AvailabilityTimeline.busyColor, '已占用'),
        item(AvailabilityTimeline.blockedColor(context), '不可约'),
      ],
    );
  }
}
