import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/services/courses/family_share.dart';
import '/services/provider.dart';
import '/types/courses.dart';
import '/utils/haptic.dart';
import 'family_view.dart';

/// 亲情课表在 Store 中的 key（pref）
const String _familyStoreKey = 'family_curriculums';

/// 最多保存的他人课表份数
const int _maxFamilyItems = 20;

/// 打开亲情课表弹窗：导入 / 导出 / 管理他人课表
Future<void> showFamilyCurriculumDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _FamilyCurriculumDialog(),
  );
}

class _FamilyCurriculumDialog extends StatefulWidget {
  const _FamilyCurriculumDialog();

  @override
  State<_FamilyCurriculumDialog> createState() =>
      _FamilyCurriculumDialogState();
}

class _FamilyCurriculumDialogState extends State<_FamilyCurriculumDialog> {
  List<FamilyCurriculum> _items = [];

  @override
  void initState() {
    super.initState();
    _items = _readItems();
  }

  List<FamilyCurriculum> _readItems() =>
      ServiceProvider.instance.storeService
          .getPref<FamilyCurriculumList>(
            _familyStoreKey,
            FamilyCurriculumList.fromJson,
          )
          ?.items ??
      [];

  void _save() {
    ServiceProvider.instance.storeService.putPref<FamilyCurriculumList>(
      _familyStoreKey,
      FamilyCurriculumList(items: _items),
    );
  }

  /// 置顶的排在前面，同组内保持原有顺序
  void _sortItems() {
    _items = [
      ..._items.where((e) => e.pinned),
      ..._items.where((e) => !e.pinned),
    ];
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---- 导入 / 导出 ----

  Future<void> _import() async {
    final item = await showDialog<FamilyCurriculum>(
      context: context,
      builder: (context) => const _ImportDialog(),
    );
    if (item == null || !mounted) return;

    final duplicate = _items
        .where((e) => e.name.isNotEmpty && e.name == item.name)
        .firstOrNull;
    if (duplicate == null && _items.length >= _maxFamilyItems) {
      _snack('最多保存 $_maxFamilyItems 份课表，请先删除一些');
      return;
    }
    if (duplicate != null) {
      final overwrite = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('已存在同名课表'),
          content: Text('已经有一份「${item.displayName}的课表」，导入后将替换旧的一份。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('替换'),
            ),
          ],
        ),
      );
      if (overwrite != true || !mounted) return;
    }

    // 本机内重新生成 id：同一份文本码被导入多次时，各份仍能独立管理
    final stored = FamilyCurriculum(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: item.name,
      term: item.term,
      classes: item.classes,
      periods: item.periods,
    );
    setState(() {
      if (duplicate != null) _items.remove(duplicate);
      _items.insert(0, stored);
      _sortItems();
    });
    _save();
    _snack('已导入「${stored.displayName}的课表」');
  }

  Future<void> _export() async {
    final store = ServiceProvider.instance.storeService;
    final my = store.getConfig<CurriculumIntegratedData>(
      'curriculum_data',
      CurriculumIntegratedData.fromJson,
    );
    final term = my?.currentTerm;
    if (my == null || term == null || my.allClasses.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('暂无可导出的课表'),
          content: const Text('本机还没有课表数据，请先在课表页刷新课表，再来导出。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }

    final custom = store
            .getPref<CustomCoursesList>(
              'custom_courses_${term.year}_${term.season}',
              CustomCoursesList.fromJson,
            )
            ?.courses ??
        const <ClassItem>[];
    final account = store.getConfig<UserLoginIntegratedData>(
      'course_account_data',
      UserLoginIntegratedData.fromJson,
    );

    final curriculum = FamilyCurriculum(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: (account?.user?.userName ?? '').trim(),
      term: term,
      classes: [...my.allClasses, ...custom],
      periods: my.allPeriods,
    );
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => _ExportDialog(curriculum: curriculum),
    );
  }

  // ---- 列表项操作 ----

  void _openView(FamilyCurriculum item) {
    final my = ServiceProvider.instance.storeService
        .getConfig<CurriculumIntegratedData>(
          'curriculum_data',
          CurriculumIntegratedData.fromJson,
        );
    final sameTerm = my != null &&
        my.currentTerm.year == item.term.year &&
        my.currentTerm.season == item.term.season;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FamilyCurriculumViewPage(
          item: item,
          calendarDays: sameTerm ? my.calendarDays : null,
        ),
      ),
    );
  }

  void _replace(FamilyCurriculum item) {
    setState(() {
      final idx = _items.indexWhere((e) => e.id == item.id);
      if (idx >= 0) _items[idx] = item;
      _sortItems();
    });
    _save();
  }

  Future<void> _manage(FamilyCurriculum item) async {
    Haptics.medium();
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => _ManageSheet(item: item),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case 'pin':
        _replace(item.copyWith(pinned: !item.pinned));
      case 'rename':
        await _rename(item);
      case 'delete':
        await _delete(item);
    }
  }

  Future<void> _rename(FamilyCurriculum item) async {
    final controller = TextEditingController(text: item.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: '课表主人姓名',
            hintText: '如：张三',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (newName == null || !mounted) return;
    _replace(item.copyWith(name: newName));
  }

  Future<void> _delete(FamilyCurriculum item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除「${item.displayName}的课表」？'),
        content: const Text('删除后不再保留这份课表，可以让对方重新发文本码导入。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _items.removeWhere((e) => e.id == item.id));
    _save();
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('亲情课表'),
      titleTextStyle: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
      contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 36,
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          Haptics.medium();
                          _export();
                        },
                        icon: const Icon(Icons.file_upload_outlined, size: 18),
                        label: const Text('导出课表'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          Haptics.medium();
                          _import();
                        },
                        icon: const Icon(Icons.file_download_outlined, size: 18),
                        label: const Text('导入课表'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_items.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  child: Text(
                    '还没有导入的课表。\n让对方「导出课表」后把文本码发给你，粘贴到「导入课表」里即可。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else ...[
                for (final item in _items) _buildItem(theme, item),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(ThemeData theme, FamilyCurriculum item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Haptics.selection();
            _openView(item);
          },
          onLongPress: () => _manage(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.favorite, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.displayName}的课表',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.term.year} 学年 第${item.term.season}学期'
                        ' · ${item.classes.length} 门课程',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.pinned)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.push_pin,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 长按列表项弹出的操作单
class _ManageSheet extends StatelessWidget {
  const _ManageSheet({required this.item});

  final FamilyCurriculum item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Icon(Icons.favorite, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${item.displayName}的课表',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(
              item.pinned ? Icons.push_pin_outlined : Icons.push_pin,
            ),
            title: Text(item.pinned ? '取消置顶' : '置顶'),
            onTap: () {
              Haptics.selection();
              Navigator.of(context).pop('pin');
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('重命名'),
            onTap: () {
              Haptics.selection();
              Navigator.of(context).pop('rename');
            },
          ),
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: theme.colorScheme.error,
            ),
            title: Text(
              '删除',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () {
              Haptics.selection();
              Navigator.of(context).pop('delete');
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// 导入：粘贴文本码
class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    setState(() {
      _controller.text = text;
      _error = null;
    });
  }

  void _submit() {
    try {
      final item = FamilyCurriculumCodec.decode(_controller.text);
      Haptics.medium();
      Navigator.of(context).pop(item);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('导入课表'),
      titleTextStyle: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
      contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      content: SizedBox(
        width: 400,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _controller,
                minLines: 4,
                maxLines: 6,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: '粘贴对方发来的课表文本码（BKNKC1:…）',
                  suffixIcon: IconButton(
                    tooltip: '从剪贴板粘贴',
                    onPressed: () {
                      Haptics.selection();
                      _pasteFromClipboard();
                    },
                    icon: const Icon(Icons.content_paste, size: 18),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                '文本码不包含账号信息，对方可在「导出课表」里复制得到。',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('导入'),
        ),
      ],
    );
  }
}

/// 导出：展示文本码并复制
class _ExportDialog extends StatefulWidget {
  const _ExportDialog({required this.curriculum});

  final FamilyCurriculum curriculum;

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  bool _copied = false;

  late final String _code = FamilyCurriculumCodec.encode(widget.curriculum);

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _code));
    if (!mounted) return;
    Haptics.medium();
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.curriculum;

    return AlertDialog(
      title: const Text('导出课表'),
      titleTextStyle: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
      contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '课表：${item.displayName}'
                        '（${item.term.year} 学年 第${item.term.season}学期）',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '共 ${item.classes.length} 门课程',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 140),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _code,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '点「复制文本码」后发给对方，让对方在「导入课表」里粘贴。',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
        FilledButton.icon(
          onPressed: _copy,
          icon: Icon(
            _copied ? Icons.check : Icons.copy,
            size: 18,
          ),
          label: Text(_copied ? '已复制' : '复制文本码'),
        ),
      ],
    );
  }
}
