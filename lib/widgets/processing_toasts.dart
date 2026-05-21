import 'package:flutter/cupertino.dart';
import '../services/voice_queue.dart';
import '../utils/theme.dart';

class ProcessingToastArea extends StatefulWidget {
  const ProcessingToastArea({super.key});

  @override
  State<ProcessingToastArea> createState() => _ProcessingToastAreaState();
}

class _ProcessingToastAreaState extends State<ProcessingToastArea> {
  final _queue = VoiceQueue();

  @override
  void initState() {
    super.initState();
    _queue.addListener(_onChange);
  }

  @override
  void dispose() {
    _queue.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final toasts = _queue.toasts;
    if (toasts.isEmpty) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      bottom: 150,
      child: IgnorePointer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: toasts.map((t) => _ToastItem(key: ValueKey(t.id), state: t)).toList(),
        ),
      ),
    );
  }
}

class _ToastItem extends StatefulWidget {
  final ToastState state;
  const _ToastItem({super.key, required this.state});

  @override
  State<_ToastItem> createState() => _ToastItemState();
}

class _ToastItemState extends State<_ToastItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 0.0,
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant _ToastItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.stage == ToastStage.fading &&
        oldWidget.state.stage != ToastStage.fading) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

   Color _bgColor() {
     return AppTheme.of(context).toastBg;
   }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Padding(
        padding: EdgeInsets.only(bottom: 8, left: 20),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            decoration: BoxDecoration(
              color: _bgColor(),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              widget.state.text,
              style: TextStyle(
                color: AppTheme.of(context).white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
