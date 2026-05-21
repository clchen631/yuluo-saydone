import 'package:flutter/cupertino.dart';
import '../models/task.dart';
import '../utils/theme.dart';

class SlideCompleteNotification extends Notification {
  final String taskId;
  final Offset globalPosition;
  final bool isStart;
  final bool isEnd;
  const SlideCompleteNotification({
    this.taskId = '',
    this.globalPosition = Offset.zero,
    this.isStart = false,
    this.isEnd = false,
  });
}

class TaskListTile extends StatefulWidget {
  final Task task;
  final bool selectionMode;
  final bool isSelected;
  final bool slideCompleting;
  final bool slideUndoing;
  final bool isDone;
  final bool fading;
  final VoidCallback? onSelect;
  final VoidCallback? onTap;
  final VoidCallback? onMarkDone;
  final VoidCallback? onUndo;

  const TaskListTile({
    super.key,
    required this.task,
    this.selectionMode = false,
    this.isSelected = false,
    this.slideCompleting = false,
    this.slideUndoing = false,
    this.isDone = false,
    this.fading = false,
    this.onSelect,
    this.onTap,
    this.onMarkDone,
    this.onUndo,
  });

  @override
  State<TaskListTile> createState() => _TaskListTileState();
}

class _TaskListTileState extends State<TaskListTile> {
  bool get _circleFilled =>
      widget.slideCompleting || (widget.isDone && !widget.slideUndoing);

  @override
  Widget build(BuildContext context) {
    final tile = GestureDetector(
      onTap: widget.selectionMode ? widget.onSelect : widget.onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: widget.selectionMode
                  ? widget.onSelect
                  : widget.isDone
                      ? widget.onUndo
                      : widget.onMarkDone,
              onVerticalDragStart: (d) {
                SlideCompleteNotification(
                  taskId: widget.task.id,
                  globalPosition: d.globalPosition,
                  isStart: true,
                ).dispatch(context);
              },
              onVerticalDragUpdate: (d) {
                SlideCompleteNotification(
                  globalPosition: d.globalPosition,
                ).dispatch(context);
              },
              onVerticalDragEnd: (d) {
                SlideCompleteNotification(isEnd: true).dispatch(context);
              },
              behavior: HitTestBehavior.translucent,
              child: Padding(
                padding: EdgeInsets.only(right: 10),
                child: widget.selectionMode
                    ? Icon(
                        widget.isSelected
                            ? CupertinoIcons.checkmark_square
                            : CupertinoIcons.square,
                        size: 22,
                        color: AppTheme.of(context).primary,
                      )
                    : _buildCircle(),
              ),
            ),
            Expanded(
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.of(context).taskCardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.task.title,
                            style: TextStyle(
                              fontSize: 16,
                              color: _circleFilled
                                  ? AppTheme.of(context).textSecondary
                                  : AppTheme.of(context).text,
                            ),
                          ),
                        ),
                        if (widget.task.importance ==
                            TaskImportance.important)
                          Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(CupertinoIcons.star_fill,
                                size: 16, color: AppTheme.of(context).star),
                          ),
                      ],
                    ),
                    if (widget.task.notes != null &&
                        widget.task.notes!.isNotEmpty) ...[
                      SizedBox(height: 2),
                      Text(
                        widget.task.notes!,
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.of(context).textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (widget.task.ddl != null) ...[
                      SizedBox(height: 2),
                      Text(
                        '截止：${widget.task.ddl}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isDdlOverdue
                              ? AppTheme.of(context).destructive
                              : AppTheme.of(context).textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return AnimatedOpacity(
      opacity: widget.fading ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 600),
      alwaysIncludeSemantics: true,
      child: tile,
    );
  }

  Widget _buildCircle() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _circleFilled ? AppTheme.of(context).primary : const Color(0x00000000),
        border: Border.all(color: AppTheme.of(context).primary, width: 1.5),
      ),
      child: AnimatedScale(
        scale: _circleFilled ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: Center(
          child: Icon(
            CupertinoIcons.checkmark_alt,
            size: 14,
            color: AppTheme.of(context).white,
          ),
        ),
      ),
    );
  }

  bool get _isDdlOverdue {
    if (widget.task.ddl == null) return false;
    final ddlDate = DateTime.tryParse(widget.task.ddl!);
    if (ddlDate == null) return false;
    return DateTime.now().isAfter(ddlDate);
  }
}
