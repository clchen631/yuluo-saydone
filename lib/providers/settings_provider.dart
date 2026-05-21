import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/database_service.dart';

class SettingsProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  static const _keyApiKey = 'api_key';
  static const _keyModelId = 'model_id';
  static const _keyThinkingEnabled = 'thinking_enabled';
  static const _keyDayBoundary = 'day_boundary';
  static const _keyRemindTime = 'remind_time';
  static const _keyRemindEnabled = 'remind_enabled';
  static const _keyRecycleDays = 'recycle_days';
  static const _keyDevMode = 'dev_mode';
  static const _keySystemPrompt = 'system_prompt';
  static const _keyPoolNames = 'pool_names';
  static const _keyEmptyTexts = 'empty_texts';
  static const _keyAliAccessKeyId = 'ali_access_key_id';
  static const _keyAliAccessKeySecret = 'ali_access_key_secret';
  static const _keyAliAppKey = 'ali_app_key';
  static const _keyAliToken = 'ali_token';
  static const _keyDashScopeApiKey = 'dashscope_api_key';
  static const _keyMoveTomorrowText = 'move_tomorrow_text';
  static const _keyProcessingText = 'processing_text';
  static const _keyCreatedText = 'created_text';
  static const _keyUpdatedText = 'updated_text';

  // Defaults
  String _apiKey = '';
  String _modelId = 'deepseek-v4-flash';
  bool _thinkingEnabled = false;
  int _dayBoundary = 4;
  int _remindHour = 23;
  int _remindMinute = 0;
  bool _remindEnabled = true;
  int _recycleDays = 5;
  bool _devMode = false;
  final Map<String, String> _poolNames = {};
  final Map<String, String> _emptyTexts = {};
  String _systemPrompt = '';
  String _aliAccessKeyId = '';
  String _aliAccessKeySecret = '';
  String _aliAppKey = '';
  String _aliToken = '';
  String _dashScopeApiKey = '';
  String _moveTomorrowText = '明天做这些';
  String _processingText = '处理中...';
  String _createdText = '已创建';
  String _updatedText = '已修改';

  // Getters
  String get apiKey => _apiKey;
  String get modelId => _modelId;
  bool get thinkingEnabled => _thinkingEnabled;
  int get dayBoundary => _dayBoundary;
  int get remindHour => _remindHour;
  int get remindMinute => _remindMinute;
  bool get remindEnabled => _remindEnabled;
  int get recycleDays => _recycleDays;
  bool get devMode => _devMode;
  Map<String, String> get poolNames => _poolNames;
  Map<String, String> get emptyTexts => _emptyTexts;
  String get systemPrompt => _systemPrompt;
  String get aliAccessKeyId => _aliAccessKeyId;
  String get aliAccessKeySecret => _aliAccessKeySecret;
  String get aliAppKey => _aliAppKey;
  String get aliToken => _aliToken;
  String get dashScopeApiKey => _dashScopeApiKey;
  String get moveTomorrowText => _moveTomorrowText.isEmpty ? '明天做这些' : _moveTomorrowText;
  String get processingText => _processingText.isEmpty ? '处理中...' : _processingText;
  String get createdText => _createdText.isEmpty ? '已创建' : _createdText;
  String get updatedText => _updatedText.isEmpty ? '已修改' : _updatedText;

  String poolDisplayName(String poolKey) =>
      _poolNames[poolKey] ?? _defaultPoolName(poolKey);

  String _defaultPoolName(String key) {
    switch (key) {
      case 'daily': return '日常待办';
      case 'light': return '轻任务';
      case 'longterm': return '长期目标';
      default: return key;
    }
  }

  String emptyText(String key) =>
      _emptyTexts[key] ?? _defaultEmptyText(key);

  String _defaultEmptyText(String key) {
    switch (key) {
      case 'daily': return '暂无待办，创建一条吧';
      case 'light': return '轻任务池空空如也，去添加一条吧';
      case 'longterm': return '还没有长期目标，设定一个吧';
      case 'completed': return '暂无已完成任务';
      case 'recycle': return '回收站是空的';
      default: return '';
    }
  }

  Future<void> load() async {
    _apiKey = await _db.getSetting(_keyApiKey) ?? '';
    _modelId = await _db.getSetting(_keyModelId) ?? 'deepseek-v4-flash';
    _thinkingEnabled = await _db.getSetting(_keyThinkingEnabled) == 'true';
    _dayBoundary = int.tryParse(await _db.getSetting(_keyDayBoundary) ?? '') ?? 4;
    _remindEnabled = await _db.getSetting(_keyRemindEnabled) != 'false';
    final remind = (await _db.getSetting(_keyRemindTime) ?? '23:00').split(':');
    _remindHour = int.tryParse(remind[0]) ?? 23;
    _remindMinute = int.tryParse(remind.length > 1 ? remind[1] : '0') ?? 0;
    _recycleDays = int.tryParse(await _db.getSetting(_keyRecycleDays) ?? '') ?? 5;
    _devMode = await _db.getSetting(_keyDevMode) == 'true';
    _systemPrompt = await _db.getSetting(_keySystemPrompt) ?? '';
    _aliAccessKeyId = await _db.getSetting(_keyAliAccessKeyId) ?? '';
    _aliAccessKeySecret = await _db.getSetting(_keyAliAccessKeySecret) ?? '';
    _aliAppKey = await _db.getSetting(_keyAliAppKey) ?? '';
    _aliToken = await _db.getSetting(_keyAliToken) ?? '';
    _dashScopeApiKey = await _db.getSetting(_keyDashScopeApiKey) ?? '';
    _moveTomorrowText = await _db.getSetting(_keyMoveTomorrowText) ?? '明天做这些';
    _processingText = await _db.getSetting(_keyProcessingText) ?? '处理中...';
    _createdText = await _db.getSetting(_keyCreatedText) ?? '已创建';
    _updatedText = await _db.getSetting(_keyUpdatedText) ?? '已修改';
    final poolNamesJson = await _db.getSetting(_keyPoolNames);
    if (poolNamesJson != null && poolNamesJson.isNotEmpty) {
      try {
        _poolNames.addAll(Map<String, String>.from(jsonDecode(poolNamesJson) as Map));
      } catch (_) {}
    }
    final emptyTextsJson = await _db.getSetting(_keyEmptyTexts);
    if (emptyTextsJson != null && emptyTextsJson.isNotEmpty) {
      try {
        _emptyTexts.addAll(Map<String, String>.from(jsonDecode(emptyTextsJson) as Map));
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> setApiKey(String v) async { _apiKey = v; await _db.setSetting(_keyApiKey, v); notifyListeners(); }
  Future<void> setModelId(String v) async { _modelId = v; await _db.setSetting(_keyModelId, v); notifyListeners(); }
  Future<void> setThinkingEnabled(bool v) async { _thinkingEnabled = v; await _db.setSetting(_keyThinkingEnabled, v.toString()); notifyListeners(); }
  Future<void> setDayBoundary(int v) async { _dayBoundary = v; await _db.setSetting(_keyDayBoundary, v.toString()); notifyListeners(); }
  Future<void> setRemindTime(int hour, int minute) async { _remindHour = hour; _remindMinute = minute; await _db.setSetting(_keyRemindTime, '$hour:${minute.toString().padLeft(2, '0')}'); notifyListeners(); }
  Future<void> setRemindEnabled(bool v) async { _remindEnabled = v; await _db.setSetting(_keyRemindEnabled, v.toString()); notifyListeners(); }
  Future<void> setRecycleDays(int v) async { _recycleDays = v; await _db.setSetting(_keyRecycleDays, v.toString()); notifyListeners(); }
  Future<void> setDevMode(bool v) async { _devMode = v; await _db.setSetting(_keyDevMode, v.toString()); notifyListeners(); }
  Future<void> setSystemPrompt(String v) async { _systemPrompt = v; await _db.setSetting(_keySystemPrompt, v); notifyListeners(); }
  Future<void> setPoolName(String key, String name) async { _poolNames[key] = name; await _db.setSetting(_keyPoolNames, jsonEncode(_poolNames)); notifyListeners(); }
  Future<void> setEmptyText(String key, String text) async { _emptyTexts[key] = text; await _db.setSetting(_keyEmptyTexts, jsonEncode(_emptyTexts)); notifyListeners(); }
  Future<void> resetSystemPrompt() async { _systemPrompt = ''; await _db.setSetting(_keySystemPrompt, ''); notifyListeners(); }
  Future<void> setAliAccessKeyId(String v) async { _aliAccessKeyId = v; await _db.setSetting(_keyAliAccessKeyId, v); notifyListeners(); }
  Future<void> setAliAccessKeySecret(String v) async { _aliAccessKeySecret = v; await _db.setSetting(_keyAliAccessKeySecret, v); notifyListeners(); }
  Future<void> setAliAppKey(String v) async { _aliAppKey = v; await _db.setSetting(_keyAliAppKey, v); notifyListeners(); }
  Future<void> setAliToken(String v) async { _aliToken = v; await _db.setSetting(_keyAliToken, v); notifyListeners(); }
  Future<void> setDashScopeApiKey(String v) async { _dashScopeApiKey = v; await _db.setSetting(_keyDashScopeApiKey, v); notifyListeners(); }
  Future<void> setMoveTomorrowText(String v) async { _moveTomorrowText = v; await _db.setSetting(_keyMoveTomorrowText, v); notifyListeners(); }
  Future<void> setProcessingText(String v) async { _processingText = v; await _db.setSetting(_keyProcessingText, v); notifyListeners(); }
  Future<void> setCreatedText(String v) async { _createdText = v; await _db.setSetting(_keyCreatedText, v); notifyListeners(); }
  Future<void> setUpdatedText(String v) async { _updatedText = v; await _db.setSetting(_keyUpdatedText, v); notifyListeners(); }
}
