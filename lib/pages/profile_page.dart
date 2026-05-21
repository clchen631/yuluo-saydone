import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../providers/task_provider.dart';
import '../providers/settings_provider.dart';
import '../models/task.dart';
import '../services/ai_service.dart';
import '../utils/theme.dart';
import '../widgets/task_list_tile.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppTheme.of(context).surface,
        middle: Text('我'),
      ),
      child: SafeArea(
        child: ListView(
          physics: const ClampingScrollPhysics(),
          children: [
            SizedBox(height: 4),
            _row(context, '设置', CupertinoIcons.settings, () {
              Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const SettingsPage()),
              );
            }),
            _row(context, '已完成任务', CupertinoIcons.checkmark_seal, () {
              Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const CompletedPage()),
              );
            }),
            _row(context, '回收站', CupertinoIcons.trash, () {
              Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const RecycleBinPage()),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.of(context).sectionCardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.of(context).primary, size: 24),
              SizedBox(width: 14),
              Expanded(child: Text(title, style: TextStyle(fontSize: 17, color: AppTheme.of(context).text))),
              Icon(CupertinoIcons.chevron_right, color: AppTheme.of(context).textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Settings page ──

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppTheme.of(context).surface,
        middle: Text('设置'),
      ),
      child: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            physics: const ClampingScrollPhysics(),
            children: [
              _section(context, 'API'),
            _inputRow(context, 'API Key', settings.apiKey,
                (v) => settings.setApiKey(v), hint: 'sk-...'),
            _tappableRow(
              context,
              '测试连接',
              () => _testConnection(context, settings.apiKey),
            ),
            _pickerRow(
              context,
              '模型',
              settings.modelId,
              ['deepseek-v4-flash', 'deepseek-v4-pro', 'kimi-k2.6'],
              (v) => settings.setModelId(v),
            ),
            _switchRow(context, '思考模式', settings.thinkingEnabled,
                (v) => settings.setThinkingEnabled(v)),
            _section(context, '语音识别（DashScope）'),
            _inputRow(context, 'API Key', settings.dashScopeApiKey,
                (v) => settings.setDashScopeApiKey(v), hint: 'sk-...'),
            _tappableRow(
              context,
              '测试连接',
              () => _testVoiceConnection(context, settings.dashScopeApiKey),
            ),
            _section(context, '时间'),
            _tappableRow(context, '日分界时间（${settings.dayBoundary}:00）',
                () => _pickHour(context, settings.dayBoundary,
                    (h) => settings.setDayBoundary(h))),
            _switchRow(context, '未完成任务提醒', settings.remindEnabled,
                (v) => settings.setRemindEnabled(v)),
            _tappableRow(
                context,
                '提醒时间（${settings.remindHour}:${settings.remindMinute.toString().padLeft(2, '0')}）',
                () => _pickTime(context, settings.remindHour,
                    settings.remindMinute, (h, m) => settings.setRemindTime(h, m))),
            _tappableRow(context, '回收站保留天数（${settings.recycleDays} 天）',
                () => _pickDays(context, settings.recycleDays,
                    (d) => settings.setRecycleDays(d))),
            _section(context, '数据'),
            _tappableRow(context, '数据导出', () => _exportData(context)),
            _tappableRow(context, '数据导入', () => _importData(context)),
            _section(context, '开发者'),
            _switchRow(context, '开发者模式', settings.devMode,
                (v) => settings.setDevMode(v)),
            if (settings.devMode)
            _tappableRow(context, '自定义池名/文案/提示词', () {
              Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const DevCustomPage()),
              );
            }),
            _section(context, '关于'),
            _tappableRow(context, '关于 语落SayDone', () => _showAbout(context)),
          ],
        ),
      ),
    ),
    );
  }

  void _showAbout(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text('语落SayDone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('版本 v1.0'),
            SizedBox(height: 8),
            Text(
              'AI 驱动的语音/文字输入本地待办应用。\n'
              '纯本地存储，无需注册账号。',
              style: TextStyle(fontSize: 13, color: AppTheme.of(context).textSecondary),
            ),
            SizedBox(height: 8),
            Text(
              '© 2026 语落SayDone',
              style: TextStyle(fontSize: 12, color: AppTheme.of(context).textSecondary),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 6),
      child: Text(title.toUpperCase(),
          style: TextStyle(
              fontSize: 13,
              color: AppTheme.of(context).textSecondary,
              letterSpacing: 0.5)),
    );
  }

  Widget _inputRow(BuildContext context, String label, String value,
      void Function(String) onChanged,
      {String? hint}) {
    final controller = TextEditingController(text: value);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: AppTheme.of(context).textSecondary)),
          SizedBox(height: 4),
          CupertinoTextField(
            controller: controller,
            placeholder: hint,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _tappableRow(BuildContext context, String label, VoidCallback onTap) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 16, color: AppTheme.of(context).text))),
            Icon(CupertinoIcons.chevron_right,
                color: AppTheme.of(context).textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _switchRow(
      BuildContext context, String label, bool value, void Function(bool) onChanged) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 16, color: AppTheme.of(context).text))),
          CupertinoSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _pickerRow(BuildContext context, String label, String current,
      List<String> options, void Function(String) onChanged) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        showCupertinoModalPopup(
          context: context,
          builder: (ctx) => CupertinoActionSheet(
            actions: options
                .map((o) => CupertinoActionSheetAction(
                      onPressed: () {
                        onChanged(o);
                        Navigator.pop(ctx);
                      },
                      child: Text(o),
                    ))
                .toList(),
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消'),
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
                child: Text('$label ($current)',
                        style: TextStyle(fontSize: 16, color: AppTheme.of(context).text))),
            Icon(CupertinoIcons.chevron_right,
                color: AppTheme.of(context).textSecondary),
          ],
        ),
      ),
    );
  }

  void _pickHour(
      BuildContext context, int current, void Function(int) onPicked) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 216,
        color: AppTheme.of(context).background,
        child: CupertinoPicker(
          itemExtent: 32,
          onSelectedItemChanged: (i) => onPicked(i),
          scrollController:
              FixedExtentScrollController(initialItem: current),
          children:
              List.generate(24, (i) => Center(child: Text('$i:00'))),
        ),
      ),
    );
  }

  void _pickTime(BuildContext context, int hour, int minute,
      void Function(int, int) onPicked) {
    int h = hour, m = minute;
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 216,
        color: AppTheme.of(context).background,
        child: Row(
          children: [
            Expanded(
              child: CupertinoPicker(
                itemExtent: 32,
                onSelectedItemChanged: (i) => h = i,
                scrollController: FixedExtentScrollController(initialItem: hour),
                children: List.generate(24, (i) => Center(child: Text('$i'))),
              ),
            ),
            Text(':', style: TextStyle(fontSize: 20)),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 32,
                onSelectedItemChanged: (i) => m = i,
                scrollController:
                    FixedExtentScrollController(initialItem: minute),
                children:
                    List.generate(60, (i) => Center(child: Text(i.toString().padLeft(2, '0')))),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      onPicked(h, m);
    });
  }

  void _pickDays(
      BuildContext context, int current, void Function(int) onPicked) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 216,
        color: AppTheme.of(context).background,
        child: CupertinoPicker(
          itemExtent: 32,
          onSelectedItemChanged: (i) => onPicked(i + 1),
          scrollController:
              FixedExtentScrollController(initialItem: current - 1),
          children: List.generate(30, (i) => Center(child: Text('${i + 1} 天'))),
        ),
      ),
    );
  }

  void _testConnection(BuildContext context, String apiKey) async {
    if (apiKey.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text('提示'),
          content: Text('请先填写 API Key'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: Text('确定'),
            ),
          ],
        ),
      );
      return;
    }
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(),
            SizedBox(width: 16),
            Text('正在测试连接...'),
          ],
        ),
      ),
    );
    final settings = context.read<SettingsProvider>();
    final ai = AiService(
      apiKey: apiKey,
      modelId: settings.modelId,
      thinkingEnabled: settings.thinkingEnabled,
    );
    final ok = await ai.testConnection();
    if (context.mounted) {
      Navigator.pop(context);
    }
    if (context.mounted) {
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: Text(ok ? '连接成功' : '连接失败'),
          content: Text(ok ? 'API Key 有效，可以正常使用 AI 功能' : '无法连接到 API，请检查 Key 和网络'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  void _testVoiceConnection(BuildContext context, String apiKey) async {
    if (apiKey.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          content: Text('请先填写 API Key'),
          actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: Text('确定'))],
        ),
      );
      return;
    }
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        content: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          CupertinoActivityIndicator(), SizedBox(width: 16), Text('正在识别测试语音...'),
        ]),
      ),
    );
    String? result;
    String? errorMsg;
    try {
      final wav = (await rootBundle.load('assets/test_voice.wav')).buffer.asUint8List();
      final b64 = base64Encode(wav);
      final response = await http.post(
        Uri.parse('https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'qwen3-asr-flash',
          'messages': [{'role': 'user', 'content': [{'type': 'input_audio', 'input_audio': {'data': 'data:audio/wav;base64,$b64'}}]}],
          'stream': false,
        }),
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        result = (json['choices'] as List?)?.first?['message']?['content'] as String?;
      } else {
        errorMsg = 'HTTP ${response.statusCode}: ${response.body.length > 200 ? '${response.body.substring(0, 200)}...' : response.body}';
      }
    } catch (e) {
      errorMsg = e.toString();
    }
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) {
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: Text(result != null ? '连接成功' : '连接失败'),
          content: Text(result ?? (errorMsg ?? '未知错误')),
          actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: Text('确定'))],
        ),
      );
    }
  }

  void _exportData(BuildContext context) async {
    try {
      final tasks = context.read<TaskProvider>();
      final data = await tasks.exportAll();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, 'yuluo_saydone_backup.json'));
      await file.writeAsString(jsonStr);
      await Share.shareXFiles([XFile(file.path)], text: '语落SayDone 数据备份');
    } catch (e) {
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: Text('导出失败'),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: Text('确定'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _importData(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.isEmpty) return;
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      if (!data.containsKey('tasks')) {
        if (context.mounted) {
          showCupertinoDialog(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: Text('格式错误'),
              content: Text('所选文件不是有效的语落数据备份'),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('确定'),
                ),
              ],
            ),
          );
        }
        return;
      }
      if (context.mounted) {
        showCupertinoModalPopup(
          context: context,
          builder: (ctx) => CupertinoActionSheet(
            title: Text('导入数据方式'),
            message: Text('选择导入策略'),
            actions: [
              CupertinoActionSheetAction(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await context.read<TaskProvider>().importData(data, false);
                  if (context.mounted) {
                    showCupertinoDialog(
                      context: context,
                      builder: (ctx2) => CupertinoAlertDialog(
                        content: Text('数据已合并导入'),
                        actions: [
                          CupertinoDialogAction(
                            onPressed: () => Navigator.pop(ctx2),
                            child: Text('确定'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                child: Text('合并（保留现有数据）'),
              ),
              CupertinoActionSheetAction(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await context.read<TaskProvider>().importData(data, true);
                  if (context.mounted) {
                    showCupertinoDialog(
                      context: context,
                      builder: (ctx2) => CupertinoAlertDialog(
                        content: Text('数据已替换导入'),
                        actions: [
                          CupertinoDialogAction(
                            onPressed: () => Navigator.pop(ctx2),
                            child: Text('确定'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                child: Text('替换（清除现有数据）'),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消'),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: Text('导入失败'),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: Text('确定'),
              ),
            ],
          ),
        );
      }
    }
  }
}

// ── Developer customization page ──

class DevCustomPage extends StatefulWidget {
  const DevCustomPage({super.key});

  @override
  State<DevCustomPage> createState() => _DevCustomPageState();
}

class _DevCustomPageState extends State<DevCustomPage> {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppTheme.of(context).surface,
        middle: Text('自定义内容'),
      ),
      child: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            physics: const ClampingScrollPhysics(),
            children: [
              _section(context, '池名称'),
            _textRow(
              context,
              '日常待办',
              settings.poolDisplayName('daily'),
              (v) => settings.setPoolName('daily', v),
            ),
            _textRow(
              context,
              '轻任务',
              settings.poolDisplayName('light'),
              (v) => settings.setPoolName('light', v),
            ),
            _textRow(
              context,
              '长期目标',
              settings.poolDisplayName('longterm'),
              (v) => settings.setPoolName('longterm', v),
            ),
            _section(context, '空状态文案'),
            _textRow(
              context,
              '日常待办为空',
              settings.emptyText('daily'),
              (v) => settings.setEmptyText('daily', v),
            ),
            _textRow(
              context,
              '轻任务为空',
              settings.emptyText('light'),
              (v) => settings.setEmptyText('light', v),
            ),
            _textRow(
              context,
              '长期目标为空',
              settings.emptyText('longterm'),
              (v) => settings.setEmptyText('longterm', v),
            ),
            _textRow(
              context,
              '已完成任务为空',
              settings.emptyText('completed'),
              (v) => settings.setEmptyText('completed', v),
            ),
            _textRow(
              context,
              '回收站为空',
              settings.emptyText('recycle'),
              (v) => settings.setEmptyText('recycle', v),
            ),
            _section(context, '按钮文字'),
            _textRow(
              context,
              '"明天做这些"按钮',
              settings.moveTomorrowText,
              (v) => settings.setMoveTomorrowText(v),
            ),
            _section(context, 'Toast 文字'),
            _textRow(
              context,
              '"处理中..."',
              settings.processingText,
              (v) => settings.setProcessingText(v),
            ),
            _textRow(
              context,
              '"已创建"',
              settings.createdText,
              (v) => settings.setCreatedText(v),
            ),
            _textRow(
              context,
              '"已修改"',
              settings.updatedText,
              (v) => settings.setUpdatedText(v),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _section(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 6),
      child: Text(title.toUpperCase(),
          style: TextStyle(
              fontSize: 13,
              color: AppTheme.of(context).textSecondary,
              letterSpacing: 0.5)),
    );
  }

  Widget _textRow(
      BuildContext context, String label, String value, void Function(String) onChanged) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(
                    fontSize: 14, color: AppTheme.of(context).textSecondary)),
          ),
          Expanded(
            child: CupertinoTextField(
              controller: TextEditingController(text: value),
              placeholder: label,
              padding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Completed page ──

class CompletedPage extends StatefulWidget {
  const CompletedPage({super.key});

  @override
  State<CompletedPage> createState() => _CompletedPageState();
}

class _CompletedPageState extends State<CompletedPage> {
  bool _selectionMode = false;
  final _selectedIds = <String>{};
  bool _slideSelecting = false;
  String? _expandedTaskId;
  final _tileKeys = <String, GlobalKey>{};
  bool _sortAscending = false;
  @override
  Widget build(BuildContext context) {
    final tasksRaw = context.watch<TaskProvider>().completedTasks;
    final tasks = _sortAscending
        ? tasksRaw.reversed.toList()
        : tasksRaw;
    final settings = context.watch<SettingsProvider>();

    // 按池分组
    final grouped = <TaskPool, List<Task>>{};
    for (final pool in TaskPool.values) {
      final poolTasks = tasks.where((t) => t.pool == pool).toList();
      if (poolTasks.isNotEmpty) grouped[pool] = poolTasks;
    }

    if (grouped.isEmpty) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          backgroundColor: AppTheme.of(context).surface,
          middle: Text('已完成任务'),
        ),
        child: Center(
          child: Text(settings.emptyText('completed'),
              style: TextStyle(color: AppTheme.of(context).textSecondary)),
        ),
      );
    }

    // 展平列表：每个池 section header + 任务条目
    final flatItems = <_CompItem>[];
    // 按池顺序追加
    for (final pool in TaskPool.values) {
      final poolTasks = grouped[pool];
      if (poolTasks == null || poolTasks.isEmpty) continue;
      flatItems.add(_CompHeader(settings.poolDisplayName(pool.name)));
      for (final t in poolTasks) {
        flatItems.add(_CompTask(t));
      }
    }

    final allTaskCount = flatItems.whereType<_CompTask>().length;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppTheme.of(context).surface,
        leading: GestureDetector(
          onTap: () => setState(() => _sortAscending = !_sortAscending),
          child: Padding(
            padding: EdgeInsets.only(left: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _sortAscending
                      ? CupertinoIcons.sort_up
                      : CupertinoIcons.sort_down,
                  size: 20,
                ),
                Text('时间',
                    style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
        middle: Text('已完成任务'),
        trailing: _selectionMode
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
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: NotificationListener<SlideCompleteNotification>(
                    onNotification: _onSlideNotify,
                    child: ListView.builder(
                      physics: _slideSelecting
                          ? const NeverScrollableScrollPhysics()
                          : const ClampingScrollPhysics(),
                      itemCount: flatItems.length,
                      itemBuilder: (_, i) {
                        final item = flatItems[i];
                        if (item is _CompHeader) {
                          return _sectionHeader(item.title);
                        }
                        final t = (item as _CompTask).task;
                        final key = _tileKeys.putIfAbsent(
                            t.id, () => GlobalKey());
                        return _completedTile(key: key, task: t);
                      },
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                              _selectedIds.length == allTaskCount &&
                                      allTaskCount > 0
                                  ? '全不选'
                                  : '全选'),
                        ),
                        onPressed: () {
                          setState(() {
                            if (_selectedIds.length == allTaskCount &&
                                allTaskCount > 0) {
                              _selectedIds.clear();
                            } else {
                              for (final item in flatItems) {
                                if (item is _CompTask) {
                                  _selectedIds.add(item.task.id);
                                }
                              }
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
                          child: Text('批量撤销',
                              style: TextStyle(color: AppTheme.of(context).destructive)),
                        ),
                        onPressed: () async {
                          final tp = context.read<TaskProvider>();
                          for (final id in _selectedIds.toList()) {
                            await tp.undoComplete(id);
                          }
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
                          child: Text('删除',
                              style: TextStyle(color: AppTheme.of(context).destructive)),
                        ),
                        onPressed: () async {
                          final tp = context.read<TaskProvider>();
                          for (final id in _selectedIds.toList()) {
                            await tp.deleteCompletedTask(id);
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
          ],
        ),
      ),
    );
  }

  bool _onSlideNotify(SlideCompleteNotification n) {
    if (!_selectionMode) return false;
    if (n.isStart) {
      setState(() {
        _slideSelecting = true;
        _selectedIds.add(n.taskId);
      });
      return false;
    }
    if (n.isEnd) {
      setState(() => _slideSelecting = false);
      return false;
    }
    if (!_slideSelecting) return false;
    for (final entry in _tileKeys.entries) {
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final pos = box.localToGlobal(Offset.zero);
      if (pos.dy <= n.globalPosition.dy &&
          n.globalPosition.dy <= pos.dy + box.size.height) {
        if (!_selectedIds.contains(entry.key)) {
          setState(() => _selectedIds.add(entry.key));
        }
      }
    }
    return false;
  }

  Widget _completedTile({required GlobalKey key, required Task task}) {
    final tasks = context.read<TaskProvider>();
    final isExpanded = _expandedTaskId == task.id;
    return Column(
      children: [
        _UndoTile(
          key: key,
          task: task,
          selectionMode: _selectionMode,
          isSelected: _selectedIds.contains(task.id),
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
          onUndo: _selectionMode
              ? null
              : () => tasks.undoComplete(task.id),
          onExpand: _selectionMode
              ? null
              : () {
                  setState(() {
                    _expandedTaskId = isExpanded ? null : task.id;
                  });
                },
        ),
        if (isExpanded) _completedDetail(task, tasks),
      ],
    );
  }

  Widget _completedDetail(Task task, TaskProvider tp) {
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
          if (task.notes != null && task.notes!.isNotEmpty) ...[
            Text('备注：', style: TextStyle(fontSize: 12, color: AppTheme.of(context).textSecondary)),
            SizedBox(height: 4),
            Text(task.notes!, style: TextStyle(fontSize: 14, color: AppTheme.of(context).text)),
            SizedBox(height: 8),
          ],
          if (task.targetDate != null) ...[
            Text('目标日期：${task.targetDate}',
                style: TextStyle(fontSize: 13, color: AppTheme.of(context).textSecondary)),
            SizedBox(height: 4),
          ],
          if (task.ddl != null) ...[
            Text('截止日期：${task.ddl}',
                style: TextStyle(fontSize: 13, color: AppTheme.of(context).textSecondary)),
            SizedBox(height: 4),
          ],
          Text('完成时间：${task.completedAt}',
              style: TextStyle(fontSize: 13, color: AppTheme.of(context).textSecondary)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.of(context).text)),
    );
  }
}

abstract class _CompItem {}
class _CompHeader extends _CompItem {
  final String title;
  _CompHeader(this.title);
}
class _CompTask extends _CompItem {
  final Task task;
  _CompTask(this.task);
}

class _UndoTile extends StatefulWidget {
  final Task task;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onSelect;
  final VoidCallback? onUndo;
  final VoidCallback? onExpand;

  const _UndoTile({
    super.key,
    required this.task,
    required this.selectionMode,
    required this.isSelected,
    this.onSelect,
    this.onUndo,
    this.onExpand,
  });

  @override
  State<_UndoTile> createState() => _UndoTileState();
}

class _UndoTileState extends State<_UndoTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  bool _undoing = false;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: 1.0,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _doUndo() {
    if (_undoing || widget.onUndo == null) return;
    setState(() => _undoing = true);
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        _fadeCtrl.reverse().then((_) {
          if (mounted) widget.onUndo?.call();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: GestureDetector(
        onTap: widget.selectionMode ? widget.onSelect : widget.onExpand,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              widget.selectionMode
                  ? GestureDetector(
                      onTap: widget.onSelect,
                      onVerticalDragStart: widget.selectionMode
                          ? (d) {
                              SlideCompleteNotification(
                                taskId: widget.task.id,
                                globalPosition: d.globalPosition,
                                isStart: true,
                              ).dispatch(context);
                            }
                          : null,
                      onVerticalDragUpdate: widget.selectionMode
                          ? (d) {
                              SlideCompleteNotification(
                                globalPosition: d.globalPosition,
                              ).dispatch(context);
                            }
                          : null,
                      onVerticalDragEnd: widget.selectionMode
                          ? (d) {
                              SlideCompleteNotification(isEnd: true)
                                  .dispatch(context);
                            }
                          : null,
                      behavior: HitTestBehavior.translucent,
                      child: Container(
                        width: 48,
                        height: 44,
                        alignment: Alignment.centerLeft,
                        child: Icon(
                          widget.isSelected
                              ? CupertinoIcons.checkmark_square
                              : CupertinoIcons.square,
                          size: 22,
                          color: AppTheme.of(context).primary,
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: _doUndo,
                      behavior: HitTestBehavior.translucent,
                      child: Container(
                        width: 48,
                        height: 44,
                        alignment: Alignment.centerLeft,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _undoing
                                ? const Color(0x00000000)
                                : AppTheme.of(context).primary,
                            border: Border.all(
                                color: AppTheme.of(context).primary, width: 1.5),
                          ),
                          child: _undoing
                              ? SizedBox()
                              : Icon(
                                  CupertinoIcons.checkmark_alt,
                                  size: 14,
                                  color: AppTheme.of(context).white,
                                ),
                        ),
                      ),
                    ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.task.title,
                  style: TextStyle(
                    fontSize: 16,
                    decoration: TextDecoration.lineThrough,
                    color: AppTheme.of(context).textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Recycle bin page ──

class RecycleBinPage extends StatefulWidget {
  const RecycleBinPage({super.key});

  @override
  State<RecycleBinPage> createState() => _RecycleBinPageState();
}

class _RecycleBinPageState extends State<RecycleBinPage> {
  String? _expandedTaskId;
  bool _selectionMode = false;
  final _selectedIds = <String>{};
  
  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskProvider>().deletedTasks;
    final settings = context.watch<SettingsProvider>();

    // 按池分组（数据库已按 deleted_at DESC 排序，分组后保持）
    final grouped = <TaskPool, List<Task>>{};
    for (final pool in TaskPool.values) {
      final poolTasks = tasks.where((t) => t.pool == pool).toList();
      if (poolTasks.isNotEmpty) grouped[pool] = poolTasks;
    }

    if (grouped.isEmpty) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          backgroundColor: AppTheme.of(context).surface,
          middle: Text('回收站'),
        ),
        child: Center(
          child: Text(settings.emptyText('recycle'),
              style: TextStyle(color: AppTheme.of(context).textSecondary)),
        ),
      );
    }

    // 展平列表
    final flatItems = <_CompItem>[];
    for (final pool in TaskPool.values) {
      final poolTasks = grouped[pool];
      if (poolTasks == null || poolTasks.isEmpty) continue;
      flatItems.add(_CompHeader(settings.poolDisplayName(pool.name)));
      for (final t in poolTasks) {
        flatItems.add(_CompTask(t));
      }
    }
    final allTaskCount = flatItems.whereType<_CompTask>().length;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppTheme.of(context).surface,
        middle: Text('回收站'),
        trailing: _selectionMode
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
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: ListView.builder(
              physics: const ClampingScrollPhysics(),
              itemCount: flatItems.length,
              itemBuilder: (_, i) {
                final item = flatItems[i];
                if (item is _CompHeader) {
                  return Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 6),
                    child: Text(item.title,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.of(context).text)),
                  );
                }
                final t = (item as _CompTask).task;
                final remaining = settings.recycleDays -
                    DateTime.now().difference(t.deletedAt!).inDays;
                final isExpanded = _expandedTaskId == t.id;
                final isSelected = _selectedIds.contains(t.id);
                return Column(
                  children: [
                    GestureDetector(
                      onTap: _selectionMode
                          ? () => setState(() {
                                if (isSelected) {
                                  _selectedIds.remove(t.id);
                                } else {
                                  _selectedIds.add(t.id);
                                }
                              })
                          : () => setState(() {
                                _expandedTaskId =
                                    isExpanded ? null : t.id;
                              }),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        child: Row(
                          children: [
                            if (_selectionMode)
                              Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: Icon(
                                  isSelected
                                      ? CupertinoIcons.checkmark_square
                                      : CupertinoIcons.square,
                                  size: 22,
                                  color: AppTheme.of(context).primary,
                                ),
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.title,
                                      style: TextStyle(
                                          fontSize: 16,
                                          color: AppTheme.of(context).text)),
                                  Text(
                                    '${remaining > 0 ? remaining : 0} 天后自动删除',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.of(context).textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            if (!_selectionMode) ...[
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                child: Text('恢复',
                                    style: TextStyle(
                                        color: AppTheme.of(context).primary,
                                        fontSize: 14)),
                                onPressed: () => context
                                    .read<TaskProvider>()
                                    .restoreTask(t.id),
                              ),
                              SizedBox(width: 8),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                child: Text('删除',
                                    style: TextStyle(
                                        color: AppTheme.of(context).destructive,
                                        fontSize: 14)),
                                onPressed: () => context
                                    .read<TaskProvider>()
                                    .permanentDelete(t.id),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (isExpanded && !_selectionMode)
                      Container(
                        margin: EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.of(context).surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (t.notes != null &&
                                t.notes!.isNotEmpty) ...[
                              Text('备注：',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.of(context).textSecondary)),
                              SizedBox(height: 4),
                              Text(t.notes!,
                                  style: TextStyle(fontSize: 14, color: AppTheme.of(context).text)),
                              SizedBox(height: 8),
                            ],
                            if (t.targetDate != null)
                              Text('目标日期：${t.targetDate}',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.of(context).textSecondary)),
                            if (t.ddl != null)
                              Text('截止日期：${t.ddl}',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.of(context).textSecondary)),
                            Text('原属池：${settings.poolDisplayName(t.pool.name)}',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.of(context).textSecondary)),
                            Text(
                                '删除时间：${t.deletedAt?.toString().substring(0, 16) ?? '—'}',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.of(context).textSecondary)),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
                ),
                if (_selectionMode)
              Container(
                width: 240,
                margin: EdgeInsets.fromLTRB(40, 0, 40, 10),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.of(context).surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                              _selectedIds.length == allTaskCount &&
                                      allTaskCount > 0
                                  ? '全不选'
                                  : '全选'),
                        ),
                        onPressed: () {
                          setState(() {
                            if (_selectedIds.length == allTaskCount &&
                                allTaskCount > 0) {
                              _selectedIds.clear();
                            } else {
                              for (final item in flatItems) {
                                if (item is _CompTask) {
                                  _selectedIds.add(item.task.id);
                                }
                              }
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
                          child: Text('彻底删除',
                              style: TextStyle(color: AppTheme.of(context).destructive)),
                        ),
                        onPressed: () {
                          final tp = context.read<TaskProvider>();
                          for (final id in _selectedIds.toList()) {
                            tp.permanentDelete(id);
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
          ],
        ),
      ),
    );
  }
}
                          