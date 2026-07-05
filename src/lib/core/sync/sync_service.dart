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

/// Orchestrates one full incremental sync cycle (#94): pull remote changes
/// (LWW), push pending local rows, then refresh the UI-facing stores. Also
/// watches the local stores and schedules a debounced auto-sync whenever a
/// signed-in user leaves pending changes behind.
///
/// Failures are swallowed here — sync must never block local tracking; status
/// and error surfacing land with #95.
class SyncService {
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
        _debounce = debounce;

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
  /// Errors are swallowed: rows keep their pending status, so the next sync
  /// retries them (see the promotion service's idempotency contract).
  Future<void> sync(String ownerId) {
    final running = _running;
    if (running != null) return running;
    final run = _syncOnce(ownerId).whenComplete(() => _running = null);
    _running = run;
    return run;
  }

  Future<void> _syncOnce(String ownerId) async {
    try {
      await _pull.pull(ownerId);
      await _promote.promote(ownerId);
      await _categories.refreshWatchers();
      await _blocks.refreshWatchers();
      await _reloadSettings();
    } catch (_) {
      // Offline or remote failure — local tracking continues, retry later.
    }
  }

  Future<bool> _hasPendingChanges() async =>
      _prefs.getBool(SettingsSyncKeys.dirty) == true ||
      (await _local.pendingCategories()).isNotEmpty ||
      (await _local.pendingTimeBlocks()).isNotEmpty;

  void dispose() {
    _timer?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
  }
}

/// False in guest-only builds (no Supabase config); main.dart overrides to
/// true when cloud ports exist, gating every [syncServiceProvider] read.
final cloudSyncEnabledProvider = Provider<bool>((_) => false);

final syncServiceProvider = Provider<SyncService>((ref) {
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
  ref.onDispose(service.dispose);
  return service;
});
