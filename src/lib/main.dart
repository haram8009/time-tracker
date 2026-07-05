import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/auth_port.dart';
import 'core/auth/supabase_auth_adapter.dart';
import 'core/db/database_helper.dart';
import 'core/services/settings_service.dart';
import 'core/sync/cloud_promotion_service.dart';
import 'core/sync/cloud_sync_port.dart';
import 'core/sync/supabase_cloud_sync_adapter.dart';
import 'core/sync/sync_service.dart';
import 'core/models/time_block_style.dart';
import 'core/notifications/notification_port.dart';
import 'core/services/appearance_service.dart';
import 'core/theme/app_theme.dart';
import 'core/notifications/notification_scheduler.dart';
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
    enabled: prefsAdapter.getBool(NotificationSettings.keyEnabled) ??
        NotificationSettings.defaultEnabled,
    sleepStartMinute: prefsAdapter.getInt(NotificationSettings.keySleepStart) ??
        NotificationSettings.defaultSleepStart,
    sleepEndMinute: prefsAdapter.getInt(NotificationSettings.keySleepEnd) ??
        NotificationSettings.defaultSleepEnd,
  );
  await scheduleWeeklyFallbackNotifications(settings, port);

  final cloud = await _initCloud();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPrefsAdapterProvider.overrideWithValue(prefsAdapter),
        notificationPortProvider.overrideWithValue(port),
        authPortProvider.overrideWithValue(cloud.authPort),
        if (cloud.syncPort != null) ...[
          cloudSyncPortProvider.overrideWithValue(cloud.syncPort!),
          cloudSyncEnabledProvider.overrideWithValue(true),
        ],
      ],
      child: const TimeTrackerApp(),
    ),
  );
}

// Cloud sync config (see docs/supabase-cloud-sync.md). Passed via --dart-define;
// absent in guest-only builds, in which case cloud login is disabled.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
const _googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

class _CloudPorts {
  final AuthPort authPort;
  final CloudSyncPort? syncPort;
  const _CloudPorts(this.authPort, this.syncPort);
}

/// Initializes Supabase + Google sign-in when configured, else falls back to a
/// guest-only port so the app runs fully offline with local SQLite.
Future<_CloudPorts> _initCloud() async {
  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    return const _CloudPorts(GuestAuthPort(), null);
  }

  await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseAnonKey);
  await GoogleSignIn.instance.initialize(
    clientId: _googleIosClientId.isEmpty ? null : _googleIosClientId,
    serverClientId: _googleWebClientId.isEmpty ? null : _googleWebClientId,
  );
  final client = Supabase.instance.client;
  return _CloudPorts(
    SupabaseAuthAdapter(supabase: client),
    SupabaseCloudSyncAdapter(client),
  );
}

class TimeTrackerApp extends ConsumerWidget {
  const TimeTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(cloudSyncEnabledProvider)) {
      // Instantiating the service starts its store watchers (auto-sync of
      // pending local changes, debounced — issue #94).
      final syncService = ref.watch(syncServiceProvider);

      // Full sync on every transition into a signed-in state — first sign-in
      // (pull before promotion so a fresh device adopts existing cloud rows
      // instead of pushing seeded presets as duplicates) and session restore
      // on app launch. Idempotent, so re-signing in is safe.
      ref.listen(authControllerProvider, (prev, next) {
        final signedInNow = prev?.account == null && next.account != null;
        if (signedInNow) {
          syncService.sync(next.account!.id);
        }
      });

      // Settings edits don't flow through the SQLite stores the service
      // watches, so nudge it from the provider side.
      ref.listen(settingsServiceProvider, (_, next) => syncService.requestSync());
    }

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
