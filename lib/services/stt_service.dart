import 'dart:async';

typedef SttPartialCallback = void Function(String text);
typedef SttFinalCallback = void Function(String text);

/// STT 语音识别抽象接口
/// 应用代码只依赖此接口，不关心底层是 Sherpa-ONNX 还是云端 API
abstract class SttService {
  bool get initialized;

  Future<void> init();

  Future<bool> startRecording({
    required SttPartialCallback onPartial,
    required SttFinalCallback onFinal,
  });

  /// 正常结束录音，返回最终识别文字
  Future<String?> stopRecording(String apiKey);

  /// 取消录音，丢弃所有中间结果
  void cancelRecording();

  bool get isRecording;

  void dispose();
}
