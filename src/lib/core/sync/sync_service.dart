// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_port.dart';
import '../db/category_store.dart';
import '../db/sync_local_store.dart';
import '../db/sync_metadata.dart';
import '../db/time_block_store.dart';
import '../services/preferences_port.dart';
import '../services/settings_service.dart';
import 'cloud_promotion_service.dart';
import 'cloud_pull_service.dart';

/// Where a sync cycle currently stands, for the Settings status UI (#95).
enum SyncPhase { idle, syncing, error }

/// UI-facing sync state: current phase, last successful sync time (persisted
/// across launches), and a concise recoverable error when the last run failed.
class SyncUiState {
  final SyncPhase phase;
  final DateTime? lastSyncedAt;
  final String? error;

  const SyncUiState({
    this.phase = SyncPhase.idle,
    this.lastSyncedAt,
    this.error,
  });
}

/// Orchestrates one full incremental sync cycle (#94): pull remote changes
/// (LWW), push pending local rows, then refresh the UI-facing stores. Also
/// watches the local stores and schedules a debounced auto-sync whenever a
/// signed-in user leaves pending changes behind.
///
/// Failures never propagate — local tracking must keep working offline. They
/// surface as [SyncUiState.error] instead (#95); pending rows keep their
/// status, so any later sync (auto or manual) retries them.
class SyncService extends StateNotifier<SyncUiState> {
  /// Prefs key: epoch millis of the last fully successful sync.
  static const lastSyncMillisKey = 'sync_last_success_millis';

  static const _errorMessage = '동기화에 실패했습니다. 네트워크 확인 후 다시 시도해 주세요.';

  final CloudPullService _pull;
  final CloudPromotionService _promote;
  final SyncLocalStore _local;
  final PreferencesPort _prefs;
  final AuthPort _auth;
  final CategoryStore _categories;
  final TimeBlockStore _blocks;
  final Future<void> Function() _reloadSettings;
  final Duration _debounce;

  final _subs = <StreamSubscription<Object?>>[];
  Timer? _timer;
  Future<void>? _running;

  SyncService({
    required CloudPullService pull,
    required CloudPromotionService promote,
    required SyncLocalStore local,
    required PreferencesPort prefs,
    required AuthPort auth,
    required CategoryStore categories,
    required TimeBlockStore blocks,
    required Future<void> Function() reloadSettings,
    Duration debounce = const Duration(seconds: 3),
  })  : _pull = pull,
        _promote = promote,
        _local = local,
        _prefs = prefs,
        _auth = auth,
        _categories = categories,
        _blocks = blocks,
        _reloadSettings = reloadSettings,
        _debounce = debounce,
        super(SyncUiState(lastSyncedAt: _readLastSync(prefs)));

  static DateTime? _readLastSync(PreferencesPort prefs) {
    final millis = prefs.getInt(lastSyncMillisKey);
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// Starts watching local mutations for auto-sync. Idempotent per instance.
  void start() {
    if (_subs.isNotEmpty) return;
    _subs.add(_blocks.changes.listen((_) => requestSync()));
    _subs.add(
        _categories.watchAllIncludingRetired().listen((_) => requestSync()));
  }

  /// Debounced sync request. No-ops when signed out or nothing is pending, so
  /// the store refreshes a sync itself triggers don't loop back into another.
  void requestSync() {
    _timer?.cancel();
    _timer = Timer(_debounce, () async {
      final account = _auth.currentAccount;
      if (account == null) return;
      if (!await _hasPendingChanges()) return;
      await sync(account.id);
    });
  }

  /// Runs one sync cycle. Concurrent calls coalesce onto the in-flight run.
  /// Never throws: failures land in [SyncUiState.error], rows keep their
  /// pending status, and the next sync retries them (see the promotion
  /// service's idempotency contract).
  Future<void> sync(String ownerId) {
    final running = _running;
    if (running != null) return running;
    final run = _syncOnce(ownerId).whenComplete(() => _running = null);
    _running = run;
    return run;
  }

  Future<void> _syncOnce(String ownerId) async {
    state = SyncUiState(
      phase: SyncPhase.syncing,
      lastSyncedAt: state.lastSyncedAt,
    );
    try {
      await _pull.pull(ownerId);
      await _promote.promote(ownerId);
      await _categories.refreshWatchers();
      await _blocks.refreshWatchers();
      await _reloadSettings();

      // Truncated to millis so the in-memory value matches what the prefs
      // round-trip restores after a relaunch.
      final now = DateTime.fromMillisecondsSinceEpoch(
          DateTime.now().millisecondsSinceEpoch);
      await _prefs.setInt(lastSyncMillisKey, now.millisecondsSinceEpoch);
      if (mounted) state = SyncUiState(lastSyncedAt: now);
    } catch (_) {
      // Offline or remote failure — local tracking continues, retry later.
      if (mounted) {
        state = SyncUiState(
          phase: SyncPhase.error,
          lastSyncedAt: state.lastSyncedAt,
          error: _errorMessage,
        );
      }
    }
  }

  Future<bool> _hasPendingChanges() async =>
      _prefs.getBool(SettingsSyncKeys.dirty) == true ||
      (await _local.pendingCategories()).isNotEmpty ||
      (await _local.pendingTimeBlocks()).isNotEmpty;

  @override
  void dispose() {
    _timer?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    super.dispose();
  }
}

/// False in guest-only builds (no Supabase config); main.dart overrides to
/// true when cloud ports exist, gating every [syncServiceProvider] read.
final cloudSyncEnabledProvider = Provider<bool>((_) => false);

final syncServiceProvider =
    StateNotifierProvider<SyncService, SyncUiState>((ref) {
  final service = SyncService(
    pull: ref.watch(cloudPullServiceProvider),
    promote: ref.watch(cloudPromotionServiceProvider),
    local: ref.watch(syncLocalStoreProvider),
    prefs: ref.watch(sharedPrefsAdapterProvider),
    auth: ref.watch(authPortProvider),
    categories: ref.watch(categoryStoreProvider),
    blocks: ref.watch(timeBlockStoreProvider),
    reloadSettings: () => ref.read(settingsServiceProvider.notifier).reload(),
  );
  service.start();
  return service;
});
