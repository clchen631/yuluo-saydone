import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'providers/task_provider.dart';
import 'providers/settings_provider.dart';
import 'services/notification_service.dart';
import 'services/voice_queue.dart';
import 'utils/theme.dart';
import 'pages/home_page.dart';
import 'pages/pools_page.dart';
import 'pages/profile_page.dart';
import 'widgets/debug_overlay.dart';
import 'widgets/processing_toasts.dart';

class SayDoneApp extends StatefulWidget {
  const SayDoneApp({super.key});

  @override
  State<SayDoneApp> createState() => _SayDoneAppState();
}

class _SayDoneAppState extends State<SayDoneApp> {
  @override
  void initState() {
    super.initState();
    _loadData();
    _listenSettings();
  }

  void _listenSettings() {
    final settings = context.read<SettingsProvider>();
    settings.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    final tasks = context.read<TaskProvider>();
    NotificationService().rescheduleFromSettings(
      enabled: settings.remindEnabled,
      hour: settings.remindHour,
      minute: settings.remindMinute,
      incompleteCount: tasks.allTasks.length,
      taskTitles: tasks.allTasks.take(2).map((t) => t.title).toList(),
    );
  }

  Future<void> _loadData() async {
    final settings = context.read<SettingsProvider>();
    await settings.load();
    if (!mounted) return;
    final tasks = context.read<TaskProvider>();
    await tasks.loadAll();
    VoiceQueue().setProviders(tasks, settings);
    if (!mounted) return;
    await tasks.cleanRecycleBin(settings.recycleDays);
    final nService = NotificationService();
    await nService.init();
    if (!mounted) return;
    final incompleteCount = tasks.allTasks.length;
    final topTitles = tasks.allTasks.take(2).map((t) => t.title).toList();
    await nService.rescheduleFromSettings(
      enabled: settings.remindEnabled,
      hour: settings.remindHour,
      minute: settings.remindMinute,
      incompleteCount: incompleteCount,
      taskTitles: topTitles,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      builder: (context, child) {
        final brightness = MediaQuery.of(context).platformBrightness;
        final devMode = context.watch<SettingsProvider>().devMode;
        final isDark = brightness == Brightness.dark;
        return CupertinoTheme(
          data: isDark ? appDarkTheme : appTheme,
          child: AppTheme(
            data: isDark ? darkTheme : lightTheme,
            child: Stack(
              children: [
                child!,
                const ProcessingToastArea(),
                if (devMode) const DebugOverlay(),
              ],
            ),
          ),
        );
      },
      home: const MainTabs(),
    );
  }
}

class MainTabs extends StatefulWidget {
  const MainTabs({super.key});

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _currentIndex = 0;
  final _homeKey = GlobalKey<HomePageState>();

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          if (i == 0) _homeKey.currentState?.refreshData();
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.today),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.tray_2_fill),
            label: '池',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person),
            label: '我',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return HomePage(key: _homeKey);
          case 1:
            return const PoolsPage();
          case 2:
            return const ProfilePage();
          default:
            return HomePage(key: _homeKey);
        }
      },
    );
  }
}
