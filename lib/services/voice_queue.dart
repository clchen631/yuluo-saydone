import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';
import '../providers/settings_provider.dart';
import 'ai_service.dart';

enum ProcessResult { created, updated, noOp, fail }

enum ToastStage { processing, done, noOp, fail, fading }

class ToastState {
  final String id;
  final String text;
  final ToastStage stage;
  const ToastState({required this.id, required this.text, required this.stage});
}

/// 语音/文字处理队列 — 单例，LLM 串行化
class VoiceQueue extends ChangeNotifier {
  static final VoiceQueue _instance = VoiceQueue._();
  factory VoiceQueue() => _instance;
  VoiceQueue._();

  final _queue = Queue<_QueueItem>();
  bool _processing = false;

  final _logs = Queue<_LogEntry>();
  static const _maxLogs = 15;
  static const _logTtl = Duration(seconds: 10);
  String? _currentText;

  TaskProvider? _tasks;
  SettingsProvider? _settings;

  final _toasts = <ToastState>[];

  bool get isProcessing => _processing;
  int get queueLength => _queue.length;
  String? get currentProcessing => _currentText;
  List<String> get recentLogs {
    _pruneLogs();
    return _logs.map((e) => e.text).toList();
  }

  List<ToastState> get toasts => List.unmodifiable(_toasts);

  void setProviders(TaskProvider tasks, SettingsProvider settings) {
    _tasks = tasks;
    _settings = settings;
  }

  void enqueue(String text, {TaskPool? pool}) {
    _queue.add(_QueueItem(text: text, pool: pool));
    _addLog('入队: "${text.length > 12 ? '${text.substring(0, 12)}...' : text}" (队列 ${_queue.length})');
    if (!_processing) _processNext();
    notifyListeners();
  }

  Future<void> _processNext() async {
    if (_queue.isEmpty) {
      _processing = false;
      notifyListeners();
      return;
    }
    _processing = true;
    final item = _queue.removeFirst();
    _currentText = item.text;
    _addLog('开始处理: "${item.text.length > 12 ? '${item.text.substring(0, 12)}...' : item.text}"');
    final toastId = item.text;
    _toasts.add(ToastState(id: toastId, text: _processingText(), stage: ToastStage.processing));
    notifyListeners();
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        _addLog('失败: 网络异常');
        _updateToast(toastId, _failText(), ToastStage.fail);
        _currentText = null;
        _processNext();
        return;
      }
      final result = await _doProcess(item.text, item.pool);
      switch (result) {
        case ProcessResult.created:
          _addLog('完成: "${item.text.length > 12 ? '${item.text.substring(0, 12)}...' : item.text}"');
          _updateToast(toastId, _doneText(), ToastStage.done);
        case ProcessResult.updated:
          _addLog('已修改: "${item.text.length > 12 ? '${item.text.substring(0, 12)}...' : item.text}"');
          _updateToast(toastId, _updatedText(), ToastStage.done);
        case ProcessResult.noOp:
          _addLog('未识别到任务内容');
          _updateToast(toastId, '未识别到任务内容', ToastStage.noOp);
        case ProcessResult.fail:
          _addLog('失败');
          _updateToast(toastId, _failText(), ToastStage.fail);
      }
    } on AiException catch (e) {
      _addLog('失败: ${e.message}');
      _updateToast(toastId, _failText(), ToastStage.fail);
    } catch (e) {
      _addLog('失败: ${e.toString().length > 30 ? e.toString().substring(0, 30) : e}');
      _updateToast(toastId, _failText(), ToastStage.fail);
    } finally {
      _currentText = null;
      notifyListeners();
      _processNext();
    }
  }

  void _updateToast(String id, String text, ToastStage stage) {
    final idx = _toasts.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    _toasts[idx] = ToastState(id: id, text: text, stage: stage);
    notifyListeners();
    if (stage == ToastStage.done || stage == ToastStage.noOp || stage == ToastStage.fail) {
      Future.delayed(const Duration(seconds: 2), () {
        final i = _toasts.indexWhere((t) => t.id == id);
        if (i == -1) return;
        _toasts[i] = ToastState(id: id, text: _toasts[i].text, stage: ToastStage.fading);
        notifyListeners();
        Future.delayed(const Duration(milliseconds: 600), () {
          _toasts.removeWhere((t) => t.id == id);
          notifyListeners();
        });
      });
    }
  }

  String _processingText() => _settings?.processingText ?? '处理中...';
  String _doneText() => _settings?.createdText ?? '已创建';
  String _updatedText() => _settings?.updatedText ?? '已修改';
  String _failText() => '失败';

  Future<ProcessResult> _doProcess(String text, TaskPool? pool) async {
    final s = _settings;
    final t = _tasks;
    if (s == null || t == null) return ProcessResult.fail;
    final ai = AiService(
      apiKey: s.apiKey,
      modelId: s.modelId,
      thinkingEnabled: s.thinkingEnabled,
    );
    final results = await ai.parse(
      text,
      dayBoundary: s.dayBoundary,
      customSystemPrompt: s.systemPrompt.isEmpty ? null : s.systemPrompt,
      activeTasks: t.allTasks,
    );
    bool created = false;
    bool updated = false;
    for (final result in results) {
      if (result.isNoOp || result.isGetContext) continue;
      if (result.isDelete && result.hasTaskId) {
        await t.deleteTask(result.taskId!);
        updated = true;
        continue;
      }
      if (result.isMovePool && result.hasTaskId) {
        await t.moveToPool(result.taskId!, result.taskPool);
        updated = true;
        continue;
      }
      if (result.isModify && result.hasTaskId) {
        final current = t.allTasks.where((x) => x.id == result.taskId).firstOrNull;
        final poolChanged = current != null && current.pool != result.taskPool;
        await t.updateTaskFields(
          result.taskId!,
          title: result.title,
          notes: result.notes,
          targetDate: result.targetDate,
          ddl: result.ddl,
          importance: result.taskImportance,
          pool: poolChanged ? result.taskPool : null,
        );
        updated = true;
        continue;
      }
      if (result.isCreate && result.title != null) {
        await t.createTask(
          title: result.title!,
          notes: result.notes,
          targetDate: result.targetDate,
          ddl: result.ddl,
          importance: result.taskImportance,
          pool: pool ?? result.taskPool,
        );
        created = true;
      }
    }
    if (created) return ProcessResult.created;
    if (updated) return ProcessResult.updated;
    return ProcessResult.noOp;
  }

  void _addLog(String msg) {
    if (kDebugMode) debugPrint('[队列] $msg');
    _logs.add(_LogEntry(text: '[${_now()}] $msg', time: DateTime.now()));
    _pruneLogs();
  }

  void _pruneLogs() {
    final cutoff = DateTime.now().subtract(_logTtl);
    _logs.removeWhere((e) => e.time.isBefore(cutoff));
    while (_logs.length > _maxLogs) {
      _logs.removeFirst();
    }
  }

  String _now() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}';
  }
}

class _LogEntry {
  final String text;
  final DateTime time;
  const _LogEntry({required this.text, required this.time});
}

class _QueueItem {
  final String text;
  final TaskPool? pool;
  const _QueueItem({required this.text, this.pool});
}
