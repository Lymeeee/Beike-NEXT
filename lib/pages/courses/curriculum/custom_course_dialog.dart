import 'package:flutter/material.dart';
import '/types/courses.dart';

class CustomCourseDialog extends StatefulWidget {
  final int day;
  final int period;
  final int maxWeek;
  final ClassItem? existing;

  const CustomCourseDialog({
    super.key,
    required this.day,
    required this.period,
    required this.maxWeek,
    this.existing,
  });

  @override
  State<CustomCourseDialog> createState() => _CustomCourseDialogState();
}

class _CustomCourseDialogState extends State<CustomCourseDialog> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _teacherController = TextEditingController();
  final _weeks = <int>{};
  bool _nameError = false;
  bool _locationError = false;

  static const _dayNames = ['一', '二', '三', '四', '五', '六', '日'];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _nameController.text = e.className;
      _locationController.text = e.locationName;
      _teacherController.text = e.teacherName;
      _weeks.addAll(e.weeks);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _teacherController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final location = _locationController.text.trim();

    setState(() {
      _nameError = name.isEmpty;
      _locationError = location.isEmpty;
    });

    if (_nameError || _locationError) return;

    if (_weeks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一个周次')),
      );
      return;
    }

    final sortedWeeks = _weeks.toList()..sort();
    final weeksText = _buildWeeksText(sortedWeeks);

    final course = ClassItem(
      day: widget.day,
      period: widget.period,
      weeks: sortedWeeks,
      weeksText: weeksText,
      className: name,
      teacherName: _teacherController.text.trim(),
      locationName: location,
      periodName: widget.existing?.periodName ?? '',
      isCustom: true,
    );

    Navigator.of(context).pop(course);
  }

  void _delete() {
    Navigator.of(context).pop('delete');
  }

  String _buildWeeksText(List<int> weeks) {
    if (weeks.isEmpty) return '';
    final buffer = StringBuffer();
    int start = weeks.first;
    int end = weeks.first;
    for (int i = 1; i < weeks.length; i++) {
      if (weeks[i] == end + 1) {
        end = weeks[i];
      } else {
        if (buffer.isNotEmpty) buffer.write(',');
        buffer.write(start == end ? '$start' : '$start-$end');
        start = weeks[i];
        end = weeks[i];
      }
    }
    if (buffer.isNotEmpty) buffer.write(',');
    buffer.write(start == end ? '$start' : '$start-$end');
    return '$buffer周';
  }

  void _showWeekPicker() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final allSelected = _weeks.length == widget.maxWeek;
            return AlertDialog(
              title: Row(
                children: [
                  const Text('选择周次'),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setDialogState(() {
                        if (allSelected) {
                          _weeks.clear();
                        } else {
                          _weeks.addAll(
                            List.generate(widget.maxWeek, (i) => i + 1),
                          );
                        }
                      });
                    },
                    child: Text(allSelected ? '取消全选' : '全选'),
                  ),
                ],
              ),
              content: SizedBox(
                width: 280,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: List.generate(widget.maxWeek, (index) {
                    final week = index + 1;
                    final selected = _weeks.contains(week);
                    return FilterChip(
                      label: Text('$week'),
                      selected: selected,
                      onSelected: (val) {
                        setDialogState(() {
                          if (val) {
                            _weeks.add(week);
                          } else {
                            _weeks.remove(week);
                          }
                        });
                      },
                    );
                  }),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {});
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = _isEditing;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(isEdit ? '编辑自定义课程' : '添加自定义课程'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.grid_view, size: 18,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    '周${_dayNames[widget.day - 1]}  第${widget.period}大节',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '课程名 *',
                border: const OutlineInputBorder(),
                errorText: _nameError ? '课程名不能为空' : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: '地点 *',
                border: const OutlineInputBorder(),
                errorText: _locationError ? '地点不能为空' : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _teacherController,
              decoration: const InputDecoration(
                labelText: '教师名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _showWeekPicker,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '周数',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                child: Text(
                  _weeks.isEmpty
                      ? '点击选择周次'
                      : '${_weeks.length}周: ${(_weeks.toList()..sort()).join(', ')}',
                  style: TextStyle(
                    color: _weeks.isEmpty
                        ? theme.colorScheme.onSurfaceVariant
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (isEdit)
          TextButton.icon(
            onPressed: _delete,
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('删除'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEdit ? '保存' : '添加'),
        ),
      ],
    );
  }
}
