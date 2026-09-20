import 'package:flutter/material.dart';

import '/services/provider.dart';
import '/types/courses.dart';
import '/types/preferences.dart';
import '/utils/app_bar.dart';
import '/utils/haptic.dart';
import 'table.dart';

/// 亲情课表：全屏只读查看导入的他人课表，可切换周次，不可编辑
class FamilyCurriculumViewPage extends StatefulWidget {
  const FamilyCurriculumViewPage({
    super.key,
    required this.item,
    this.calendarDays,
  });

  final FamilyCurriculum item;

  /// 学期与本机课表一致时借用本机的教学日历，使周次能显示日期
  final List<CalendarDay>? calendarDays;

  @override
  State<FamilyCurriculumViewPage> createState() =>
      _FamilyCurriculumViewPageState();
}

class _FamilyCurriculumViewPageState extends State<FamilyCurriculumViewPage> {
  late final CurriculumIntegratedData _data;
  int _currentWeek = 1;

  @override
  void initState() {
    super.initState();
    _data = CurriculumIntegratedData(
      currentTerm: widget.item.term,
      allClasses: widget.item.classes,
      allPeriods: widget.item.periods,
      calendarDays: widget.calendarDays,
    );

    final maxWeek = _data.getMaxValidWeekIndex();
    final todayWeek = maxWeek >= 1 ? _data.getWeekIndexToday() : null;
    _currentWeek = (todayWeek != null && todayWeek >= 1)
        ? todayWeek.clamp(1, maxWeek)
        : 1;
  }

  CurriculumSettings get _settings {
    final cached = ServiceProvider.instance.storeService
        .getPref<CurriculumSettings>("curriculum", CurriculumSettings.fromJson);
    return CurriculumSettings(
      weekendMode: WeekendDisplayMode.auto,
      tableSize: TableSize.small,
      animationMode: AnimationMode.slide,
      activated: cached?.activated ?? true,
    );
  }

  int get _maxWeek => _data.getMaxValidWeekIndex();

  void _gotoWeekSafe(int newWeek) {
    if (_maxWeek < 1) return;
    newWeek = newWeek.clamp(1, _maxWeek);
    if (newWeek == _currentWeek) return;
    setState(() => _currentWeek = newWeek);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final term = widget.item.term;

    return Scaffold(
      appBar: PageAppBar(title: '${widget.item.displayName}的课表'),
      body: _data.allPeriods.isEmpty
          ? _buildEmpty(theme, '这份课表缺少节次信息，无法显示')
          : _maxWeek < 1
              ? _buildEmpty(theme, '这份课表还没有课程')
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      _buildWeekSelector(),
                      const SizedBox(height: 4),
                      Text(
                        '${term.year} 学年 第${term.season}学期'
                        ' · 共 ${_data.allClasses.length} 门课程',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ClipRect(
                          child: GestureDetector(
                            onPanEnd: (details) {
                              if (details.velocity.pixelsPerSecond.dx.abs() >
                                  400) {
                                Haptics.medium();
                                _gotoWeekSafe(
                                  _currentWeek +
                                      (details.velocity.pixelsPerSecond.dx > 0
                                          ? -1
                                          : 1),
                                );
                              }
                            },
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _buildTable(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmpty(ThemeData theme, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekSelector() {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            Haptics.selection();
            _gotoWeekSafe(_currentWeek - 1);
          },
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '第 $_currentWeek 周',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            Haptics.selection();
            _gotoWeekSafe(_currentWeek + 1);
          },
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildTable() {
    return LayoutBuilder(
      key: ValueKey(_currentWeek),
      builder: (context, constraints) {
        return CurriculumTable(
          curriculumData: _data,
          availableWidth: constraints.maxWidth,
          availableHeight: constraints.maxHeight,
          settings: _settings,
          weekDates: _data.getWeekdayDaysOf(_currentWeek),
          currentWeek: _currentWeek,
        );
      },
    );
  }
}
