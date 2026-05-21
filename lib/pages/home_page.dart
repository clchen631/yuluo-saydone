import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../providers/settings_provider.dart';
import '../models/task.dart';
import '../utils/date_utils.dart' as du;
import '../utils/strings.dart' as str;
import '../utils/theme.dart';
import '../widgets/task_list_tile.dart';
import '../widgets/mic_button.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  bool _tomorrowExpanded = false;
  List<Task> _lightTasks = [];
  List<Task> _longtermGoals = [];
  bool _selectionMode = false;
  final _selectedIds = <String>{};
  bool _slideCompleting = false;
  final _slideCompleteIds = <String>{};
  final _slideUndoIds = <String>{};
  double? _slideStartY;
  final _tileKeys = <String, GlobalKey>{};
  final _scrollController = ScrollController();
  bool _scrollEnabled = false;
  int _prevActiveCount = -1;

  @override
  void initState() {
    super.initState();
    context.read<TaskProvider>().addListener(_onTasksChanged);
    _scrollController.addListener(_checkScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
  }

  @override
  void dispose() {
    context.read<TaskProvider>().removeListener(_onTasksChanged);
    _scrollController.removeListener(_checkScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkScroll() {
    if (!_scrollController.hasClients) return;
    final canScroll = _scrollController.position.maxScrollExtent > 0;
    if (canScroll != _scrollEnabled && mounted) {
      setState(() => _scrollEnabled = canScroll);
    }
  }

  void _onTasksChanged() {
    if (mounted) _refreshLight();
  }

  void refreshData() {
    if (mounted) _refreshLight();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = context.read<TaskProvider>();
    final settings = context.watch<SettingsProvider>();
    final today = du.getTodayDate(DateTime.now(), settings.dayBoundary);
    final tomorrow = du.getTomorrowDate(DateTime.now(), settings.dayBoundary);

    final todayTasks = tasks.todayTasks(today);
    final overdueTasks = tasks.overdueTasks(today);
    final tomorrowTasks = tasks.tomorrowTasks(tomorrow);
    final dailyDonePending = tasks.donePendingFor(TaskPool.daily);
    final lightDonePending = tasks.donePendingFor(TaskPool.light);
    final longtermDonePending = tasks.donePendingFor(TaskPool.longterm);
    final todayDonePending = dailyDonePending
        .where((t) => t.targetDate == today)
        .toList();
    final overdueDonePending = dailyDonePending
        .where((t) => t.targetDate != null && t.targetDate!.isNotEmpty && t.targetDate!.compareTo(today) < 0)
        .toList();
    final tomorrowDonePending = dailyDonePending
        .where((t) => t.targetDate == tomorrow)
        .toList();

    final allOverdueIds = {
      ...overdueTasks.map((t) => t.id),
      ...overdueDonePending.map((t) => t.id),
    };

    final currentActiveCount = tasks.allTasks.length;
    if (_prevActiveCount != currentActiveCount) {
      _prevActiveCount = currentActiveCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshLight();
      });
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppTheme.of(context).surface,
        middle: Text('语落SayDone'),
        trailing: overdueTasks.isNotEmpty
            ? GestureDetector(
                onTap: () => setState(() {
                  _selectionMode = !_selectionMode;
                  if (!_selectionMode) _selectedIds.clear();
                }),
                child: Text(
                  _selectionMode ? '完成' : '选择',
                  style: TextStyle(fontSize: 16),
                ),
              )
            : null,
      ),
      child: Column(
        children: [
          Expanded(
            child: SafeArea(
              child: Stack(
                children: [
                  NotificationListener<SlideCompleteNotification>(
                    onNotification: _onSlideNotify,
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: _slideCompleting
                          ? const NeverScrollableScrollPhysics()
                          : (_scrollEnabled
                              ? const ClampingScrollPhysics()
                              : const NeverScrollableScrollPhysics()),
                      slivers: [
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),
                        // ── 今日待办 ──
                        _sectionCard(
                          title: str.AppStrings.todayTodo,
                          minHeight: 240,
                          emptyText: todayTasks.isEmpty && overdueTasks.isEmpty && todayDonePending.isEmpty && overdueDonePending.isEmpty
                              ? str.AppStrings.emptyDaily
                              : null,
                          children: [
                            ...todayTasks.map((t) => _taskTile(t, null)),
                            if (todayDonePending.isNotEmpty) ...[
                              _doneSeparator(todayDonePending.length, tasks.isDoneFading),
                              ...todayDonePending.map((t) => _taskTile(t, null, isDone: true, fading: tasks.isDoneFading)),
                            ],
                            if (overdueTasks.isNotEmpty || overdueDonePending.isNotEmpty) ...[
                              _sectionDivider(str.AppStrings.yesterdayIncomplete),
                              ...overdueTasks.map((t) => _taskTile(t, allOverdueIds)),
                              if (overdueDonePending.isNotEmpty) ...[
                                _doneSeparator(overdueDonePending.length, tasks.isDoneFading),
                                ...overdueDonePending.map((t) => _taskTile(t, allOverdueIds, isDone: true, fading: tasks.isDoneFading)),
                              ],
                            ],
                          ],
                        ),
                        // ── 轻任务 ──
                        _sectionCard(
                          title: str.AppStrings.lightTasks,
                          minHeight: 110,
                          emptyText: _lightTasks.isEmpty && lightDonePending.isEmpty
                              ? str.AppStrings.emptyLight
                              : null,
                          headerTrailing: _lightTasks.isNotEmpty
                              ? CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: _refreshLight,
                                  child: Text('刷新',
                                      style: TextStyle(fontSize: 13)),
                                )
                              : null,
                          children: [
                            ..._lightTasks
                                .map((t) => _taskTile(t, null)),
                            if (lightDonePending.isNotEmpty) ...[
                              _doneSeparator(lightDonePending.length, tasks.isDoneFading),
                              ...lightDonePending
                                .map((t) => _taskTile(t, null, isDone: true, fading: tasks.isDoneFading)),
                            ],
                          ],
                        ),
                        // ── 长期目标 ──
                        _sectionCard(
                          title: str.AppStrings.longTermGoals,
                          minHeight: 110,
                          emptyText: _longtermGoals.isEmpty && longtermDonePending.isEmpty
                              ? str.AppStrings.emptyLongterm
                              : null,
                          children: [
                            ..._longtermGoals.map((t) => Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 4),
                                  child: Text(
                                    t.title,
                                    style: TextStyle(fontSize: 16),
                                  ),
                                )),
                            if (longtermDonePending.isNotEmpty) ...[
                              _doneSeparator(longtermDonePending.length, tasks.isDoneFading),
                              ...longtermDonePending
                                .map((t) => _taskTile(t, null, isDone: true, fading: tasks.isDoneFading)),
                            ],
                          ],
                        ),
                        // ── 明日待办 ──
                        _tomorrowSection(tomorrowTasks, tomorrowDonePending, settings),
                        const SliverToBoxAdapter(child: SizedBox(height: 80)),
                      ],
                  ),
                  ),
                Positioned(
                  right: 36,
                  bottom: 70,
                  child: MicButton(),
                ),
              ],
              ),
            ),
          ),
          if (_selectionMode && _selectedIds.isNotEmpty)
            Container(
              color: AppTheme.of(context).surface,
              padding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    CupertinoButton(
                      child: Text(allOverdueIds.isNotEmpty &&
                              _selectedIds.length == allOverdueIds.length
                          ? '全不选'
                          : '全选'),
                      onPressed: () {
                        setState(() {
                          if (_selectedIds.length == allOverdueIds.length &&
                              allOverdueIds.isNotEmpty) {
                            _selectedIds.clear();
                          } else {
                            _selectedIds.addAll(allOverdueIds);
                          }
                        });
                      },
                    ),
                    CupertinoButton(
                      child: Text('一键移至今天'),
                      onPressed: () async {
                        final t = context.read<TaskProvider>();
                        for (final id in _selectedIds.toList()) {
                          await t.moveToToday(id, today);
                        }
                        _selectedIds.clear();
                        setState(() => _selectionMode = false);
                      },
                    ),
                    CupertinoButton(
                      child: Text('移回日常待办'),
                      onPressed: () async {
                        final t = context.read<TaskProvider>();
                        for (final id in _selectedIds.toList()) {
                          await t.removeFromHomepage(id);
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
    );
  }

  bool _onSlideNotify(SlideCompleteNotification n) {
    if (_selectionMode) return false;
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

  void _refreshLight() {
    final tasks = context.read<TaskProvider>();
    setState(() {
      _lightTasks = tasks.shuffledLightTasks(5);
      _longtermGoals = tasks.shuffledLongtermGoals(3);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshLight();
    final tasks = context.read<TaskProvider>();
    final settings = context.read<SettingsProvider>();
    final tomorrow =
        du.getTomorrowDate(DateTime.now(), settings.dayBoundary);
    final count = tasks.tomorrowTasks(tomorrow).length;
    if (count > 0 && !_tomorrowExpanded) {
      _tomorrowExpanded = true;
    }
  }

  Widget _sectionCard({
    required String title,
    String? emptyText,
    Widget? headerTrailing,
    double minHeight = 80,
    List<Widget> children = const [],
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.of(context).text,
                      ),
                    ),
                  ),
                  if (headerTrailing != null) headerTrailing,
                ],
              ),
            ),
            Container(
              constraints: BoxConstraints(minHeight: minHeight),
              decoration: BoxDecoration(
                color: AppTheme.of(context).sectionCardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: emptyText != null
                  ? Center(
                      child: Text(
                        emptyText,
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .tabLabelTextStyle
                            .copyWith(fontSize: 14),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: children,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionDivider(String label) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
          children: [
            Expanded(
                child: SizedBox(
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            border: Border(
                                top: BorderSide(
                                    color: AppTheme.of(context).separator))))),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label,
                style: CupertinoTheme.of(context)
                    .textTheme
                    .tabLabelTextStyle
                    .copyWith(fontSize: 12),
              ),
            ),
            Expanded(
                child: SizedBox(
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            border: Border(
                                top: BorderSide(
                                    color: AppTheme.of(context).separator))))),
            ),
          ],
        ),
    );
  }

  Widget _doneSeparator(int count, bool isFading) {
    return AnimatedOpacity(
      opacity: isFading ? 0.0 : 1.0,
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
    );
  }

  Widget _taskTile(Task task, Set<String>? overdueIds, {bool isDone = false, bool fading = false}) {
    final isOverdue = overdueIds != null && overdueIds.contains(task.id);
    final selectable = _selectionMode && isOverdue;
    final key = _tileKeys.putIfAbsent(task.id, () => GlobalKey());
    final tp = context.read<TaskProvider>();
    return Container(
      key: key,
      child: TaskListTile(
        key: ValueKey(task.id),
        task: task,
        selectionMode: selectable,
        isSelected: selectable && _selectedIds.contains(task.id),
        slideCompleting: _slideCompleteIds.contains(task.id),
        slideUndoing: _slideUndoIds.contains(task.id),
        isDone: isDone,
        fading: fading,
        onMarkDone: selectable
            ? null
            : () => tp.markDonePending(task.id),
        onUndo: isDone
            ? () => tp.undoDonePending(task.id)
            : null,
        onSelect: selectable
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
      ),
    );
  }

  Widget _tomorrowSection(
      List<Task> tomorrowTasks, List<Task> tomorrowDonePending, SettingsProvider settings) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.of(context).sectionCardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () =>
                    setState(() => _tomorrowExpanded = !_tomorrowExpanded),
                child: Row(
                  children: [
                    Icon(
                      _tomorrowExpanded
                          ? CupertinoIcons.chevron_down
                          : CupertinoIcons.chevron_right,
                      size: 18,
                    ),
                    SizedBox(width: 6),
                    Text(str.AppStrings.tomorrowTodo,
                        style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              if (_tomorrowExpanded) ...[
                if (tomorrowTasks.isEmpty && tomorrowDonePending.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                        str.AppStrings.tomorrowEmpty,
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.of(context).textSecondary)),
                  )
                else
                  ...tomorrowTasks.map((t) => TaskListTile(
                        task: t,
                        onMarkDone: () => context
                            .read<TaskProvider>()
                            .markDonePending(t.id),
                      )),
                  ...tomorrowDonePending.map((t) => TaskListTile(
                        task: t,
                        isDone: true,
                        fading: context.read<TaskProvider>().isDoneFading,
                        onUndo: () => context
                            .read<TaskProvider>()
                            .undoDonePending(t.id),
                      )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
