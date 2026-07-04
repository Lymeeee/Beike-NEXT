import 'package:flutter/material.dart';
import '/services/provider.dart';
import '/types/courses.dart';
import '/utils/app_bar.dart';

class GradePage extends StatefulWidget {
  const GradePage({super.key});

  @override
  State<GradePage> createState() => _GradePageState();
}

class _GradePageState extends State<GradePage> {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;

  List<CourseGradeItem>? _allGrades;
  DateTime? _lastFetchTime;

  bool _isLoading = false;
  String? _errorMessage;

  final Set<String> _selectedCourseIds = {};
  bool _isAllSelected = false;

  @override
  void initState() {
    super.initState();
    _loadCachedGrades();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _loadCachedGrades() {
    final cached = _serviceProvider.storeService.getPref<CachedGradeList>(
      'cached_grades',
      CachedGradeList.fromJson,
    );
    if (cached != null && mounted) {
      setState(() {
        _allGrades = cached.grades;
        _lastFetchTime = cached.fetchTime;
      });
    }
  }

  Future<void> _refreshGrades() async {
    final service = _serviceProvider.coursesService;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final grades = await service.getGrades();
      final fetchTime = DateTime.now();

      _serviceProvider.storeService.putPref<CachedGradeList>(
        'cached_grades',
        CachedGradeList(grades: grades, fetchTime: fetchTime),
      );

      if (mounted) {
        setState(() {
          _allGrades = grades;
          _lastFetchTime = fetchTime;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _toggleSelectAll() {
    if (_allGrades == null) return;

    setState(() {
      if (_isAllSelected) {
        _selectedCourseIds.clear();
        _isAllSelected = false;
      } else {
        _selectedCourseIds.clear();
        for (final grade in _allGrades!) {
          _selectedCourseIds.add(grade.courseId);
        }
        _isAllSelected = true;
      }
    });
  }

  void _toggleCourseSelection(String courseId) {
    setState(() {
      if (_selectedCourseIds.contains(courseId)) {
        _selectedCourseIds.remove(courseId);
      } else {
        _selectedCourseIds.add(courseId);
      }

      if (_allGrades != null) {
        final visibleCourseIds =
            _allGrades!.map((g) => g.courseId).toSet();
        _isAllSelected = visibleCourseIds.isNotEmpty &&
            visibleCourseIds.every((id) => _selectedCourseIds.contains(id));
      }
    });
  }

  void _showGradeDetail(CourseGradeItem grade) {
    showDialog(
      context: context,
      builder: (ctx) => _GradeDetailDialog(grade: grade),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showQuickCalculation() {
    if (_selectedCourseIds.isEmpty) {
      _showCalculationDialog(
        title: '快捷计算',
        content: '请先选择需要参与计算的课程，在左侧打勾。',
        isError: true,
      );
      return;
    }

    if (_allGrades == null) return;

    final selectedGrades = _allGrades!
        .where((grade) => _selectedCourseIds.contains(grade.courseId))
        .toList();

    if (selectedGrades.isEmpty) {
      _showCalculationDialog(
        title: '快捷计算',
        content: '选中的课程中没有有效的成绩数据。',
        isError: true,
      );
      return;
    }

    double totalScore = 0;
    double totalWeightedScore = 0;
    double totalCredits = 0;

    for (final grade in selectedGrades) {
      final score = grade.score.toDouble();
      final credit = grade.credit.toDouble();

      totalScore += score;
      totalWeightedScore += score * credit;
      totalCredits += credit;
    }

    final averageScore = totalScore / selectedGrades.length;
    final weightedScore = totalWeightedScore / totalCredits;

    _showCalculationDialog(
      title: '快捷计算',
      content: '已选择课程数：${selectedGrades.length}\n'
          '平均成绩：${averageScore.toStringAsFixed(4)}\n'
          '加权成绩：${weightedScore.toStringAsFixed(4)}',
      isError: false,
    );
  }

  void _showCalculationDialog({
    required String title,
    required String content,
    required bool isError,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageAppBar(title: '成绩查询'),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _allGrades == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载成绩...'),
          ],
        ),
      );
    }

    if (_errorMessage != null && _allGrades == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            const Text(
              '加载失败',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
                onPressed: _refreshGrades, child: const Text('重试')),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(padding: const EdgeInsets.all(12), child: _buildActionBar()),
        Expanded(child: _buildTableOrEmptyState()),
      ],
    );
  }

  Widget _buildTableOrEmptyState() {
    if (_allGrades == null || _allGrades!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assessment, size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              _allGrades == null ? '点击刷新获取成绩数据' : '暂无成绩数据',
              style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return _buildResponsiveTable();
  }

  Widget _buildActionBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              _lastFetchTime != null
                  ? '上次更新: ${_lastFetchTime!.toLocal().toString().substring(0, 16)}'
                  : '点击刷新获取成绩数据',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(
              Theme.of(context).colorScheme.primaryContainer,
            ),
            foregroundColor: WidgetStatePropertyAll(
              Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          onPressed: !_isLoading ? _refreshGrades : null,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 18),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(
              Theme.of(context).colorScheme.primaryContainer,
            ),
            foregroundColor: WidgetStatePropertyAll(
              Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          onPressed: _showQuickCalculation,
          child: const Icon(Icons.calculate, size: 18),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(
              Theme.of(context).colorScheme.primaryContainer,
            ),
            foregroundColor: WidgetStatePropertyAll(
              Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          onPressed: _showOverview,
          child: const Icon(Icons.analytics, size: 18),
        ),
      ],
    );
  }

  void _showOverview() {
    showDialog(
      context: context,
      builder: (ctx) => _GpaOverviewDialog(),
    );
  }

  Widget _buildResponsiveTable() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;

        final columnConfig = [
          {'name': '', 'minWidth': 50.0, 'flex': 0, 'isNumeric': false},
          {'name': '课程名称', 'minWidth': 160.0, 'flex': 5, 'isNumeric': false},
          {'name': '学分', 'minWidth': 60.0, 'flex': 1, 'isNumeric': true},
          {'name': '成绩', 'minWidth': 60.0, 'flex': 1, 'isNumeric': true},
        ];

        final totalMinWidth = columnConfig.fold<double>(
          0,
          (sum, col) => sum + (col['minWidth'] as double),
        );
        final totalFlex = columnConfig.fold<int>(
          0,
          (sum, col) => sum + (col['flex'] as int),
        );

        final needsHorizontalScroll = availableWidth < totalMinWidth;

        List<double> columnWidths;
        double tableWidth;

        if (needsHorizontalScroll) {
          columnWidths = columnConfig
              .map((col) => col['minWidth'] as double)
              .toList();
          tableWidth = totalMinWidth;
        } else {
          final extraWidth = availableWidth - totalMinWidth;
          columnWidths = columnConfig.map((col) {
            final minWidth = col['minWidth'] as double;
            final flex = col['flex'] as int;
            if (flex == 0) return minWidth;
            final extraForThisColumn = extraWidth * (flex / totalFlex);
            return minWidth + extraForThisColumn;
          }).toList();
          tableWidth = availableWidth;
        }

        final dividerColor = Theme.of(context)
            .colorScheme.outlineVariant.withValues(alpha: 0.4);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const AlwaysScrollableScrollPhysics(),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              width: tableWidth,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        borderRadius: needsHorizontalScroll
                            ? null
                            : const BorderRadius.vertical(
                                top: Radius.circular(16)),
                      ),
                      child: Row(
                        children:
                            columnConfig.asMap().entries.map((entry) {
                          final index = entry.key;
                          final column = entry.value;
                          final isCheckbox = index == 0;

                          if (isCheckbox) {
                            return SizedBox(
                              width: columnWidths[index],
                              child: Align(
                                alignment: Alignment.center,
                                child: Checkbox(
                                  value: _isAllSelected,
                                  onChanged: (_) => _toggleSelectAll(),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            );
                          } else {
                            return _buildHeaderCell(
                              column['name'] as String,
                              columnWidths[index],
                              isNumeric: column['isNumeric'] as bool,
                            );
                          }
                        }).toList(),
                      ),
                    ),
                    Divider(height: 1, color: dividerColor),
                    ...List.generate(_allGrades!.length, (i) {
                      final grade = _allGrades![i];
                      final isLast = i == _allGrades!.length - 1;
                      return Column(
                        children: [
                          if (i > 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              child: Divider(
                                  height: 1, color: dividerColor),
                            ),
                          InkWell(
                            onTap: () => _showGradeDetail(grade),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: i.isEven
                                    ? null
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerLowest,
                                borderRadius: isLast && !needsHorizontalScroll
                                    ? const BorderRadius.vertical(
                                        bottom: Radius.circular(16))
                                    : null,
                              ),
                              child: Row(children:
                                  _buildDataRow(grade, columnWidths)),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      ),
    );
  }

  List<Widget> _buildDataRow(CourseGradeItem grade, List<double> columnWidths) {
    return [
      SizedBox(
        width: columnWidths[0],
        child: Align(
          alignment: Alignment.center,
          child: Checkbox(
            value: _selectedCourseIds.contains(grade.courseId),
            onChanged: (_) => _toggleCourseSelection(grade.courseId),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
      _buildDataCell(_buildCourseNameCell(grade), columnWidths[1]),
      _buildDataCell(
        Text(grade.credit.toStringAsFixed(1)),
        columnWidths[2],
        isNumeric: true,
      ),
      _buildDataCell(
        Text(
          grade.score.toString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: grade.score >= 60
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
          ),
        ),
        columnWidths[3],
        isNumeric: true,
      ),
    ];
  }

  Widget _buildHeaderCell(String text, double width, {bool isNumeric = false}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
        textAlign: isNumeric ? TextAlign.center : TextAlign.left,
        maxLines: 2,
      ),
    );
  }

  Widget _buildDataCell(Widget child, double width, {bool isNumeric = false}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Align(
        alignment: isNumeric ? Alignment.center : Alignment.centerLeft,
        child: child,
      ),
    );
  }

  Widget _buildCourseNameCell(CourseGradeItem grade) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          grade.courseName,
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        if (grade.courseNameAlt != null && grade.courseNameAlt!.isNotEmpty)
          Text(
            grade.courseNameAlt!,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
      ],
    );
  }
}

class _GradeDetailDialog extends StatefulWidget {
  final CourseGradeItem grade;

  const _GradeDetailDialog({required this.grade});

  @override
  State<_GradeDetailDialog> createState() => _GradeDetailDialogState();
}

class _GradeDetailDialogState extends State<_GradeDetailDialog> {
  List<ScoreDetail>? _details;
  String? _detailError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  void _loadDetails() {
    final grade = widget.grade;
    if (grade.rwid.isEmpty || grade.cjid.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    final service = ServiceProvider.instance.coursesService;
    service.fetchScoreDetails(grade.rwid, grade.cjid).then((d) {
      if (mounted) setState(() { _details = d; _isLoading = false; });
    }).catchError((e) {
      if (mounted) setState(() { _detailError = e.toString(); _isLoading = false; });
    });
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grade = widget.grade;

    return AlertDialog(
      title: Text(grade.courseName),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _detailRow('课程代码', grade.courseId),
            _detailRow('课程名称', grade.courseName),
            if (grade.courseNameAlt != null && grade.courseNameAlt!.isNotEmpty)
              _detailRow('课程名称(英文)', grade.courseNameAlt!),
            _detailRow('学期', grade.termName),
            if (grade.termNameAlt.isNotEmpty)
              _detailRow('学期(英文)', grade.termNameAlt),
            if (grade.schoolName != null && grade.schoolName!.isNotEmpty)
              _detailRow('开课院系', grade.schoolName!),
            if (grade.schoolNameAlt != null && grade.schoolNameAlt!.isNotEmpty)
              _detailRow('开课院系(英文)', grade.schoolNameAlt!),
            _detailRow('课程性质', grade.type),
            _detailRow('课程类别', grade.category),
            if (grade.makeupStatus != null && grade.makeupStatus!.isNotEmpty)
              _detailRow('补考标记', grade.makeupStatus!),
            if (grade.examType != null && grade.examType!.isNotEmpty)
              _detailRow('考核方式', grade.examType!),
            _detailRow('学时', grade.hours.toStringAsFixed(1)),
            _detailRow('学分', grade.credit.toStringAsFixed(1)),
            _detailRow('成绩', grade.score.toString()),
            const Divider(height: 24),
            Text(
              '成绩明细',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            if (grade.rwid.isEmpty || grade.cjid.isEmpty)
              Text('暂无分项成绩数据',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant))
            else if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_detailError != null)
              Text('加载失败',
                  style: TextStyle(color: Theme.of(context).colorScheme.error))
            else if (_details != null && _details!.isNotEmpty)
              ..._details!.map((d) => _detailRow(
                    d.name,
                    '${d.score.toStringAsFixed(1)} / ${d.maxScore.toStringAsFixed(1)}  (${d.weight.toStringAsFixed(0)}%)',
                  ))
            else
              Text('暂无分项成绩数据',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            if (grade.rank != null || grade.totalStudents != null) ...[
              if (grade.rank != null)
                _detailRow('班级排名', '${grade.rank}'),
              if (grade.totalStudents != null)
                _detailRow('班级总人数', '${grade.totalStudents}'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

class _GpaOverviewDialog extends StatefulWidget {
  const _GpaOverviewDialog();

  @override
  State<_GpaOverviewDialog> createState() => _GpaOverviewDialogState();
}

class _GpaOverviewDialogState extends State<_GpaOverviewDialog> {
  GpaOverview? _data;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final service = ServiceProvider.instance.coursesService;
    // Try cached first
    final cached = service.getCachedGpaOverview();
    if (cached != null) {
      if (mounted) setState(() { _data = cached; _isLoading = false; });
      return;
    }
    // Fetch from page
    service.fetchGpaOverview().then((d) {
      if (mounted) setState(() { _data = d; _isLoading = false; });
    }).catchError((e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    });
  }

  Widget _row(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value ?? '-', style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('成绩总览'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text('加载失败',
                  style: TextStyle(color: Theme.of(context).colorScheme.error))
            else if (_data != null) ...[
              _row('排名', (_data!.rank != null && _data!.totalStudents != null)
                  ? '${_data!.rank} / ${_data!.totalStudents}' : null),
              _row('比例', _data!.ratio != null ? '${_data!.ratio}%' : null),
              _row('平均学分绩点排名', _data!.avgGpaRank),
              _row('获得学分', _data!.earnedCredits),
              _row('通过课程', _data!.passedCourses),
            ] else
              const Text('暂无数据'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
