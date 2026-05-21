import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/theme.dart';
import 'pool_detail_page.dart';

class PoolsPage extends StatefulWidget {
  const PoolsPage({super.key});

  @override
  State<PoolsPage> createState() => _PoolsPageState();
}

class _PoolsPageState extends State<PoolsPage> {
  @override
  void initState() {
    super.initState();
    final tp = context.read<TaskProvider>();
    tp.addListener(_onTasksChanged);
  }

  @override
  void dispose() {
    context.read<TaskProvider>().removeListener(_onTasksChanged);
    super.dispose();
  }

  void _onTasksChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final tp = context.read<TaskProvider>();
    final dailyCount = tp.activeInPool(TaskPool.daily).length;
    final lightCount = tp.activeInPool(TaskPool.light).length;
    final longtermCount = tp.activeInPool(TaskPool.longterm).length;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppTheme.of(context).surface,
        middle: Text('池'),
      ),
      child: SafeArea(
        child: ListView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.all(16),
          children: [
            _poolCard(
              context,
              title: settings.poolDisplayName('daily'),
              pool: TaskPool.daily,
              icon: CupertinoIcons.today,
              count: dailyCount,
            ),
            SizedBox(height: 12),
            _poolCard(
              context,
              title: settings.poolDisplayName('light'),
              pool: TaskPool.light,
              icon: CupertinoIcons.wand_stars,
              count: lightCount,
            ),
            SizedBox(height: 12),
            _poolCard(
              context,
              title: settings.poolDisplayName('longterm'),
              pool: TaskPool.longterm,
              icon: CupertinoIcons.flag,
              count: longtermCount,
            ),
          ],
        ),
      ),
    );
  }

  Widget _poolCard(
    BuildContext context, {
    required String title,
    required TaskPool pool,
    required IconData icon,
    required int count,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => PoolDetailPage(pool: pool),
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.of(context).sectionCardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: AppTheme.of(context).primary),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('$count 条任务',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.of(context).textSecondary)),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right,
                color: AppTheme.of(context).textSecondary),
          ],
        ),
      ),
    );
  }
}
