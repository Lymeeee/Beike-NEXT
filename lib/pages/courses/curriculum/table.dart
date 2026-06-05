import 'package:flutter/material.dart';
import '/types/courses.dart';
import '/types/preferences.dart';

class _TimeIndicatorInfo {
  final int periodIndex;
  final bool isPreview;

  const _TimeIndicatorInfo(this.periodIndex, this.isPreview);
}

class _MajorPeriodInfo {
  final int id;
  final String name;
  final String startTime;
  final String endTime;

  _MajorPeriodInfo(this.id, this.name, this.startTime, this.endTime);
}

class CurriculumTable extends StatelessWidget {
  final CurriculumIntegratedData curriculumData;
  final double availableWidth;
  final double availableHeight;
  final CurriculumSettings settings;
  final Map<int, int> weekDates;
  final int currentWeek;
  final void Function(int day, int period)? onTripleTapEmptyCell;
  final void Function(ClassItem classItem)? onTapCustomCourse;

  const CurriculumTable({
    super.key,
    required this.curriculumData,
    required this.availableWidth,
    required this.availableHeight,
    required this.settings,
    required this.weekDates,
    required this.currentWeek,
    this.onTripleTapEmptyCell,
    this.onTapCustomCourse,
  });

  List<ClassItem> get weekClasses => curriculumData.allClasses
      .where((classItem) => classItem.weeks.contains(currentWeek))
      .toList();

  static const List<String> dayNames = ['一', '二', '三', '四', '五', '六', '日'];

  void _showClassDetails(BuildContext context, ClassItem classItem) {
    if (classItem.isCustom && onTapCustomCourse != null) {
      onTapCustomCourse!(classItem);
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(classItem.className),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('教师: ${classItem.teacherName}'),
            Text('地点: ${classItem.locationName}'),
            Text('周次: ${classItem.weeksText}'),
            Text('节次: 第${classItem.period}大节'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  _TimeIndicatorInfo? _calculateTimeIndicator(
    List<_MajorPeriodInfo> majorPeriods, [
    String? debugCurrentHHmmss,
  ]) {
    final now = debugCurrentHHmmss != null
        ? DateTime.parse('1970-01-01 $debugCurrentHHmmss')
        : DateTime.now();
    final currentTime = TimeOfDay.fromDateTime(now);
    final currentMinutes = currentTime.hour * 60 + currentTime.minute;

    for (int i = 0; i < majorPeriods.length; i++) {
      final period = majorPeriods[i];
      try {
        final startParts = period.startTime.split(':');
        final endParts = period.endTime.split(':');
        final startMinutes =
            int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

        // Current time is within this period
        if (currentMinutes >= startMinutes && currentMinutes <= endMinutes) {
          return _TimeIndicatorInfo(i, false);
        }

        // Current time is before this period
        if (currentMinutes < startMinutes) {
          return _TimeIndicatorInfo(i, true);
        }
      } catch (e) {
        continue;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final majorPeriods = _getMajorPeriods(curriculumData.allPeriods);
    final timeIndicatorInfo = _calculateTimeIndicator(majorPeriods);

    final displayDays = settings.calculateDisplayDays(
      weekClasses.map((c) => c.day).toSet().toList(),
    );
    final dayColumnWidth = (availableWidth - 2) / (displayDays + 1);
    const headerHeight = 66.0; // 50 + 2×2 margin + 12 safety
    const rowVerticalMargin = 2.0; // 1+1 top+bottom per body cell
    final cellHeight = (availableHeight - headerHeight) / majorPeriods.length - rowVerticalMargin;

    String? displayMonth;
    String? displayYear;

    final days = curriculumData.calendarDays;
    if (days != null) {
      for (final calendarDay in days) {
        if (calendarDay.weekIndex == currentWeek) {
          displayMonth = '${calendarDay.month}月';
          displayYear = '${calendarDay.year}年';
        }
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: availableWidth,
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: Table(
            columnWidths: {
              for (int i = 0; i <= displayDays; i++)
                i: FixedColumnWidth(dayColumnWidth),
            },
            children: [
              // Table header
              TableRow(
                children: [
                  _buildHeaderCell(
                    context,
                    displayMonth ?? '${curriculumData.currentTerm.year.split('-').last}年',
                    subtitle: displayMonth != null ? displayYear : null,
                  ),
                  for (int day = 1; day <= displayDays; day++)
                    _buildHeaderCell(
                      context,
                      '周${dayNames[day - 1]}',
                      subtitle: weekDates[day]?.toString(),
                      isToday: day == _getTodayWeekday(),
                    ),
                ],
              ),
              // Table body
              for (
                int periodIndex = 0;
                periodIndex < majorPeriods.length;
                periodIndex++
              )
                TableRow(
                  children: [
                    _buildMajorTimeCell(
                      context,
                      cellHeight,
                      majorPeriods[periodIndex],
                      timeIndicatorInfo,
                      periodIndex,
                    ),
                    for (int day = 1; day <= displayDays; day++)
                      _buildMajorClassCell(
                        context,
                        cellHeight,
                        settings,
                        weekClasses,
                        day,
                        majorPeriods[periodIndex],
                      ),
                  ],
                ),
            ],
          ),
        ),
    );
  }

  Widget _buildHeaderCell(
    BuildContext context,
    String text, {
    String? subtitle,
    bool isToday = false,
  }) {
    return Container(
      height: 50,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: isToday
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: subtitle == null ? 16 : 14,
                fontWeight: FontWeight.bold,
                color: isToday
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: isToday
                      ? Theme.of(
                          context,
                        ).colorScheme.onPrimary.withValues(alpha: 0.8)
                      : Theme.of(
                          context,
                        ).colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMajorTimeCell(
    BuildContext context,
    double cellHeight,
    _MajorPeriodInfo majorPeriod,
    _TimeIndicatorInfo? arrowInfo,
    int periodIndex,
  ) {
    final showArrow = arrowInfo != null && arrowInfo.periodIndex == periodIndex;

    return Container(
      height: cellHeight,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  majorPeriod.startTime,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${majorPeriod.id}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  majorPeriod.endTime,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (showArrow)
            Positioned(
              right: 2,
              top: arrowInfo.isPreview ? 4 : cellHeight / 2 - 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  arrowInfo.isPreview ? Icons.north_east : Icons.east,
                  color: Theme.of(context).colorScheme.primary,
                  size: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMajorClassCell(
    BuildContext context,
    double cellHeight,
    CurriculumSettings settings,
    List<ClassItem> weekClasses,
    int day,
    _MajorPeriodInfo majorPeriod,
  ) {
    final classesInSlot = weekClasses.where((classItem) {
      return classItem.day == day && classItem.period == majorPeriod.id;
    }).toList();

    final classColors = classesInSlot.isEmpty
        ? null
        : _getClassColors(context, classesInSlot.first);

    return Container(
      height: cellHeight,
      margin: const EdgeInsets.fromLTRB(2, 1, 2, 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: classColors?.background ??
            Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: classesInSlot.isEmpty
                ? _TripleTapDetector(
                    onTripleTap: onTripleTapEmptyCell != null
                        ? () => onTripleTapEmptyCell!(day, majorPeriod.id)
                        : null,
                    child: const SizedBox.expand(),
                  )
                : _buildClassContent(context, classesInSlot, settings, classColors!.foreground),
          ),
        ],
      ),
    );
  }

  Widget _buildClassContent(
    BuildContext context,
    List<ClassItem> classesInSlot,
    CurriculumSettings settings,
    Color foregroundColor,
  ) {
    final maxLines = switch (settings.tableSize) {
      TableSize.small => 2,
      TableSize.medium => 3,
      TableSize.large => 4,
    };
    final firstClass = classesInSlot.first;
    final useAnimation = settings.animationMode != AnimationMode.none;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showClassDetails(context, firstClass),
        splashColor: Theme.of(
          context,
        ).colorScheme.surface.withValues(alpha: 0.3),
        highlightColor: Theme.of(
          context,
        ).colorScheme.surface.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(2),
        child: useAnimation
            ? AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0),
                width: double.infinity,
                height: double.infinity,
                child: _buildClassContentInner(
                  context,
                  firstClass,
                  classesInSlot,
                  maxLines,
                  foregroundColor,
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0),
                width: double.infinity,
                height: double.infinity,
                child: _buildClassContentInner(
                  context,
                  firstClass,
                  classesInSlot,
                  maxLines,
                  foregroundColor,
                ),
              ),
      ),
    );
  }

  String _simplifyLocation(String location) {
    return location
        .replaceAll('校本部', '')
        .replaceAll('【', '')
        .replaceAll('】', '')
        .trim();
  }

  Widget _buildClassContentInner(
    BuildContext context,
    ClassItem firstClass,
    List<ClassItem> classesInSlot,
    int maxLines,
    Color foregroundColor,
  ) {
    final location = _simplifyLocation(firstClass.locationName);
    final locationMaxLines = (maxLines ~/ 2).clamp(1, 2);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          firstClass.className.replaceAll('\n', ' '),
          style: TextStyle(
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.bold,
            color: foregroundColor,
          ),
          textAlign: TextAlign.center,
          maxLines: maxLines,
        ),
        if (location.isNotEmpty) ...[
          const SizedBox(height: 1),
          Text(
            location,
            style: TextStyle(fontSize: 10, height: 1.2, color: foregroundColor.withValues(alpha: 0.7)),
            textAlign: TextAlign.center,
            maxLines: locationMaxLines,
          ),
        ],
        if (classesInSlot.length > 1) ...[
          const SizedBox(height: 1),
          Text(
            '+${classesInSlot.length - 1}',
            style: TextStyle(fontSize: 9, height: 1.2, color: foregroundColor.withValues(alpha: 0.7)),
          ),
        ],
      ],
    );
  }

  ({Color background, Color foreground}) _getClassColors(BuildContext context, ClassItem classItem) {
    final scheme = Theme.of(context).colorScheme;
    return (background: scheme.primaryContainer, foreground: scheme.onPrimaryContainer);
  }

  List<_MajorPeriodInfo> _getMajorPeriods(List<ClassPeriod> periods) {
    final majorPeriodsMap = <int, List<ClassPeriod>>{};

    for (final period in periods) {
      majorPeriodsMap.putIfAbsent(period.majorId, () => []).add(period);
    }

    final majorPeriodsList = <_MajorPeriodInfo>[];

    for (final entry in majorPeriodsMap.entries) {
      final majorId = entry.key;
      final periodsInMajor = entry.value;

      if (periodsInMajor.isEmpty) continue;

      final majorName = periodsInMajor.first.majorName;

      String majorStartTime = '';
      String majorEndTime = '';

      for (final period in periodsInMajor) {
        if (period.majorStartTime != null &&
            period.majorStartTime!.isNotEmpty) {
          majorStartTime = period.majorStartTime!;
          break;
        }
      }

      for (final period in periodsInMajor) {
        if (period.majorEndTime != null && period.majorEndTime!.isNotEmpty) {
          majorEndTime = period.majorEndTime!;
          break;
        }
      }

      if (majorStartTime.isEmpty) {
        periodsInMajor.sort((a, b) => a.minorId.compareTo(b.minorId));
        majorStartTime = periodsInMajor.first.minorStartTime;
      }

      if (majorEndTime.isEmpty) {
        periodsInMajor.sort((a, b) => b.minorId.compareTo(a.minorId));
        majorEndTime = periodsInMajor.first.minorEndTime;
      }

      if (majorStartTime.isEmpty || majorEndTime.isEmpty) {
        throw StateError(
          'Incomplete data for MajorPeriod $majorId ($majorName)',
        );
      }

      majorPeriodsList.add(
        _MajorPeriodInfo(majorId, majorName, majorStartTime, majorEndTime),
      );
    }

    return majorPeriodsList;
  }

  /// Returns 1~7 for Monday~Sunday, or null if today is not in the current week
  int? _getTodayWeekday() {
    if (curriculumData.calendarDays == null ||
        curriculumData.calendarDays!.isEmpty) {
      return null;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final calendarDay in curriculumData.calendarDays!) {
      if (calendarDay.weekIndex == currentWeek) {
        final dayDate = DateTime(
          calendarDay.year,
          calendarDay.month,
          calendarDay.day,
        );
        if (dayDate.year == today.year &&
            dayDate.month == today.month &&
            dayDate.day == today.day) {
          return calendarDay.weekday;
        }
      }
    }
    return null;
  }
}

class _TripleTapDetector extends StatefulWidget {
  final VoidCallback? onTripleTap;
  final Widget child;

  const _TripleTapDetector({this.onTripleTap, required this.child});

  @override
  State<_TripleTapDetector> createState() => _TripleTapDetectorState();
}

class _TripleTapDetectorState extends State<_TripleTapDetector> {
  int _tapCount = 0;
  DateTime _firstTap = DateTime.now();

  void _handleTap() {
    final now = DateTime.now();
    if (now.difference(_firstTap).inMilliseconds > 600) {
      _tapCount = 0;
      _firstTap = now;
    }
    _tapCount++;
    if (_tapCount >= 3) {
      _tapCount = 0;
      widget.onTripleTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTripleTap != null ? _handleTap : null,
      behavior: HitTestBehavior.opaque,
      child: widget.child,
    );
  }
}
