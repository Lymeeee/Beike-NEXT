import 'package:flutter/material.dart';
import '/services/provider.dart';
import '/types/courses.dart';
import '/utils/app_bar.dart';

class ExamPage extends StatefulWidget {
  const ExamPage({super.key});

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;

  List<ExamInfo>? _exams;
  DateTime? _lastFetchTime;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCachedExams();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _loadCachedExams() {
    final cached = _serviceProvider.storeService.getPref<CachedExamList>(
      'cached_exams',
      CachedExamList.fromJson,
    );
    if (cached != null && mounted) {
      setState(() {
        _exams = cached.exams;
        _lastFetchTime = cached.fetchTime;
      });
    }
  }

  Future<void> _refreshExams() async {
    final service = _serviceProvider.coursesService;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentTerm = TermInfo.autoDetect();
      final exams = await service.getExams(currentTerm);
      final fetchTime = DateTime.now();

      _serviceProvider.storeService.putPref<CachedExamList>(
        'cached_exams',
        CachedExamList(exams: exams, fetchTime: fetchTime),
      );

      if (mounted) {
        setState(() {
          _exams = exams;
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

  void _showExamDetail(ExamInfo exam) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(exam.courseName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('课程代码', exam.courseId),
              _detailRow('课程名称', exam.courseName),
              if (exam.courseNameAlt != null &&
                  exam.courseNameAlt!.isNotEmpty &&
                  exam.courseNameAlt != exam.courseName)
                _detailRow('课程名称(英文)', exam.courseNameAlt!),
              _detailRow('考试类型', exam.examRange),
              if (exam.examRangeAlt != null && exam.examRangeAlt!.isNotEmpty)
                _detailRow('考试类型(英文)', exam.examRangeAlt!),
              _detailRow('日期', exam.examDateDisplay),
              _detailRow('星期', exam.examDayName),
              _detailRow('时间', exam.examTime),
              _detailRow('考场', exam.examRoom),
              if (exam.examBuilding != null &&
                  exam.examBuilding!.isNotEmpty &&
                  exam.examBuilding != exam.examRoom)
                _detailRow('教学楼', exam.examBuilding!),
              _detailRow('学期', '${exam.termYear}学年 第${exam.termSeason}学期'),
              _detailRow('第几周', '第${exam.examWeek}周'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageAppBar(title: '考试查询'),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _exams == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载考试信息...'),
          ],
        ),
      );
    }

    if (_errorMessage != null && _exams == null) {
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
                onPressed: _refreshExams, child: const Text('重试')),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(padding: const EdgeInsets.all(12), child: _buildActionBar()),
        Expanded(
          child: (_exams == null || _exams!.isEmpty)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment, size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text('暂无考试数据',
                          style: TextStyle(
                              fontSize: 18,
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : _buildTable(),
        ),
      ],
    );
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
                  : '点击刷新获取考试信息',
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
          onPressed: !_isLoading ? _refreshExams : null,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 18),
        ),
      ],
    );
  }

  Widget _buildTable() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;

        final columnConfig = [
          {'name': '课程名称', 'minWidth': 140.0, 'flex': 3, 'isNumeric': false},
          {'name': '日期', 'minWidth': 100.0, 'flex': 3, 'isNumeric': false},
          {'name': '时间', 'minWidth': 100.0, 'flex': 3, 'isNumeric': false},
          {'name': '考场位置', 'minWidth': 140.0, 'flex': 4, 'isNumeric': false},
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
                          return _buildHeaderCell(
                            column['name'] as String,
                            columnWidths[index],
                            isNumeric: column['isNumeric'] as bool,
                          );
                        }).toList(),
                      ),
                    ),
                    Divider(height: 1, color: dividerColor),
                    ...List.generate(_exams!.length, (i) {
                      final exam = _exams![i];
                      final isLast = i == _exams!.length - 1;
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
                            onTap: () => _showExamDetail(exam),
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
                              child: Row(
                                  children: _buildDataRow(
                                      exam, columnWidths)),
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

  List<Widget> _buildDataRow(ExamInfo exam, List<double> columnWidths) {
    return [
      _buildDataCell(_buildClassNameCell(exam), columnWidths[0]),
      _buildDataCell(_buildExamDateCell(exam), columnWidths[1]),
      _buildDataCell(_buildExamTimeCell(exam), columnWidths[2]),
      _buildDataCell(_buildExamRoomCell(exam), columnWidths[3]),
    ];
  }

  Widget _buildHeaderCell(String text, double width, {bool isNumeric = false}) {
    return Container(
      width: width,
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
        textAlign: isNumeric ? TextAlign.center : TextAlign.left,
        maxLines: 2,
      ),
    );
  }

  Widget _buildDataCell(Widget child, double width,
      {bool isNumeric = false}) {
    return Container(
      width: width,
      child: Align(
        alignment: isNumeric ? Alignment.center : Alignment.centerLeft,
        child: child,
      ),
    );
  }

  Widget _buildClassNameCell(ExamInfo exam) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          exam.courseName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        if (exam.courseNameAlt != null &&
            exam.courseNameAlt!.isNotEmpty &&
            exam.courseNameAlt != exam.courseName)
          Text(
            exam.courseNameAlt!,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
      ],
    );
  }

  Widget _buildExamDateCell(ExamInfo exam) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          exam.examDateDisplay,
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        Text(
          "第${exam.examWeek}周 ${exam.examDayName}",
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildExamTimeCell(ExamInfo exam) {
    final now = DateTime.now();
    final startTime = exam.getStartTime();
    String? remainingText;

    if (startTime != null) {
      final difference = startTime.difference(now);
      if (!difference.isNegative) {
        final days = difference.inDays;
        if (days < 21) {
          final hours = difference.inHours % 24;
          remainingText = '剩余 $days 天 $hours 小时';
        } else {
          remainingText = '剩余 $days 天';
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          exam.examTime,
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        if (remainingText != null)
          Text(
            remainingText,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
      ],
    );
  }

  Widget _buildExamRoomCell(ExamInfo exam) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          exam.examRoom,
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        if (exam.examBuilding != null &&
            exam.examBuilding!.isNotEmpty &&
            exam.examBuilding != exam.examRoom)
          Text(
            exam.examBuilding!,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
      ],
    );
  }
}
