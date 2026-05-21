import 'dart:async';
import 'package:flutter/cupertino.dart';
import '../services/voice_queue.dart';
import '../utils/theme.dart';

class DebugOverlay extends StatefulWidget {
  const DebugOverlay({super.key});

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  double _x = 16;
  double _y = 120;
  bool _minimized = false;
  final _queue = VoiceQueue();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _queue.addListener(_onQueueChange);
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _queue.removeListener(_onQueueChange);
    super.dispose();
  }

  void _onQueueChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_minimized) {
      return Positioned(
        left: _x,
        top: _y,
        child: GestureDetector(
          onTap: () => setState(() => _minimized = false),
          onPanUpdate: (d) => setState(() {
            _x += d.delta.dx;
            _y += d.delta.dy;
          }),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _statusColor().withValues(alpha: 0.9),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${_queue.queueLength}',
                style: TextStyle(color: AppTheme.of(context).white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      );
    }
    return Positioned(
      left: _x,
      top: _y,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() {
          _x += d.delta.dx;
          _y += d.delta.dy;
        }),
        child: Container(
          width: 220,
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: CupertinoColors.black.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _statusColor(),
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    _queue.isProcessing ? '处理中' : _queue.queueLength > 0 ? '排队: ${_queue.queueLength}' : '空闲',
                    style: TextStyle(color: AppTheme.of(context).white, fontSize: 13),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _minimized = true),
                    child: Icon(CupertinoIcons.xmark, size: 16, color: AppTheme.of(context).white),
                  ),
                ],
              ),
              if (_queue.currentProcessing != null) ...[
                SizedBox(height: 6),
                Text(
                  _queue.currentProcessing!,
                  style: TextStyle(color: AppTheme.of(context).primary, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (_queue.queueLength > 0 && !_queue.isProcessing) ...[
                SizedBox(height: 4),
                Text('${_queue.queueLength} 条排队中',
                    style: TextStyle(color: AppTheme.of(context).textSecondary, fontSize: 11)),
              ],
              SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: SizedBox(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0x33FFFFFF))),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 4),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _queue.recentLogs
                        .map((l) => Text(l,
                            style: TextStyle(color: Color(0x99FFFFFF), fontSize: 10)))
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor() {
    if (_queue.isProcessing) return AppTheme.of(context).primary;
    if (_queue.queueLength > 0) return AppTheme.of(context).star;
    return const Color(0xFF4CAF50);
  }
}
