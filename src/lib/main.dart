import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/db/database_helper.dart';
import 'core/models/time_block_style.dart';
import 'core/notifications/notification_port.dart';
import 'core/services/appearance_service.dart';
import 'core/theme/app_theme.dart';
import 'core/notifications/notification_scheduler.dart';
import 'core/notifications/notification_settings.dart';
import 'core/services/preferences_port.dart';
import 'features/analytics/analytics_screen.dart';
import 'features/grid/grid_screen.dart';
import 'features/settings/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await openAppDatabase();
  final rawPrefs = await SharedPreferences.getInstance();
  final prefsAdapter = SharedPrefsAdapter(rawPrefs);

  final port = FlutterLocalNotificationsAdapter();
  await port.initialize();

  final settings = NotificationSettings(
    enabled: prefsAdapter.getBool(NotificationSettings.keyEnabled) ?? true,
    sleepStartMinute:
        prefsAdapter.getInt(NotificationSettings.keySleepStart) ?? 1380,
    sleepEndMinute:
        prefsAdapter.getInt(NotificationSettings.keySleepEnd) ?? 420,
  );
  await scheduleWeeklyFallbackNotifications(settings, port);

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPrefsAdapterProvider.overrideWithValue(prefsAdapter),
        notificationPortProvider.overrideWithValue(port),
      ],
      child: const TimeTrackerApp(),
    ),
  );
}

class TimeTrackerApp extends ConsumerWidget {
  const TimeTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeServiceProvider);
    return MaterialApp(
      title: 'Time Tracker',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const _RootShell(),
    );
  }
}

class _RootShell extends ConsumerStatefulWidget {
  const _RootShell();

  @override
  ConsumerState<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<_RootShell> {
  int _index = 0;

  static const _screens = [GridScreen(), AnalyticsScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blockStyle = ref.watch(appearanceServiceProvider);
    final isGlass = blockStyle == TimeBlockStyle.liquidGlass;

    final scaffold = Scaffold(
      backgroundColor: isGlass ? Colors.transparent : null,
      extendBody: true,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: CupertinoTabBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            activeColor: isDark ? Colors.white : Colors.black,
            inactiveColor: const Color(0xFFC7C7CC),
            backgroundColor: Colors.transparent,
            border: null,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: '기록'),
              BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '분석'),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
            ],
          ),
        ),
      ),
    );

    if (!isGlass) return scaffold;

    final gradient = isDark
        ? AppTheme.ambientGradientDark
        : AppTheme.ambientGradientLight;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: Theme(
        data: Theme.of(
          context,
        ).copyWith(scaffoldBackgroundColor: Colors.transparent),
        child: scaffold,
      ),
    );
  }
}
