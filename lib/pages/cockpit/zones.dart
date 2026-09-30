import 'package:flutter/material.dart';

import '/types/courses.dart';
import '/types/library.dart';
import '/utils/reservation_view.dart';
import 'data.dart';

/// 由可用尺寸推导的密度档位：手机横屏（高 < 500）用紧凑档
class CockpitMetrics {
  final bool compact;
  final double pagePadding;
  final double gap;
  final double clockSize;
  final bool showSeconds;
  final double titleSize;
  final double metaSize;
  final double itemPadding;
  final double timeColumnWidth;

  CockpitMetrics._({
    required this.compact,
    required this.pagePadding,
    required this.gap,
    required this.clockSize,
    required this.showSeconds,
    required this.titleSize,
    required this.metaSize,
    required this.itemPadding,
    required this.timeColumnWidth,
  });

  factory CockpitMetrics.of(Size size) {
    final compact = size.height < 500;
    return CockpitMetrics._(
      compact: compact,
      pagePadding: compact ? 10 : 20,
      gap: compact ? 10 : 16,
      clockSize: compact
          ? (size.height * 0.36).clamp(42.0, 92.0)
          : (size.height * 0.30).clamp(72.0, 150.0),
      showSeconds: !compact,
      titleSize: compact ? 15 : 17,
      metaSize: compact ? 11.5 : 13,
      itemPadding: compact ? 10 : 14,
      timeColumnWidth: compact ? 68 : 88,
    );
  }
}

/// 看板分区容器：统一的圆角底色
class CockpitPane extends StatelessWidget {
  final Widget child;

  const CockpitPane({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}

class CockpitPaneHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;

  const CockpitPaneHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: scheme.primary,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          Text(
            trailing!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class CockpitEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const CockpitEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: scheme.outline),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 左区：大时钟 + 日期 + 周次
class CockpitClockPane extends StatelessWidget {
  final CockpitSnapshot snapshot;
  final CockpitMetrics metrics;

  const CockpitClockPane({
    super.key,
    required this.snapshot,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = snapshot.now;
    final weekIndex = snapshot.weekIndex;

    final clockStyle = TextStyle(
      fontSize: metrics.clockSize,
      fontWeight: FontWeight.w600,
      height: 1.0,
      color: scheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return CockpitPane(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: metrics.showSeconds
                  ? Row(
                      textBaseline: TextBaseline.alphabetic,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      children: [
                        Text(
                          '${now.hour.toString().padLeft(2, '0')}:'
                          '${now.minute.toString().padLeft(2, '0')}',
                          style: clockStyle,
                        ),
                        Text(
                          ':${now.second.toString().padLeft(2, '0')}',
                          style: clockStyle.copyWith(
                            fontSize: metrics.clockSize * 0.38,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      '${now.hour.toString().padLeft(2, '0')}:'
                      '${now.minute.toString().padLeft(2, '0')}',
                      style: clockStyle,
                    ),
            ),
            SizedBox(height: metrics.compact ? 6 : 12),
            Text(
              metrics.compact && weekIndex != null
                  ? '${now.month}月${now.day}日 ${weekdayLabel(now.weekday)} · 第$weekIndex周'
                  : '${now.month}月${now.day}日 ${weekdayLabel(now.weekday)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: metrics.titleSize,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (weekIndex != null && !metrics.compact) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '第$weekIndex 周',
                  style: TextStyle(
                    fontSize: metrics.metaSize,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 中区：今日课表（进行中/接下来高亮）
class CockpitSchedulePane extends StatelessWidget {
  final CockpitSnapshot snapshot;
  final CockpitMetrics metrics;

  const CockpitSchedulePane({
    super.key,
    required this.snapshot,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return CockpitPane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CockpitPaneHeader(
            icon: Icons.calendar_today,
            title: '今日课表',
            trailing: snapshot.slots.isEmpty
                ? null
                : '${snapshot.slots.length} 节',
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildContent(context)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (snapshot.holidayMode) {
      return const CockpitEmptyState(
        icon: Icons.beach_access,
        title: '假期模式已开启',
        subtitle: '课表已隐藏',
      );
    }
    if (snapshot.examMode) {
      return const CockpitEmptyState(
        icon: Icons.assignment,
        title: '考试模式已开启',
        subtitle: '课表已隐藏',
      );
    }
    if (snapshot.slots.isEmpty && snapshot.weekIndex == null) {
      if (!snapshot.coursesOnline) {
        return const CockpitEmptyState(
          icon: Icons.login,
          title: '尚未登录教务账户',
          subtitle: '登录后可查看今日课表',
        );
      }
      return const CockpitEmptyState(
        icon: Icons.cloud_off,
        title: '暂无课表数据',
        subtitle: '可在课表页刷新',
      );
    }
    if (snapshot.slots.isEmpty) {
      return const CockpitEmptyState(
        icon: Icons.sentiment_satisfied,
        title: '今日无课',
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: snapshot.slots.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _CockpitClassTile(
        slot: snapshot.slots[index],
        now: snapshot.now,
        metrics: metrics,
      ),
    );
  }
}

class _CockpitClassTile extends StatelessWidget {
  final CockpitClassSlot slot;
  final DateTime now;
  final CockpitMetrics metrics;

  const _CockpitClassTile({
    required this.slot,
    required this.now,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isOngoing = slot.status == CockpitClassStatus.ongoing;
    final isNext = slot.status == CockpitClassStatus.next;
    final isPast = slot.status == CockpitClassStatus.past;
    final dimColor =
        isPast ? scheme.onSurface.withValues(alpha: 0.45) : scheme.onSurface;

    final names = slot.classes
        .map((item) => item.className.replaceAll('\n', ' '))
        .toSet()
        .toList();
    final first = slot.classes.first;
    final metaParts = [
      if (first.locationName.isNotEmpty) first.locationName,
      if (first.teacherName.isNotEmpty) first.teacherName,
    ];
    final progress = isOngoing ? slot.progressFraction(now) : null;

    return Container(
      padding: EdgeInsets.all(metrics.itemPadding),
      decoration: BoxDecoration(
        color: isOngoing ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: isNext ? Border.all(color: scheme.primary, width: 1.2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: metrics.timeColumnWidth,
                child: Text(
                  slot.timeRangeLabel,
                  style: TextStyle(
                    fontSize: metrics.metaSize,
                    fontWeight: FontWeight.w600,
                    color: isOngoing
                        ? scheme.onPrimaryContainer
                        : dimColor.withValues(alpha: isPast ? 0.45 : 0.8),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final name in names)
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: metrics.titleSize,
                          fontWeight: FontWeight.bold,
                          color: isOngoing
                              ? scheme.onPrimaryContainer
                              : dimColor,
                        ),
                      ),
                    if (metaParts.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        [
                          ...metaParts,
                          if (names.length > 1) '冲突',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: metrics.metaSize,
                          color: isOngoing
                              ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                              : (isPast
                                  ? scheme.onSurface.withValues(alpha: 0.35)
                                  : scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isOngoing || isNext) ...[
                const SizedBox(width: 8),
                _CockpitTag(
                  text: isOngoing ? '进行中' : '接下来',
                  filled: isOngoing,
                  fontSize: metrics.metaSize,
                ),
              ],
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                color: scheme.primary,
                backgroundColor:
                    scheme.onPrimaryContainer.withValues(alpha: 0.15),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 右区：预约 + 考试
class CockpitAgendaPane extends StatelessWidget {
  final CockpitSnapshot snapshot;
  final CockpitMetrics metrics;

  const CockpitAgendaPane({
    super.key,
    required this.snapshot,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final showExamSection =
        !snapshot.holidayMode && (snapshot.examMode || snapshot.hasExams);

    return CockpitPane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CockpitPaneHeader(
            icon: Icons.event_seat,
            title: '预约',
            trailing:
                snapshot.reservations.isEmpty ? null : '${snapshot.reservations.length} 项',
          ),
          const SizedBox(height: 8),
          Expanded(
            flex: showExamSection ? 3 : 1,
            child: _buildReservations(context),
          ),
          if (showExamSection) ...[
            SizedBox(height: metrics.gap),
            const CockpitPaneHeader(icon: Icons.assignment, title: '考试'),
            const SizedBox(height: 8),
            Expanded(flex: 2, child: _buildExams(context)),
          ],
        ],
      ),
    );
  }

  Widget _buildReservations(BuildContext context) {
    if (!snapshot.libraryLoggedIn) {
      return const CockpitEmptyState(
        icon: Icons.lock_outline,
        title: '尚未登录图书馆账号',
        subtitle: '登录后可查看预约',
      );
    }
    if (snapshot.reservations.isEmpty) {
      return const CockpitEmptyState(
        icon: Icons.event_available,
        title: '暂无预约',
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: snapshot.reservations.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _CockpitReservationTile(
        reservation: snapshot.reservations[index],
        now: snapshot.now,
        metrics: metrics,
      ),
    );
  }

  Widget _buildExams(BuildContext context) {
    final exams = <({ExamInfo exam, bool isOngoing})>[
      if (snapshot.ongoingExam != null)
        (exam: snapshot.ongoingExam!, isOngoing: true),
      if (snapshot.upcomingExam != null)
        (exam: snapshot.upcomingExam!, isOngoing: false),
    ];
    if (exams.isEmpty) {
      return Center(
        child: Text(
          '暂无考试安排',
          style: TextStyle(
            fontSize: metrics.metaSize,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: exams.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _CockpitExamTile(
        exam: exams[index].exam,
        isOngoing: exams[index].isOngoing,
        metrics: metrics,
      ),
    );
  }
}

class _CockpitReservationTile extends StatelessWidget {
  final LibzwReservation reservation;
  final DateTime now;
  final CockpitMetrics metrics;

  const _CockpitReservationTile({
    required this.reservation,
    required this.now,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final r = reservation;
    final isOngoing =
        !r.begin!.isAfter(now) && r.end!.isAfter(now);
    final label = reservationDayLabel(r);

    final dev = r.devices.isNotEmpty ? r.devices.first : null;
    final roomText = dev == null
        ? ''
        : (dev.roomName.isNotEmpty && dev.roomName != dev.devName)
            ? dev.roomName
            : dev.labName;
    final place = [
      if (r.kindLabel.isNotEmpty) r.kindLabel,
      if (roomText.isNotEmpty) roomText,
    ].join(' · ');
    final timeRange =
        '${formatHhmm(TimeOfDay.fromDateTime(r.begin!))}-'
        '${formatHhmm(TimeOfDay.fromDateTime(r.end!))}';

    return Container(
      padding: EdgeInsets.all(metrics.itemPadding),
      decoration: BoxDecoration(
        color:
            isOngoing ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dev?.devName ?? '预约',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: metrics.titleSize,
                    fontWeight: FontWeight.bold,
                    color:
                        isOngoing ? scheme.onPrimaryContainer : scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeRange,
                  style: TextStyle(
                    fontSize: metrics.metaSize,
                    color: isOngoing
                        ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                        : scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (place.isNotEmpty)
                  Text(
                    place,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: metrics.metaSize,
                      color: isOngoing
                          ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _CockpitTag(
            text: label,
            filled: isOngoing,
            fontSize: metrics.metaSize,
          ),
        ],
      ),
    );
  }
}

class _CockpitExamTile extends StatelessWidget {
  final ExamInfo exam;
  final bool isOngoing;
  final CockpitMetrics metrics;

  const _CockpitExamTile({
    required this.exam,
    required this.isOngoing,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(metrics.itemPadding),
      decoration: BoxDecoration(
        color:
            isOngoing ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  exam.courseName.replaceAll('\n', ' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: metrics.titleSize,
                    fontWeight: FontWeight.bold,
                    color:
                        isOngoing ? scheme.onPrimaryContainer : scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _CockpitTag(
                text: isOngoing ? '考试进行中' : '接下来',
                filled: isOngoing,
                fontSize: metrics.metaSize,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${exam.examDateDisplay} ${exam.examDayName} ${exam.examTime}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: metrics.metaSize,
              color: isOngoing
                  ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                  : scheme.onSurfaceVariant,
            ),
          ),
          if (exam.examRoom.isNotEmpty)
            Text(
              exam.examRoom,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: metrics.metaSize,
                color: isOngoing
                    ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                    : scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _CockpitTag extends StatelessWidget {
  final String text;
  final bool filled;
  final double fontSize;

  const _CockpitTag({
    required this.text,
    required this.filled,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? scheme.primary : scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: filled ? null : Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize - 0.5,
          fontWeight: FontWeight.w600,
          color: filled ? scheme.onPrimary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
