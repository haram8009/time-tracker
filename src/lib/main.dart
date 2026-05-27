import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/notifications/notification_port.dart';
import 'core/notifications/notification_scheduler.dart';
import 'core/services/settings_service.dart';
import 'features/analytics/analytics_screen.dart';
import 'features/grid/grid_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final port = FlutterLocalNotificationsAdapter();
  await port.initialize();
  final settings = await NotificationSettings.loadFromPrefs();
  await scheduleWeeklyFallbackNotifications(settings, port);
  runApp(ProviderScope(
    overrides: [notificationPortProvider.overrideWithValue(port)],
    child: const TimeTrackerApp(),
  ));
}

class TimeTrackerApp extends StatelessWidget {
  const TimeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Time Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const _RootShell(),
    );
  }
}

class _RootShell extends StatefulWidget {
  const _RootShell();

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> {
  int _index = 0;

  static const _screens = [GridScreen(), AnalyticsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view), label: '기록'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: '분석'),
        ],
      ),
    );
  }
}
