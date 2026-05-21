import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/date_utils.dart' as du;
import '../utils/theme.dart';
import '../widgets/task_list_tile.dart';
import '../widgets/mic_button.dart';

class PoolDetailPage extends StatefulWidget {
  final TaskPool pool;
  const PoolDetailPage({super.key, required this.pool});

  @override
  State<PoolDetailPage> createState() => _PoolDetailPageState();
}

class _PoolDetailPageState extends State<PoolDetailPage> {
  bool _selectionMode = false;
  final _selectedIds = <String>{};
  String? _expandedTaskId;
  bool _slideCompleting = false;
  final _slideCompleteIds = <String>{};
  final _slideUndoIds = <String>{};
  double? _slideStartY;
  bool _slideSelecting = false;
  final _tileKeys = <String, GlobalKey>{};
  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskProvider>();
    final settings = context.watch<SettingsProvider>();
    final today = du.getTodayDate(DateTime.now(), settings.dayBoundary);

    final activeTasks = tasks.activeInPool(widget.pool);
    final donePending = tasks.donePendingFor(widget.pool);
    final allTasks = [...activeTasks, ...donePending];
    final todayActive = widget.pool == TaskPool.daily
        ? activeTasks.where((t) => t.targetDate == today).toList()
        : <Task>[];
    final todayDone = widget.pool == TaskPool.daily
        ? donePending.where((t) => t.targetDate == today).toList()
        : <Task>[];
    final otherActive = widget.pool == TaskPool.daily
        ? activeTasks.where((t) => t.targetDate != today).toList()
        : activeTasks;
    final otherDone = widget.pool == TaskPool.daily
        ? donePending.where((t) => t.targetDate != today).toList()
        : donePending;

    final title = settings.poolDisplayName(widget.pool.name);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppTheme.of(context).surface,
        middle: Text(title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _showCreateForm,
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: Icon(CupertinoIcons.add_circled, size: 24),
              ),
            ),
            _selectionMode
                ? GestureDetector(
                    onTap: () => setState(() {
                      _selectionMode = false;
                      _selectedIds.clear();
                    }),
                    child: Text('完成', style: TextStyle(fontSize: 16)),
                  )
                : GestureDetector(
                    onTap: () => setState(() => _selectionMode = true),
                    child: Text('选择', style: TextStyle(fontSize: 16)),
                  ),
          ],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: NotificationListener<SlideCompleteNotification>(
                    onNotification: _onSlideNotify,
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: (_slideCompleting || _slideSelecting)
                          ? const NeverScrollableScrollPhysics()
                          : const ClampingScrollPhysics(),
                      slivers: [
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),
                    // Today section (daily pool only)
                    if (widget.pool == TaskPool.daily && (todayActive.isNotEmpty || todayDone.isNotEmpty)) ...[
                      _sectionHeader('今日任务'),
                      ...todayActive.map((t) => _taskTile(t, false)),
                      if (todayDone.isNotEmpty) ...[
                        _doneSeparator(todayDone.length),
                        ...todayDone.map((t) => _taskTile(t, true)),
                      ],
                      if (otherActive.isNotEmpty || otherDone.isNotEmpty) _divider(),
                    ],
                    // Other tasks
                    if (widget.pool == TaskPool.daily && (otherActive.isNotEmpty || otherDone.isNotEmpty))
                      ...[
                        ...otherActive.map((t) => _taskTile(t, false)),
                        if (otherDone.isNotEmpty) ...[
                          _doneSeparator(otherDone.length),
                          ...otherDone.map((t) => _taskTile(t, true)),
                        ],
                      ]
                    else if (widget.pool != TaskPool.daily)
                      ...[
                        ...activeTasks.map((t) => _taskTile(t, false)),
                        if (donePending.isNotEmpty) ...[
                          _doneSeparator(donePending.length),
                          ...donePending.map((t) => _taskTile(t, true)),
                        ],
                      ]
                    else if (activeTasks.isEmpty && donePending.isEmpty)
                      _emptySection(settings.emptyText(widget.pool.name)),
                  ],
                ),
              ),
            ),
            if (_selectionMode)
                Container(
                  width: MediaQuery.of(context).size.width - 80,
                  margin: EdgeInsets.fromLTRB(40, 0, 40, 10),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.of(context).surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SafeArea(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.of(context).surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                                _selectedIds.length == allTasks.length &&
                                        allTasks.isNotEmpty
                                    ? '全不选'
                                    : '全选'),
                          ),
                          onPressed: () {
                            setState(() {
                              if (_selectedIds.length == allTasks.length &&
                                  allTasks.isNotEmpty) {
                                _selectedIds.clear();
                              } else {
                                _selectedIds.addAll(
                                    allTasks.map((t) => t.id));
                              }
                            });
                          },
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.of(context).surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('删除', style: TextStyle(color: AppTheme.of(context).destructive)),
                          ),
                          onPressed: () async {
                            await tasks.deleteTasksBatch(_selectedIds.toList());
                            _selectedIds.clear();
                            setState(() => _selectionMode = false);
                          },
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.of(context).surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('移动到'),
                          ),
                          onPressed: () => _showMoveSheet(tasks),
                        ),
                        if (widget.pool == TaskPool.daily)
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.of(context).surface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(settings.moveTomorrowText),
                            ),
                            onPressed: () async {
                              final tomorrow = du.getTomorrowDate(DateTime.now(), settings.dayBoundary);
                              for (final id in _selectedIds.toList()) {
                                await tasks.moveToToday(id, tomorrow);
                              }
                              _selectedIds.clear();
                              setState(() => _selectionMode = false);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          Positioned(
            right: 36,
            bottom: 98,
            child: MicButton(defaultPool: widget.pool),
          ),
        ],
      ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 6),
        child: Text(title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.of(context).text)),
      ),
    );
  }

  Widget _divider() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: SizedBox(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppTheme.of(context).separator),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _doneSeparator(int count) {
    final tasks = context.read<TaskProvider>();
    return SliverToBoxAdapter(
      child: AnimatedOpacity(
        opacity: tasks.isDoneFading ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 600),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Container(height: 1, color: AppTheme.of(context).separator),
              ),
              SizedBox(width: 8),
              Text('已完成：$count 条',
                  style: TextStyle(
                      fontSize: 13, color: AppTheme.of(context).textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptySection(String text) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Text(text, style: TextStyle(fontSize: 14, color: AppTheme.of(context).textSecondary)),
      ),
    );
  }

  Widget _taskTile(Task task, bool isDone) {
    final tp = context.read<TaskProvider>();
    return _taskTileWithFade(task, isDone, isDone && tp.isDoneFading);
  }

  Widget _taskTileWithFade(Task task, bool isDone, bool fading) {
    final isExpanded = _expandedTaskId == task.id;
    final key = _tileKeys.putIfAbsent(task.id, () => GlobalKey());
    final tp = context.read<TaskProvider>();
    return SliverToBoxAdapter(
      child: Container(
        key: key,
        child: Column(
        children: [
          TaskListTile(
            key: ValueKey(task.id),
            task: task,
            selectionMode: _selectionMode,
            isSelected: _selectedIds.contains(task.id),
            slideCompleting: _slideCompleteIds.contains(task.id),
            slideUndoing: _slideUndoIds.contains(task.id),
            isDone: isDone,
            fading: fading,
            onMarkDone: _selectionMode
                ? null
                : () => tp.markDonePending(task.id),
            onUndo: isDone
                ? () => tp.undoDonePending(task.id)
                : null,
            onSelect: _selectionMode
                ? () {
                    setState(() {
                      if (_selectedIds.contains(task.id)) {
                        _selectedIds.remove(task.id);
                      } else {
                        _selectedIds.add(task.id);
                      }
                    });
                  }
                : null,
            onTap: _selectionMode
                ? null
                : () {
                    setState(() {
                      _expandedTaskId =
                          isExpanded ? null : task.id;
                    });
                  },
          ),
          if (isExpanded) _detailEditor(task, tp),
        ],
      ),
    ),
    );
  }

  Widget _detailEditor(Task task, TaskProvider tasks) {
    final titleCtrl = TextEditingController(text: task.title);
    final notesCtrl = TextEditingController(text: task.notes ?? '');
    final targetCtrl = TextEditingController(text: task.targetDate ?? '');
    final ddlCtrl = TextEditingController(text: task.ddl ?? '');

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.of(context).surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CupertinoTextField(
            controller: titleCtrl,
            placeholder: '任务标题',
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 8),
          CupertinoTextField(
            controller: notesCtrl,
            placeholder: '备注',
            maxLines: 3,
            minLines: 1,
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: targetCtrl,
                  placeholder: '目标日期 (YYYY-MM-DD)',
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  style: TextStyle(fontSize: 13),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: CupertinoTextField(
                  controller: ddlCtrl,
                  placeholder: '截止日期 (YYYY-MM-DD)',
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Text('重要性：',
                  style: TextStyle(fontSize: 13,
                      color: AppTheme.of(context).textSecondary)),
              CupertinoSegmentedControl<String>(
                groupValue: task.importance.name,
                onValueChanged: (v) {
                  tasks.updateTaskFields(task.id,
                      importance: TaskImportance.values.byName(v));
                },
                children: const {
                  'normal': Text('普通', style: TextStyle(fontSize: 12)),
                  'important': Text('重要', style: TextStyle(fontSize: 12)),
                },
              ),
            ],
          ),
          SizedBox(height: 10),
          Center(
            child: CupertinoButton(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text('保存修改'),
              onPressed: () {
                final newTitle = titleCtrl.text.trim();
                if (newTitle.isNotEmpty) {
                  tasks.updateTaskFields(
                    task.id,
                    title: newTitle,
                    notes: notesCtrl.text.trim().isEmpty
                        ? null
                        : notesCtrl.text.trim(),
                    targetDate: targetCtrl.text.trim().isEmpty
                        ? null
                        : targetCtrl.text.trim(),
                    ddl: ddlCtrl.text.trim().isEmpty
                        ? null
                        : ddlCtrl.text.trim(),
                  );
                }
                setState(() => _expandedTaskId = null);
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _onSlideNotify(SlideCompleteNotification n) {
    if (_selectionMode) {
      if (n.isStart) {
        setState(() {
          _slideSelecting = true;
          _selectedIds.add(n.taskId);
          _slideStartY = n.globalPosition.dy;
        });
        return false;
      }
      if (n.isEnd) {
        setState(() {
          _slideSelecting = false;
          _slideStartY = null;
        });
        return false;
      }
      if (!_slideSelecting) return false;
      _selectedIds
        ..clear()
        ..addAll(_rubberBand(n.globalPosition.dy));
      setState(() {});
      return false;
    }
    if (n.isStart) {
      setState(() {
        _slideCompleting = true;
        _slideCompleteIds.add(n.taskId);
        _slideStartY = n.globalPosition.dy;
      });
      return false;
    }
    if (n.isEnd) {
      final tp = context.read<TaskProvider>();
      for (final id in _slideCompleteIds) {
        tp.markDonePending(id);
      }
      for (final id in _slideUndoIds) {
        tp.undoDonePending(id);
      }
      setState(() {
        _slideCompleting = false;
        _slideCompleteIds.clear();
        _slideUndoIds.clear();
        _slideStartY = null;
      });
      return false;
    }
    if (!_slideCompleting) return false;
    _splitRubberBand(n.globalPosition.dy);
    setState(() {});
    return false;
  }

  void _splitRubberBand(double fingerY) {
    final covered = _rubberBand(fingerY);
    final tp = context.read<TaskProvider>();
    final doneIds = tp.donePending.map((t) => t.id).toSet();
    _slideCompleteIds.clear();
    _slideUndoIds.clear();
    for (final id in covered) {
      if (doneIds.contains(id)) {
        _slideUndoIds.add(id);
      } else {
        _slideCompleteIds.add(id);
      }
    }
  }

  /// 橡皮筋：固定端 _slideStartY，拖拽端 fingerY，返回被覆盖的条目 ID 集合
  Set<String> _rubberBand(double fingerY) {
    if (_slideStartY == null) return {};
    final bandTop = _slideStartY! < fingerY ? _slideStartY! : fingerY;
    final bandBot = _slideStartY! > fingerY ? _slideStartY! : fingerY;
    final ids = <String>{};
    for (final entry in _tileKeys.entries) {
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      final bot = top + box.size.height;
      if (top <= bandBot && bot >= bandTop) ids.add(entry.key);
    }
    return ids;
  }

  void _showMoveSheet(TaskProvider tasks) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('移动到'),
        actions: TaskPool.values
            .where((p) => p != widget.pool)
            .map((p) => CupertinoActionSheetAction(
                  onPressed: () {
                    tasks.moveToPoolBatch(_selectedIds.toList(), p);
                    _selectedIds.clear();
                    Navigator.pop(ctx);
                    setState(() => _selectionMode = false);
                  },
                  child: Text(_poolLabel(p)),
                ))
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text('取消'),
        ),
      ),
    );
  }

  String _poolLabel(TaskPool p) {
    switch (p) {
      case TaskPool.daily: return '日常待办';
      case TaskPool.light: return '轻任务';
      case TaskPool.longterm: return '长期目标';
    }
  }

  void _showCreateForm() {
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final ddlCtrl = TextEditingController();
    var importance = TaskImportance.normal;
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setFormState) => Center(
          child: Container(
            width: 320,
            margin: EdgeInsets.only(bottom: 120),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CupertinoTheme.of(ctx).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('新建任务',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.of(context).text)),
                SizedBox(height: 16),
                CupertinoTextField(
                  controller: titleCtrl,
                  placeholder: '任务标题',
                  autofocus: true,
                  padding: EdgeInsets.all(12),
                ),
                SizedBox(height: 8),
                CupertinoTextField(
                  controller: notesCtrl,
                  placeholder: '备注（选填）',
                  maxLines: 2,
                  padding: EdgeInsets.all(12),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoTextField(
                        controller: targetCtrl,
                        placeholder: '目标日期 YYYY-MM-DD',
                        padding: EdgeInsets.all(12),
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: CupertinoTextField(
                        controller: ddlCtrl,
                        placeholder: '截止日期 YYYY-MM-DD',
                        padding: EdgeInsets.all(12),
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Text('重要性：',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.of(context).textSecondary)),
                    CupertinoSegmentedControl<String>(
                      groupValue: importance.name,
                      onValueChanged: (v) => setFormState(() =>
                          importance = TaskImportance.values.byName(v)),
                      children: const {
                        'normal': Text('普通', style: TextStyle(fontSize: 12)),
                        'important':
                            Text('重要', style: TextStyle(fontSize: 12)),
                      },
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CupertinoButton(
                      child: Text('取消'),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    CupertinoButton.filled(
                      child: Text('创建'),
                      onPressed: () {
                        final title = titleCtrl.text.trim();
                        if (title.isEmpty) return;
                        context.read<TaskProvider>().createTask(
                              title: title,
                              notes: notesCtrl.text.trim().isEmpty
                                  ? null
                                  : notesCtrl.text.trim(),
                              targetDate: targetCtrl.text.trim().isEmpty
                                  ? null
                                  : targetCtrl.text.trim(),
                              ddl: ddlCtrl.text.trim().isEmpty
                                  ? null
                                  : ddlCtrl.text.trim(),
                              importance: importance,
                              pool: widget.pool,
                            );
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
