import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/task.dart';
import '../utils/date_utils.dart' as app_date_utils;

class AiException implements Exception {
  final String message;
  final String? detail;
  const AiException(this.message, {this.detail});
  @override
  String toString() => 'AiException: $message${detail != null ? ' ($detail)' : ''}';
}

class ProcessTaskInput {
  final String action;
  final String? taskId;
  final String? title;
  final String? notes;
  final String? targetDate;
  final String? ddl;
  final String importance;
  final String pool;

  const ProcessTaskInput({
    this.action = 'create',
    this.taskId,
    this.title,
    this.notes,
    this.targetDate,
    this.ddl,
    this.importance = 'normal',
    this.pool = 'daily',
  });

  factory ProcessTaskInput.fromJson(Map<String, dynamic> json) {
    return ProcessTaskInput(
      action: json['action'] as String? ?? 'create',
      taskId: json['task_id'] as String?,
      title: json['title'] as String?,
      notes: json['notes'] as String?,
      targetDate: json['target_date'] as String?,
      ddl: json['ddl'] as String?,
      importance: json['importance'] as String? ?? 'normal',
      pool: json['pool'] as String? ?? 'daily',
    );
  }

  Map<String, dynamic> toJson() => {
        'action': action,
        if (taskId != null) 'task_id': taskId,
        if (title != null) 'title': title,
        if (notes != null) 'notes': notes,
        if (targetDate != null) 'target_date': targetDate,
        if (ddl != null) 'ddl': ddl,
        'importance': importance,
        'pool': pool,
      };

  bool get isNoOp => action == 'no_op';
  bool get isGetContext => action == 'get_context';
  bool get isCreate => action == 'create' || action.isEmpty;
  bool get isDelete => action == 'delete';
  bool get isMovePool => action == 'move_pool';
  bool get isModify => action == 'modify';
  bool get hasTaskId => taskId != null && taskId!.isNotEmpty;

  TaskPool get taskPool => TaskPool.values.byName(pool);
  TaskImportance get taskImportance =>
      TaskImportance.values.byName(importance == 'important' ? 'important' : 'normal');
}

class AiService {
  final String apiKey;
  final String modelId;
  final bool thinkingEnabled;
  final http.Client _client;
  final Connectivity _connectivity;

  AiService({
    required this.apiKey,
    required this.modelId,
    this.thinkingEnabled = false,
    http.Client? client,
    Connectivity? connectivity,
  })  : _client = client ?? http.Client(),
        _connectivity = connectivity ?? Connectivity();

  String get _baseUrl {
    if (modelId.startsWith('deepseek')) {
      return 'https://api.deepseek.com';
    }
    if (modelId.startsWith('kimi')) {
      return 'https://api.moonshot.cn/v1';
    }
    return 'https://api.deepseek.com';
  }

  static String buildDefaultSystemPrompt({
    required String todayDate,
    required String tomorrowDate,
    required String dayAfterTomorrowDate,
    String? injectedContext,
  }) {
    final contextSection = injectedContext != null && injectedContext.isNotEmpty
        ? '\n## 当前上下文\n$injectedContext\n'
        : '';
    return '''
## 日期对照（日分界凌晨4:00）
- 应用今天：$todayDate
- 应用明天：$tomorrowDate
- 应用后天：$dayAfterTomorrowDate

$contextSection
## 参数含义

| 参数 | 可选值 | 说明 |
|------|--------|------|
| title | 文本 | 任务标题。从用户输入中提取核心要做的事。 |
| target_date | YYYY-MM-DD | **计划做这件事的日期**。任务到这天出现在首页今日待办。用户表达了"哪天去做"（如"明天买""今天做"）→填target_date。将相对日期转为绝对日期。用户只说一个事件日期但没有表达那天去做（如"5月X号要考"）→不填target_date，填ddl。 |
| ddl | YYYY-MM-DD | **截止日期或事件日期**。仅影响排序优先级和重要性标记，不会让任务出现在首页。有 DDL 自动标 important。用户表达"X号之前""X号要XXX（考试/提交/截止等，非亲身去做）"→填ddl。将相对日期转为绝对日期。未提及则不填。 |
| importance | "normal" / "important" | 有 DDL→important。用户说重要/优先/紧急→important。其余→normal。 |
| pool | "daily" / "light" / "longterm" | 任务归属。见下方规则。默认 daily。 |
| notes | 文本 | 除标题、日期、归属外用户提到的其他补充信息。未提及则不填。 |
| action | "create" / "delete" / "move_pool" / "no_op" | 操作类型。未指定则默认 create。有 task_id 时根据用户意图填。 |
| task_id | 文本 | 仅当上下文中有 current_task 且用户明确在说该任务时填写。 |

## 规则

### 多任务拆分与混合操作
一条语音可能包含**创建新任务 + 修改已有任务 + 删除任务**等多种操作。对同一任务做多个修改（如清目标日期+改ddl+移池）要合并为一次 modify。

示例：
"诶那个，看书的那个任务，目标日期删了吧，然后呢ddl改成五月三十号。啊还有C++作业明天做一下。对了买纸巾删了吧。嗯...再来一个，轻任务加今天买垃圾袋的。就这些。"
→ 先调 get_task_context() 拿到列表，然后返回 4 个 tool_call：
  tool_call 1: process_task_input(action="modify", task_id="看书的id", target_date="", ddl="2026-05-30")  ← 同一任务多个修改合并为一次 modify
  tool_call 2: process_task_input(action="modify", task_id="C++作业的id", target_date="2026-05-17")
  tool_call 3: process_task_input(action="delete", task_id="买纸巾的id")
  tool_call 4: process_task_input(action="create", title="买垃圾袋", pool="light", target_date="2026-05-16")  ← 创建新任务无需 task_id

### 归属池
检测用户是否表达了归属意图（自然语义理解，不依赖特定关键词）：
- 表达了随手做/有空再说/不重要/碎片时间等含义 → pool = "light"
- 表达了长期/目标/长远规划等含义 → pool = "longterm"
- 未表达任何归属意图 → pool = "daily"

### 日期换算
参考上方「应用今天/明天/后天」的绝对日期，将用户说的相对日期转为 YYYY-MM-DD。"今天""今晚""今儿"等 → 应用今天；"明天""明日""明早""明晚"等 → 应用明天；"后天" → 应用后天。其他如"下周三""这周末"等，以应用今天为基准推算。

### 重要：target_date 与 ddl 的区分
当用户提到一个日期时，判断用户是"打算那天去做"还是"那天有个事件/截止"：
- **填 target_date**：用户表达了在那天亲身去做（如"明天买纸巾""今天做家务""后天取快递"）
- **填 ddl**：用户只说了事件的日期，没有说那天去做（如"5月23号考C++""下周三之前背完单词""这周末交PPT"）
判断标准：如果任务是你**亲手在那天执行**的行为→target_date；如果是**外部事件在那天发生/那天之前必须完成**→ddl。

### 重要性
- 有 ddl → 自动 importance = "important"
- 用户说重要/优先/紧急/尽快等 → importance = "important"
- 其余 → importance = "normal"

### 修改已有任务
当用户要求修改/删除/移动现有任务时：
1. 如果没有任务上下文 → 调用 get_task_context() 获取所有活跃任务
2. 根据任务列表匹配用户指代的任务，获取 task_id
3. 调用 process_task_input 执行操作（action="modify"/"delete"/"move_pool"，填入 task_id）
4. modify 时只填需要修改的字段，其余不填。**移到不同池时填入新的 pool 值即可，不需要单独调 move_pool**
5. 对同一个任务做多个修改（如清目标日期+改ddl+移池）→ 一次 modify 全部填入

### 轻任务池参数限制
轻任务池不需要DDL和重要性。当任务在轻任务池时：
- 不填 ddl 字段
- importance 始终为 normal
- target_date 可选保留
用户输入与创建/修改任务无关（闲聊、问候、天气等）→ action = "no_op"

## 示例

明天买纸巾
→ title="买纸巾", target_date="2026-05-15", pool="daily", importance="normal"

后天取快递
→ title="取快递", target_date="2026-05-16", pool="daily", importance="normal"

顺手买纸巾
→ title="买纸巾", pool="light", importance="normal"

有空的时候查一下手机价格
→ title="查一下手机价格", pool="light", importance="normal"

周五前写完报告很重要
→ title="写完报告", ddl="2026-05-16", importance="important", pool="daily"

这周末交PPT，优先做
→ title="交PPT", target_date="2026-05-17", importance="important", pool="daily"

下周三之前背完单词
→ title="背完单词", ddl="2026-05-20", pool="daily", importance="important"

下周五前背完单词
→ title="背完单词", ddl="2026-05-22", pool="daily", importance="important"

我5月23号要考C++
→ title="考C++", ddl="2026-05-23", importance="important", pool="daily"

5月20号交论文
→ title="交论文", ddl="2026-05-20", importance="important", pool="daily"

长期目标学会单片机
→ title="学会单片机", pool="longterm", importance="normal"

长远规划健身三个月
→ title="健身三个月", pool="longterm", importance="normal"

买纸巾，备注要用维达的
→ title="买纸巾", notes="要用维达的", pool="daily", importance="normal"

明天交作业，用PDF格式
→ title="交作业", target_date="2026-05-15", notes="用PDF格式", pool="daily", importance="normal"

把买纸巾放到长期目标里
→ title="买纸巾", pool="longterm", importance="normal"

今天写作业、做开发、写预习报告
→ 3 个 tool_call，title 分别为 "写作业" / "做开发" / "写预习报告"，target_date 为今天日期

今天天气怎么样
→ action="no_op"

你好
→ action="no_op"

嗯
→ action="no_op"
''';
  }

  List<Map<String, dynamic>> _buildTools() {
    return [
      {
        'type': 'function',
        'function': {
          'name': 'process_task_input',
          'description': '创建/修改/删除/移动任务。仅当拥有任务上下文（已通过get_task_context获取）或明确创建新任务时调用。修改已有任务时必须填入task_id',
          'parameters': {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': ['create', 'delete', 'move_pool', 'modify', 'no_op'],
                'description': '操作类型。create=创建新任务, delete=删除任务, move_pool=移动任务到其他池, modify=修改任务字段, no_op=无操作',
              },
              'task_id': {
                'type': 'string',
                'description': '要修改的任务ID。delete/move_pool/modify时必填，从get_task_context返回的列表中获取',
              },
              'title': {
                'type': 'string',
                'description': '任务标题',
              },
              'notes': {
                'type': 'string',
                'description': '备注补充信息',
              },
              'target_date': {
                'type': 'string',
                'description': '任务展示在首页的日期，YYYY-MM-DD格式。将相对日期转为绝对日期',
              },
              'ddl': {
                'type': 'string',
                'description': '截止日期，YYYY-MM-DD格式。仅影响排序优先级',
              },
              'importance': {
                'type': 'string',
                'enum': ['normal', 'important'],
                'description': '重要性。有ddl时自动important',
              },
              'pool': {
                'type': 'string',
                'enum': ['daily', 'light', 'longterm'],
                'description': '任务归属池。默认daily',
              },
            },
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'get_task_context',
          'description': '获取当前所有活跃任务列表。当用户要求修改/删除/移动某个已有任务但无法确定task_id时，必须先调用此函数获取任务列表，再调用process_task_input操作',
          'parameters': {
            'type': 'object',
            'properties': {},
          },
        },
      },
    ];
  }

  Map<String, dynamic> _buildRequestBody(List<Map<String, dynamic>> messages) {
    final body = <String, dynamic>{
      'model': modelId,
      'messages': messages,
      'tools': _buildTools(),
      'tool_choice': 'auto',
      'stream': false,
    };

    if (thinkingEnabled) {
      body['thinking'] = {'type': 'enabled'};
    } else {
      body['thinking'] = {'type': 'disabled'};
    }

    if (modelId.startsWith('kimi')) {
      body['temperature'] = 1.0;
      body['max_tokens'] = 16000;
    }

    return body;
  }

  Future<Map<String, dynamic>> _sendRequest(Map<String, dynamic> body) async {
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw const AiException('当前未联网');
    }

    final url = Uri.parse('$_baseUrl/chat/completions');
    try {
      final response = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      String errorMsg = '请求失败 (${response.statusCode})';
      try {
        final errBody = jsonDecode(response.body) as Map<String, dynamic>;
        if (errBody.containsKey('error')) {
          final err = errBody['error'];
          if (err is Map && err.containsKey('message')) {
            errorMsg = err['message'] as String;
          } else if (err is String) {
            errorMsg = err;
          }
        }
      } catch (_) {}

      if (response.statusCode == 401) {
        throw AiException('API Key 无效', detail: errorMsg);
      }
      throw AiException(errorMsg);
    } on AiException {
      rethrow;
    } on http.ClientException catch (e) {
      throw AiException('网络连接失败', detail: e.message);
    } catch (e) {
      if (e is AiException) rethrow;
      throw AiException('请求超时或网络异常', detail: e.toString());
    }
  }

  List<ProcessTaskInput> _extractResults(Map<String, dynamic> response) {
    final choices = response['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw const AiException('AI 未返回有效结果');
    }
    final message = choices.first['message'] as Map<String, dynamic>?;
    if (message == null) {
      throw const AiException('AI 未返回有效消息');
    }
    final toolCalls = message['tool_calls'] as List?;
    if (toolCalls == null || toolCalls.isEmpty) {
      return [const ProcessTaskInput(action: 'no_op')];
    }
    final results = <ProcessTaskInput>[];
    for (final tc in toolCalls) {
      final toolCall = tc as Map<String, dynamic>;
      final function = toolCall['function'] as Map<String, dynamic>?;
      if (function == null) continue;
      final name = function['name'] as String?;
      final argumentsRaw = function['arguments'];
      if (argumentsRaw == null) continue;
      Map<String, dynamic> args;
      if (argumentsRaw is String) {
        try { args = jsonDecode(argumentsRaw) as Map<String, dynamic>; } catch (_) { continue; }
      } else if (argumentsRaw is Map<String, dynamic>) {
        args = argumentsRaw;
      } else { continue; }
      if (name == 'get_task_context') { results.add(const ProcessTaskInput(action: 'get_context')); continue; }
      if (name != 'process_task_input') continue;
      final input = ProcessTaskInput.fromJson(args);
      if (input.isCreate) { final t = input.title?.trim(); if (t == null || t.isEmpty) continue; }
      results.add(input);
    }
    if (results.isEmpty) throw const AiException('未识别到任务内容');
    return results;
  }

  Future<List<ProcessTaskInput>> parse(
    String userText, {
    String? currentTaskId,
    Task? lastCreatedTask,
    String? customSystemPrompt,
    int dayBoundary = 4,
    List<Task>? activeTasks,
  }) async {
    final trimText = userText.trim();
    if (trimText.isEmpty) throw const AiException('未识别到内容');
    if (apiKey.isEmpty) throw const AiException('请先配置 API Key');

    final now = DateTime.now();
    final todayDate = app_date_utils.getTodayDate(now, dayBoundary);
    final tomorrowDate = app_date_utils.getTomorrowDate(now, dayBoundary);
    final dayAfter = app_date_utils.getDayAfterTomorrowDate(now, dayBoundary);

    String injectedContext = '';
    if (currentTaskId != null && currentTaskId.isNotEmpty) {
      injectedContext += '\ncurrent_task: {"id": "$currentTaskId"}';
    }
    if (lastCreatedTask != null) {
      injectedContext += '\nlast_created_task: {"id": "${lastCreatedTask.id}", "title": "${lastCreatedTask.title}"}';
    }

    final systemPrompt = customSystemPrompt != null && customSystemPrompt.isNotEmpty
        ? '$customSystemPrompt\n\n## 日期对照\n应用今天：$todayDate\n应用明天：$tomorrowDate\n应用后天：$dayAfter\n$injectedContext'
        : buildDefaultSystemPrompt(
            todayDate: todayDate, tomorrowDate: tomorrowDate,
            dayAfterTomorrowDate: dayAfter, injectedContext: injectedContext.trim());

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': trimText},
    ];

    for (int round = 0; round < 3; round++) {
      final body = _buildRequestBody(messages);
      final response = await _sendRequest(body);
      final results = _extractResults(response);

      final needsContext = results.any((r) => r.isGetContext);
      if (needsContext && activeTasks != null && activeTasks.isNotEmpty) {
        final message = (response['choices'] as List).first['message'] as Map<String, dynamic>;
        final assistantMsg = <String, dynamic>{
          'role': 'assistant',
          'content': message['content'],
          'tool_calls': message['tool_calls'],
        };
        if (message['reasoning_content'] != null) {
          assistantMsg['reasoning_content'] = message['reasoning_content'];
        }
        messages.add(assistantMsg);
        messages.add({
          'role': 'tool',
          'tool_call_id': (message['tool_calls'] as List).first['id'],
          'content': buildActiveTasksContext(activeTasks),
        });
        continue;
      }
      return results;
    }
    throw const AiException('未识别到任务内容');
  }

  static String buildActiveTasksContext(List<Task> tasks) {
    if (tasks.isEmpty) return '当前没有活跃任务。';
    final list = tasks.map((t) {
      final parts = <String>[];
      parts.add('"id":"${t.id}"');
      parts.add('"title":"${t.title.replaceAll('"', '\\"')}"');
      parts.add('"pool":"${t.pool.name}"');
      if (t.targetDate != null) parts.add('"target_date":"${t.targetDate}"');
      if (t.ddl != null) parts.add('"ddl":"${t.ddl}"');
      parts.add('"importance":"${t.importance.name}"');
      if (t.notes != null && t.notes!.isNotEmpty) {
        final short = t.notes!.length > 30 ? '${t.notes!.substring(0, 30)}...' : t.notes!;
        parts.add('"notes":"${short.replaceAll('"', '\\"')}"');
      }
      return '{${parts.join(',')}}';
    }).join(',\n');
    return '以下是当前所有活跃任务：\n[\n$list\n]';
  }

  Future<bool> testConnection() async {
    if (apiKey.isEmpty) return false;
    try {
      final requestBody = _buildRequestBody([
        {'role': 'system', 'content': buildDefaultSystemPrompt(
          todayDate: app_date_utils.getTodayDate(DateTime.now(), 4),
          tomorrowDate: app_date_utils.getTomorrowDate(DateTime.now(), 4),
          dayAfterTomorrowDate: app_date_utils.getDayAfterTomorrowDate(DateTime.now(), 4),
        )},
        {'role': 'user', 'content': '你好'},
      ]);
      final response = await _sendRequest(requestBody);
      final choices = response['choices'] as List?;
      return choices != null && choices.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _client.close();
  }
}
