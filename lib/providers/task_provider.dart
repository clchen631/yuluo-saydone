import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../services/database_service.dart';

class TaskProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final _uuid = const Uuid();

  List<Task> _allTasks = [];
  List<Task> _completedTasks = [];
  List<Task> _deletedTasks = [];
  final _donePending = <Task>[];
  Timer? _doneTimer;
  bool _doneFading = false;
  bool _loaded = false;

  List<Task> get allTasks => _allTasks;
  List<Task> get completedTasks => _completedTasks;
  List<Task> get deletedTasks => _deletedTasks;
  List<Task> get donePending => _donePending;
  bool get isDoneFading => _doneFading;
  bool get loaded => _loaded;

  /// Active, non-deleted, non-completed tasks by pool
  List<Task> activeInPool(TaskPool pool) {
    final list = _allTasks.where((t) => t.pool == pool).toList();
    _sortTasks(list, pool);
    return list;
  }

  /// Today's target_date tasks from daily pool
  List<Task> todayTasks(String todayDate) {
    final list = _allTasks
        .where((t) => t.pool == TaskPool.daily && t.targetDate == todayDate)
        .toList();
    _sortTasks(list, TaskPool.daily);
    return list;
  }

  /// Past-due tasks from daily pool
  List<Task> overdueTasks(String todayDate) {
    final list = _allTasks
        .where((t) => t.pool == TaskPool.daily &&
            t.targetDate != null &&
            t.targetDate!.isNotEmpty &&
            t.targetDate!.compareTo(todayDate) < 0)
        .toList();
    _sortTasks(list, TaskPool.daily);
    return list;
  }

  /// Tomorrow's target_date tasks
  List<Task> tomorrowTasks(String tomorrowDate) {
    final list = _allTasks
        .where((t) => t.pool == TaskPool.daily && t.targetDate == tomorrowDate)
        .toList();
    _sortTasks(list, TaskPool.daily);
    return list;
  }

  /// Sort tasks by importance, DDL proximity, then created_at
  void _sortTasks(List<Task> tasks, TaskPool pool) {
    if (pool == TaskPool.light) {
      // 轻任务不区分重要性，按创建时间排
      tasks.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return;
    }
    tasks.sort((a, b) {
      // 重要性高的在前
      final impCmp = b.importance.index.compareTo(a.importance.index);
      if (impCmp != 0) return impCmp;
      // 有 DDL 的在前，DDL 近的优先
      if (a.ddl != null && b.ddl != null) {
        return a.ddl!.compareTo(b.ddl!);
      }
      if (a.ddl != null) return -1;
      if (b.ddl != null) return 1;
      // 按创建时间（早的在前）
      return a.createdAt.compareTo(b.createdAt);
    });
  }

  /// Shuffled light tasks (for homepage random 5)
  List<Task> shuffledLightTasks(int count) {
    final list = activeInPool(TaskPool.light).toList();
    list.shuffle();
    return list.take(count).toList();
  }

  /// Shuffled longterm goals (for homepage display 1-3)
  List<Task> shuffledLongtermGoals(int count) {
    final list = activeInPool(TaskPool.longterm).toList();
    list.shuffle();
    return list.take(count).toList();
  }

  /// Load all data from database
  Future<void> loadAll() async {
    _allTasks = await _db.getAllActiveTasks();
    _completedTasks = await _db.getCompletedTasks();
    _deletedTasks = await _db.getDeletedTasks();
    _loaded = true;
    notifyListeners();
  }

  /// Create new task
  Future<Task> createTask({
    required String title,
    String? notes,
    String? targetDate,
    String? ddl,
    TaskImportance importance = TaskImportance.normal,
    TaskPool pool = TaskPool.daily,
  }) async {
    final task = Task(
      id: _uuid.v4(),
      title: title,
      notes: notes,
      createdAt: DateTime.now(),
      targetDate: targetDate,
      ddl: ddl,
      importance: ddl != null ? TaskImportance.important : importance,
      pool: pool,
    );
    await _db.insertTask(task);
    _allTasks.add(task);
    notifyListeners();
    return task;
  }

  /// Complete task
  Future<void> completeTask(String id) async {
    final idx = _allTasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final task = _allTasks[idx].copyWith(
      isCompleted: true,
      completedAt: () => DateTime.now(),
    );
    await _db.updateTask(task);
    _allTasks.removeAt(idx);
    _completedTasks.insert(0, task);
    notifyListeners();
  }

  /// 标记为已完成（进入待淡出状态）— 从活跃列表移除，放入 donePending，启动1s倒计时
  void markDonePending(String id) {
    final idx = _allTasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final task = _allTasks.removeAt(idx).copyWith(
      isCompleted: true,
      completedAt: () => DateTime.now(),
    );
    _donePending.add(task);
    _doneTimer?.cancel();
    _doneFading = false;
    notifyListeners();
    _doneTimer = Timer(const Duration(seconds: 1), _startDoneFade);
  }

  void _startDoneFade() {
    _doneFading = true;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 600), _flushDonePending);
  }

  void _flushDonePending() {
    for (final t in _donePending) {
      _db.updateTask(t);
      _completedTasks.insert(0, t);
    }
    _donePending.clear();
    _doneFading = false;
    notifyListeners();
  }

  /// 撤销：从待淡出列表移回活跃列表
  void undoDonePending(String id) {
    final idx = _donePending.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final task = _donePending.removeAt(idx).copyWith(
      isCompleted: false,
      completedAt: () => null,
    );
    _allTasks.add(task);
    _db.updateTask(task);
    if (_donePending.isEmpty) {
      _doneTimer?.cancel();
      _doneFading = false;
    }
    notifyListeners();
  }

  /// 按池返回 donePending 任务
  List<Task> donePendingFor(TaskPool pool) =>
      _donePending.where((t) => t.pool == pool).toList();

  /// Undo complete (from completed list)
  Future<void> undoComplete(String id) async {
    final idx = _completedTasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final task = _completedTasks[idx].copyWith(
      isCompleted: false,
      completedAt: () => null,
    );
    await _db.updateTask(task);
    _completedTasks.removeAt(idx);
    _allTasks.add(task);
    notifyListeners();
  }

  /// Soft delete → recycle bin
  Future<void> deleteTask(String id) async {
    final idx = _allTasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final task = _allTasks[idx].copyWith(
      isDeleted: true,
      deletedAt: () => DateTime.now(),
    );
    await _db.updateTask(task);
    _allTasks.removeAt(idx);
    _deletedTasks.insert(0, task);
    notifyListeners();
  }

  /// Batch delete (from selection mode)
  Future<void> deleteTasksBatch(List<String> ids) async {
    for (final id in ids) {
      await deleteTask(id);
    }
  }

  /// Restore from recycle bin
  Future<void> restoreTask(String id) async {
    final idx = _deletedTasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final task = _deletedTasks[idx].copyWith(
      isDeleted: false,
      deletedAt: () => null,
    );
    await _db.updateTask(task);
    _deletedTasks.removeAt(idx);
    _allTasks.add(task);
    notifyListeners();
  }

  /// Permanently delete (from recycle bin)
  Future<void> permanentDelete(String id) async {
    await _db.deleteTaskPermanent(id);
    _deletedTasks.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  /// 从已完成任务中软删除到回收站
  Future<void> deleteCompletedTask(String id) async {
    final idx = _completedTasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final task = _completedTasks[idx].copyWith(
      isDeleted: true,
      deletedAt: () => DateTime.now(),
    );
    await _db.updateTask(task);
    _completedTasks.removeAt(idx);
    _deletedTasks.insert(0, task);
    notifyListeners();
  }

  /// Move task to different pool
  Future<void> moveToPool(String id, TaskPool newPool) async {
    final idx = _allTasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final task = _allTasks[idx].copyWith(pool: newPool);
    await _db.updateTask(task);
    _allTasks[idx] = task;
    notifyListeners();
  }

  /// Batch move to pool
  Future<void> moveToPoolBatch(List<String> ids, TaskPool newPool) async {
    for (final id in ids) {
      await moveToPool(id, newPool);
    }
  }

  /// Set target_date to today
  Future<void> moveToToday(String id, String todayDate) async {
    final idx = _allTasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final task = _allTasks[idx].copyWith(targetDate: () => todayDate);
    await _db.updateTask(task);
    _allTasks[idx] = task;
    notifyListeners();
  }

  /// Remove from homepage (清空 target_date)
  Future<void> removeFromHomepage(String id) async {
    final idx = _allTasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final task = _allTasks[idx].copyWith(targetDate: () => null);
    await _db.updateTask(task);
    _allTasks[idx] = task;
    notifyListeners();
  }

  /// Update task fields
  Future<void> updateTaskFields(String id, {
    String? title,
    String? notes,
    String? targetDate,
    String? ddl,
    TaskImportance? importance,
    TaskPool? pool,
  }) async {
    final idx = _allTasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    var task = _allTasks[idx];
    if (title != null) task = task.copyWith(title: title);
    if (notes != null) task = task.copyWith(notes: () => notes);
    if (targetDate != null) {
      task = task.copyWith(targetDate: () => targetDate.isEmpty ? null : targetDate);
    }
    if (ddl != null) {
      task = task.copyWith(
        ddl: () => ddl.isEmpty ? null : ddl,
        importance: TaskImportance.important,
      );
    }
    if (importance != null) task = task.copyWith(importance: importance);
    if (pool != null) {
      task = task.copyWith(pool: pool);
      if (pool == TaskPool.light) {
        task = task.copyWith(
          ddl: () => null,
          importance: TaskImportance.normal,
        );
      }
    }
    await _db.updateTask(task);
    _allTasks[idx] = task;
    notifyListeners();
  }

  /// Auto-clean recycle bin
  Future<void> cleanRecycleBin(int retentionDays) async {
    await _db.cleanRecycleBin(retentionDays);
    _deletedTasks = await _db.getDeletedTasks();
    notifyListeners();
  }

  /// Export all data
  Future<Map<String, dynamic>> exportAll() => _db.exportAll();

  /// Import data
  Future<void> importData(Map<String, dynamic> data, bool replace) async {
    await _db.importData(data, replace);
    _allTasks = await _db.getAllActiveTasks();
    _completedTasks = await _db.getCompletedTasks();
    _deletedTasks = await _db.getDeletedTasks();
    notifyListeners();
  }
}
