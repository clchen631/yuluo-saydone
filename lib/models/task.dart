enum TaskPool { daily, light, longterm }

enum TaskImportance { normal, important }

class Task {
  final String id;
  final String title;
  final String? notes;
  final DateTime createdAt;
  final String? targetDate;
  final String? ddl;
  final TaskImportance importance;
  final TaskPool pool;
  final bool isCompleted;
  final DateTime? completedAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  Task({
    required this.id,
    required this.title,
    this.notes,
    required this.createdAt,
    this.targetDate,
    this.ddl,
    this.importance = TaskImportance.normal,
    this.pool = TaskPool.daily,
    this.isCompleted = false,
    this.completedAt,
    this.isDeleted = false,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'target_date': targetDate,
      'ddl': ddl,
      'importance': importance.index,
      'pool': pool.name,
      'is_completed': isCompleted ? 1 : 0,
      'completed_at': completedAt?.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      targetDate: map['target_date'] as String?,
      ddl: map['ddl'] as String?,
      importance: TaskImportance.values[map['importance'] as int],
      pool: TaskPool.values.byName(map['pool'] as String),
      isCompleted: (map['is_completed'] as int) == 1,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      isDeleted: (map['is_deleted'] as int) == 1,
      deletedAt: map['deleted_at'] != null
          ? DateTime.parse(map['deleted_at'] as String)
          : null,
    );
  }

  Task copyWith({
    String? id,
    String? title,
    String? Function()? notes,
    DateTime? createdAt,
    String? Function()? targetDate,
    String? Function()? ddl,
    TaskImportance? importance,
    TaskPool? pool,
    bool? isCompleted,
    DateTime? Function()? completedAt,
    bool? isDeleted,
    DateTime? Function()? deletedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes != null ? notes() : this.notes,
      createdAt: createdAt ?? this.createdAt,
      targetDate: targetDate != null ? targetDate() : this.targetDate,
      ddl: ddl != null ? ddl() : this.ddl,
      importance: importance ?? this.importance,
      pool: pool ?? this.pool,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt != null ? completedAt() : this.completedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
    );
  }
}
