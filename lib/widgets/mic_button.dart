import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../providers/settings_provider.dart';
import '../services/stt_service.dart';
import '../services/stt_paraformer.dart';
import '../services/voice_queue.dart';
import '../utils/theme.dart';
import '../utils/strings.dart' as str;

class MicButton extends StatefulWidget {
  final TaskPool? defaultPool;
  final SttService? sttService;
  const MicButton({super.key, this.defaultPool, this.sttService});

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with TickerProviderStateMixin {
  final _buttonKey = GlobalKey();
  late SttService _stt;
  OverlayEntry? _voiceOverlay;

  bool _voiceActive = false;
  String _sttPartialText = '';
  TaskPool? _voicePool;
  int _highlightedDir = -1;
  bool _buttonScaleUp = false;

  late AnimationController _popCtrl;
  late Animation<double> _dotTopAnim;
  late Animation<double> _dotLeftAnim;
  late Animation<double> _dotTopLeftAnim;
  late AnimationController _cancelCtrl;
  Offset? _dotsCenter;
  late AnimationController _rippleCtrl;

  static const _dirUp = 0;
  static const _dirLeft = 1;
  static const _dirUpLeft = 2;
  static const _dirDown = 3;

  @override
  void initState() {
    super.initState();
    _stt = widget.sttService ?? ParaformerSttService();
    _popCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _dotTopAnim = CurvedAnimation(
      parent: _popCtrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
    );
    _dotTopLeftAnim = CurvedAnimation(
      parent: _popCtrl,
      curve: const Interval(0.15, 0.65, curve: Curves.easeOutBack),
    );
    _dotLeftAnim = CurvedAnimation(
      parent: _popCtrl,
      curve: const Interval(0.24, 0.78, curve: Curves.easeOutBack),
    );
    _cancelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _popCtrl.dispose();
    _cancelCtrl.dispose();
    _rippleCtrl.dispose();
    _dismissOverlay();
    super.dispose();
  }

  void _dismissOverlay() {
    _voiceOverlay?.remove();
    _voiceOverlay = null;
  }

  Offset? _buttonCenter() {
    final ctx = _buttonKey.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final pos = box.localToGlobal(Offset.zero);
    return Offset(pos.dx + box.size.width / 2, pos.dy + box.size.height / 2);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _buttonScaleUp ? 1.25 : 1.0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.elasticOut,
      child: GestureDetector(
        onTap: _onTap,
        onLongPressStart: _onLongPressStart,
        onLongPressMoveUpdate: _onLongPressMove,
        onLongPressEnd: _onLongPressEnd,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (_voiceActive)
              Positioned.fill(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _rippleCtrl,
                    builder: (_, _) => CustomPaint(
                       painter: _RipplePainter(_rippleCtrl.value, AppTheme.of(context).primary),
                      size: const Size(80, 80),
                    ),
                  ),
                ),
              ),
            Container(
              key: _buttonKey,
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.of(context).primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.of(context).primary.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                CupertinoIcons.mic_fill,
                color: AppTheme.of(context).white,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTap() async {
    if (_voiceActive) return;
    final settings = context.read<SettingsProvider>();
    if (settings.apiKey.isEmpty) {
      _showHint('请先配置 API Key');
      return;
    }
    final result = await Connectivity().checkConnectivity();
    if (!mounted) return;
    if (result.contains(ConnectivityResult.none)) {
      _showHint(str.AppStrings.networkOffline);
      return;
    }
    _showTextInput();
  }

  void _onLongPressStart(LongPressStartDetails details) {
    final settings = context.read<SettingsProvider>();
    if (settings.apiKey.isEmpty) {
      _showHint('请先配置 API Key');
      return;
    }
    if (settings.dashScopeApiKey.isEmpty) {
      _showHint('请先配置语音识别 API Key（设置 → 语音识别）');
      return;
    }
    final center = _buttonCenter();
    if (center == null) return;
    _dotsCenter = center;
    setState(() {
      _voiceActive = true;
      _buttonScaleUp = true;
      _sttPartialText = '';
      _voicePool = null;
      _highlightedDir = -1;
    });
    _popCtrl.forward(from: 0);
    _cancelCtrl.forward();
    _rippleCtrl.reset();
    _rippleCtrl.repeat();
    _showVoiceOverlay();
    _startRecordingAsync();
  }

  Future<void> _startRecordingAsync() async {
    final result = await Connectivity().checkConnectivity();
    if (!mounted) {
      _stt.cancelRecording();
      return;
    }
    if (result.contains(ConnectivityResult.none)) {
      _showHint(str.AppStrings.networkOffline);
      _cancelVoice();
      return;
    }
    final ok = await _stt.startRecording(
      onPartial: (text) {
        if (mounted) setState(() => _sttPartialText = text);
      },
      onFinal: (_) {},
    );
    if (!mounted) return;
    if (!ok) {
      _showHint('录音启动失败，请检查麦克风权限');
      _cancelVoice();
    }
  }

  void _cancelVoice() {
    setState(() {
      _voiceActive = false;
      _buttonScaleUp = false;
    });
    _popCtrl.reverse();
    _cancelCtrl.reverse();
    _rippleCtrl.stop();
    Future.delayed(const Duration(milliseconds: 200), _dismissOverlay);
  }

  void _onLongPressMove(LongPressMoveUpdateDetails details) {
    final center = _dotsCenter;
    if (center == null) return;
    final dx = details.globalPosition.dx - center.dx;
    final dy = details.globalPosition.dy - center.dy;
    const r = 100.0;
    const d = 80.0;
    const hit = 48.0;
    final hit2 = hit * hit;
    int dir = -1;
    if (_d2(dx, dy + r) < hit2) {
      dir = _dirUp;
    } else if (_d2(dx + r * 0.707, dy + r * 0.707) < hit2) {
      dir = _dirUpLeft;
    } else if (_d2(dx + r, dy) < hit2) {
      dir = _dirLeft;
    } else if (dy > d - hit && dx.abs() < hit) {
      dir = _dirDown;
    }
    if (dir != _highlightedDir) {
      setState(() => _highlightedDir = dir);
      _voiceOverlay?.markNeedsBuild();
    }
  }

  double _d2(double x, double y) => x * x + y * y;

  void _onLongPressEnd(LongPressEndDetails details) async {
    _dotsCenter = null;
    _popCtrl.reverse();
    _cancelCtrl.reverse();
    _rippleCtrl.stop();
    if (!_voiceActive) return;
    final settings = context.read<SettingsProvider>();
    if (_highlightedDir == _dirDown) {
      _stt.cancelRecording();
    } else {
      final recogText = await _stt.stopRecording(settings.dashScopeApiKey);
      if (recogText != null && recogText.isNotEmpty) {
        _sttPartialText = recogText;
      }
    }
    setState(() {
      _voiceActive = false;
      _buttonScaleUp = false;
    });
    Future.delayed(const Duration(milliseconds: 200), _dismissOverlay);
    if (_highlightedDir == _dirDown) return;

    TaskPool? pool;
    switch (_highlightedDir) {
      case _dirUp:
        pool = TaskPool.daily;
        break;
      case _dirLeft:
        pool = TaskPool.light;
        break;
      case _dirUpLeft:
        pool = TaskPool.longterm;
        break;
    }
    _voicePool = pool;

    final text = _sttPartialText.trim();
    if (text.isEmpty) {
      _showHint(str.AppStrings.sttFailed);
      return;
    }
    VoiceQueue().enqueue(text, pool: _voicePool);
  }

  void _showVoiceOverlay() {
    final c = _dotsCenter;
    if (c == null) return;
    final x0 = c.dx;
    final y0 = c.dy;
    const r = 100.0;
    const d = 80.0;
    const half = 34.0; // 68/2
    _voiceOverlay = OverlayEntry(
      builder: (ctx) {
        return ClipRect(
          clipBehavior: Clip.hardEdge,
          child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {},
                child: Container(color: CupertinoColors.black.withValues(alpha: 0.3)),
              ),
            ),
            // 日常待办 · 上 (x0, y0-r)
            _dot(x0 - half, y0 - r - half,
              icon: CupertinoIcons.today,
              highlighted: _highlightedDir == _dirUp,
              anim: _dotTopAnim,
            ),
            // 轻任务 · 左上 (x0 - r/√2, y0 - r/√2)
            _dot(x0 - r * 0.707 - half, y0 - r * 0.707 - half,
              icon: CupertinoIcons.wand_stars,
              highlighted: _highlightedDir == _dirUpLeft,
              anim: _dotTopLeftAnim,
            ),
            // 长期目标 · 左 (x0 - r, y0)
            _dot(x0 - r - half, y0 - half,
              icon: CupertinoIcons.flag,
              highlighted: _highlightedDir == _dirLeft,
              anim: _dotLeftAnim,
            ),
            // 取消 · 下 (x0, y0+d) 始终可见
            _dot(x0 - half, y0 + d - half,
              icon: CupertinoIcons.xmark,
              highlighted: _highlightedDir == _dirDown,
              anim: _cancelCtrl,
              isCancel: true,
            ),
            // 浮动文字框
            if (_sttPartialText.isNotEmpty)
              Positioned(
                left: 40, right: 40, top: y0 - r - 80,
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.of(context).background,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withValues(alpha: 0.15),
                        blurRadius: 10, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Text(_sttPartialText,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        );
      },
    );
    Overlay.of(context).insert(_voiceOverlay!);
  }

  Widget _dot(double left, double top, {
    required IconData icon,
    required bool highlighted,
    required Animation<double> anim,
    bool isCancel = false,
  }) {
    final color = isCancel ? AppTheme.of(context).destructive : AppTheme.of(context).primary;
    final size = highlighted ? 68.0 : 56.0;
    return Positioned(
      left: left,
      top: top,
      child: AnimatedBuilder(
        animation: anim,
        builder: (_, child) {
          final v = anim.value.clamp(0.0, 1.0);
          return Opacity(
            opacity: v,
            child: Transform.scale(
              scale: v,
              alignment: Alignment.center,
              child: SizedBox(
                width: 68,
                height: 68,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: highlighted
                          ? color.withValues(alpha: 0.9)
                          : color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: AppTheme.of(context).white, size: 24),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTextInput() {
    final settings = context.read<SettingsProvider>();
    final tasks = context.read<TaskProvider>();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => _TextInputSheet(
        defaultPool: widget.defaultPool,
        settings: settings,
        tasks: tasks,
      ),
    );
  }

  void _showHint(String msg) {
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text('确定'),
          ),
        ],
      ),
    );
  }
}

class _TextInputSheet extends StatefulWidget {
  final TaskPool? defaultPool;
  final SettingsProvider settings;
  final TaskProvider tasks;

  const _TextInputSheet({
    required this.defaultPool,
    required this.settings,
    required this.tasks,
  });

  @override
  State<_TextInputSheet> createState() => _TextInputSheetState();
}

class _TextInputSheetState extends State<_TextInputSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  TaskPool? _selectedPool;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selectedPool = widget.defaultPool;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoTheme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _poolTag(TaskPool.daily, '日常待办'),
                SizedBox(width: 10),
                _poolTag(TaskPool.light, '轻任务'),
                SizedBox(width: 10),
                _poolTag(TaskPool.longterm, '长期目标'),
              ],
            ),
            SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: CupertinoTextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    placeholder: str.AppStrings.micHint,
                    maxLines: 3,
                    minLines: 1,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.of(context).surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                SizedBox(width: 8),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  onPressed: _loading ? null : _send,
                  child: _loading
                      ? const CupertinoActivityIndicator()
                      : Icon(CupertinoIcons.arrow_up_circle_fill,
                          size: 36, color: AppTheme.of(context).primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _poolTag(TaskPool pool, String label) {
    final isSelected = _selectedPool == pool;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedPool = _selectedPool == pool ? null : pool;
      }),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.of(context).primary
              : AppTheme.of(context).surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? AppTheme.of(context).white : AppTheme.of(context).text,
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _loading = true);
    VoiceQueue().enqueue(text, pool: _selectedPool);
    if (mounted) Navigator.pop(context);
  }
}

class _RipplePainter extends CustomPainter {
  final double t;
  final Color color;
  _RipplePainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    for (int i = 0; i < 3; i++) {
      final phase = (t * 3 + i / 3) % 1.0;
      final radius = 20 + phase * 18;
      final opacity = (1 - phase) * 0.5;
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) => old.t != t;
}
