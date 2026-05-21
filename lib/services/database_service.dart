import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';

class DatabaseService {
  static Database? _database;
  static const _dbVersion = 1;
  static const _dbName = 'yuluo_saydone.db';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        target_date TEXT,
        ddl TEXT,
        importance INTEGER NOT NULL DEFAULT 0,
        pool TEXT NOT NULL DEFAULT 'daily',
        is_completed INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1.0 → future versions
  }

  // ===== Task CRUD =====

  Future<void> insertTask(Task task) async {
    final db = await database;
    await db.insert('tasks', task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateTask(Task task) async {
    final db = await database;
    await db.update('tasks', task.toMap(),
        where: 'id = ?', whereArgs: [task.id]);
  }

  Future<void> deleteTaskPermanent(String id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<Task?> getTask(String id) async {
    final db = await database;
    final maps = await db.query('tasks', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Task.fromMap(maps.first);
  }

  /// Active tasks (not completed, not deleted) in given pool
  Future<List<Task>> getActiveTasks(TaskPool pool) async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'pool = ? AND is_completed = 0 AND is_deleted = 0',
      whereArgs: [pool.name],
    );
    return maps.map(Task.fromMap).toList();
  }

  /// All active tasks from all pools
  Future<List<Task>> getAllActiveTasks() async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'is_completed = 0 AND is_deleted = 0',
    );
    return maps.map(Task.fromMap).toList();
  }

  /// Completed tasks, grouped by pool
  Future<List<Task>> getCompletedTasks() async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'is_completed = 1 AND is_deleted = 0',
      orderBy: 'completed_at DESC',
    );
    return maps.map(Task.fromMap).toList();
  }

  /// Deleted tasks (recycle bin), grouped by pool, most recent first
  Future<List<Task>> getDeletedTasks() async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'is_deleted = 1',
      orderBy: 'deleted_at DESC',
    );
    return maps.map(Task.fromMap).toList();
  }

  /// Auto-clean recycle bin: delete tasks older than retentionDays
  Future<void> cleanRecycleBin(int retentionDays) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    await db.delete(
      'tasks',
      where: 'is_deleted = 1 AND deleted_at < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
  }

  /// Export all data as JSON-compatible map
  Future<Map<String, dynamic>> exportAll() async {
    final db = await database;
    final tasks = await db.query('tasks');
    final settings = await db.query('settings');
    return {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'tasks': tasks,
      'settings': settings,
    };
  }

  /// Import data — merge or replace
  Future<void> importData(Map<String, dynamic> data, bool replace) async {
    final db = await database;
    if (replace) {
      await db.delete('tasks');
      await db.delete('settings');
    }
    for (final t in (data['tasks'] as List)) {
      try {
        await db.insert('tasks', t as Map<String, dynamic>,
            conflictAlgorithm: ConflictAlgorithm.ignore);
      } catch (_) {}
    }
    for (final s in (data['settings'] as List)) {
      try {
        await db.insert('settings', s as Map<String, dynamic>,
            conflictAlgorithm:
                replace ? ConflictAlgorithm.replace : ConflictAlgorithm.ignore);
      } catch (_) {}
    }
  }

  // ===== Settings =====

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps =
        await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }
}
