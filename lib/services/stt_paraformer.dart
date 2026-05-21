import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'stt_service.dart';

/// 阿里云 DashScope Qwen3-ASR 语音识别
/// OpenAI 兼容接口 — 和 DeepSeek 同一套调用方式
///
/// 用户需在设置页提供 DashScope API Key (sk-...)
class ParaformerSttService extends SttService {
  bool _isRecording = false;
  bool _initialized = false;

  SttPartialCallback? _onPartial;
  SttFinalCallback? _onFinal;

  AudioRecorder? _audioRecorder;
  StreamSubscription<Uint8List>? _audioSub;
  final _audioBuffer = <int>[];

  ParaformerSttService();

  @override
  bool get initialized => _initialized;

  @override
  bool get isRecording => _isRecording;

  @override
  Future<void> init() async {
    if (_initialized) return;
    _audioRecorder = AudioRecorder();
    _initialized = true;
  }

  @override
  Future<bool> startRecording({
    required SttPartialCallback onPartial,
    required SttFinalCallback onFinal,
  }) async {
    if (_isRecording) return false;
    if (!_initialized) await init();

    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;

    _isRecording = true;
    _onPartial = onPartial;
    _onFinal = onFinal;
    _audioBuffer.clear();

    try {
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      );
      final stream = await _audioRecorder!.startStream(config);
      _audioSub = stream.listen(
        (data) => _audioBuffer.addAll(data),
      );
    } catch (_) {
      _isRecording = false;
      return false;
    }
    return true;
  }

  @override
  Future<String?> stopRecording(String apiKey) async {
    if (!_isRecording) return null;
    _isRecording = false;
    _audioSub?.cancel();
    _audioSub = null;

    try {
      await _audioRecorder!.stop();
    } catch (_) {}

    if (_audioBuffer.isEmpty) return '';
    final text = await _recognize(Uint8List.fromList(_audioBuffer), apiKey);
    _audioBuffer.clear();

    if (text != null && text.isNotEmpty) {
      _onFinal?.call(text);
    }
    return text ?? '';
  }

  @override
  void cancelRecording() {
    _isRecording = false;
    _audioSub?.cancel();
    _audioSub = null;
    _audioBuffer.clear();
    try {
      _audioRecorder!.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    cancelRecording();
    _audioRecorder?.dispose();
  }

  // ───── Qwen3-ASR OpenAI 兼容接口 ─────
  static const _endpoint =
      'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';

  Future<String?> _recognize(Uint8List pcm, String apiKey) async {
    if (apiKey.isEmpty || pcm.isEmpty) return null;

    final wav = _pcmToWav(pcm);
    final b64 = base64Encode(wav);
    final dataUri = 'data:audio/wav;base64,$b64';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'qwen3-asr-flash',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'input_audio',
                  'input_audio': {'data': dataUri}
                }
              ]
            }
          ],
          'stream': false,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;
      final msg = choices.first['message'] as Map<String, dynamic>?;
      return msg?['content'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// PCM 16bit 16kHz mono → WAV
  Uint8List _pcmToWav(Uint8List pcm) {
    final byteRate = 16000 * 2;
    final dataSize = pcm.length;
    final fileSize = 44 + dataSize;

    final buf = ByteData(fileSize);
    // RIFF header
    buf.setUint8(0, 0x52);
    buf.setUint8(1, 0x49);
    buf.setUint8(2, 0x46);
    buf.setUint8(3, 0x46);
    buf.setUint32(4, fileSize - 8, Endian.little);
    buf.setUint8(8, 0x57);
    buf.setUint8(9, 0x41);
    buf.setUint8(10, 0x56);
    buf.setUint8(11, 0x45);
    // fmt chunk
    buf.setUint8(12, 0x66);
    buf.setUint8(13, 0x6D);
    buf.setUint8(14, 0x74);
    buf.setUint8(15, 0x20);
    buf.setUint32(16, 16, Endian.little);
    buf.setUint16(20, 1, Endian.little);
    buf.setUint16(22, 1, Endian.little);
    buf.setUint32(24, 16000, Endian.little);
    buf.setUint32(28, byteRate, Endian.little);
    buf.setUint16(32, 2, Endian.little);
    buf.setUint16(34, 16, Endian.little);
    // data chunk
    buf.setUint8(36, 0x64);
    buf.setUint8(37, 0x61);
    buf.setUint8(38, 0x74);
    buf.setUint8(39, 0x61);
    buf.setUint32(40, dataSize, Endian.little);
    for (int i = 0; i < dataSize; i++) {
      buf.setUint8(44 + i, pcm[i]);
    }
    return buf.buffer.asUint8List();
  }
}
