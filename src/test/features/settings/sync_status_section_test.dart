import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/core/auth/auth_account.dart';
import 'package:time_tracker/core/auth/auth_controller.dart';
import 'package:time_tracker/core/auth/auth_port.dart';
import 'package:time_tracker/core/sync/sync_service.dart';
import 'package:time_tracker/features/settings/sync_status_section.dart';

// ---------------------------------------------------------------------------
// Fakes — the section only needs auth state and sync UI state, so both ports
// are mocked; no SQLite or network is involved.
// ---------------------------------------------------------------------------

class _FakeAuth implements AuthPort {
  @override
  AuthAccount? currentAccount;
  _FakeAuth([this.currentAccount]);

  @override
  Stream<AuthAccount?> authChanges() => const Stream.empty();
  @override
  Future<AuthAccount?> signInWithGoogle() async => currentAccount;
  @override
  Future<void> signOut() async => currentAccount = null;
}

class _StubSyncService extends StateNotifier<SyncUiState>
    implements SyncService {
  final syncedOwners = <String>[];

  _StubSyncService(super.state);

  @override
  Future<void> sync(String ownerId) async => syncedOwners.add(ownerId);
  @override
  void start() {}
  @override
  void requestSync() {}

  /// Test hook — [state] is protected inside StateNotifier subclasses.
  void emit(SyncUiState s) => state = s;
}

const _account = AuthAccount(id: 'owner-1', email: 'a@b.c');

Widget _app(_StubSyncService stub, {AuthAccount? account = _account}) =>
    ProviderScope(
      overrides: [
        cloudSyncEnabledProvider.overrideWithValue(true),
        authPortProvider.overrideWithValue(_FakeAuth(account)),
        syncServiceProvider.overrideWith((ref) => stub),
      ],
      child: const MaterialApp(home: Scaffold(body: SyncStatusSection())),
    );

void main() {
  testWidgets('guest renders nothing', (tester) async {
    await tester.pumpWidget(
        _app(_StubSyncService(const SyncUiState()), account: null));
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('guest-only build (sync disabled) renders nothing',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authPortProvider.overrideWithValue(_FakeAuth(_account)),
      ],
      child: const MaterialApp(home: Scaffold(body: SyncStatusSection())),
    ));
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('signed-in idle shows last successful sync time',
      (tester) async {
    final stub = _StubSyncService(
      SyncUiState(lastSyncedAt: DateTime(2026, 7, 5, 9, 30)),
    );
    await tester.pumpWidget(_app(stub));

    expect(find.text('마지막 동기화: 2026.07.05 09:30'), findsOneWidget);
    expect(find.byIcon(Icons.sync), findsOneWidget);
  });

  testWidgets('never-synced idle shows placeholder', (tester) async {
    await tester.pumpWidget(_app(_StubSyncService(const SyncUiState())));
    expect(find.text('아직 동기화되지 않음'), findsOneWidget);
  });

  testWidgets('syncing shows progress and hides the manual action',
      (tester) async {
    await tester.pumpWidget(_app(
        _StubSyncService(const SyncUiState(phase: SyncPhase.syncing))));

    expect(find.text('동기화 중…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.sync), findsNothing);
  });

  testWidgets('error shows concise message and retry stays available',
      (tester) async {
    final stub = _StubSyncService(const SyncUiState(
      phase: SyncPhase.error,
      error: '동기화에 실패했습니다. 네트워크 확인 후 다시 시도해 주세요.',
    ));
    await tester.pumpWidget(_app(stub));

    expect(find.text('동기화 실패'), findsOneWidget);
    expect(find.textContaining('네트워크'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.sync));
    expect(stub.syncedOwners, ['owner-1']);
  });

  testWidgets('manual sync action syncs the signed-in owner', (tester) async {
    final stub = _StubSyncService(const SyncUiState());
    await tester.pumpWidget(_app(stub));

    await tester.tap(find.byIcon(Icons.sync));

    expect(stub.syncedOwners, ['owner-1']);
  });

  testWidgets('state transitions re-render: syncing → error → idle',
      (tester) async {
    final stub = _StubSyncService(const SyncUiState(phase: SyncPhase.syncing));
    await tester.pumpWidget(_app(stub));
    expect(find.text('동기화 중…'), findsOneWidget);

    stub.emit(const SyncUiState(phase: SyncPhase.error, error: '실패'));
    await tester.pump();
    expect(find.text('동기화 실패'), findsOneWidget);

    stub.emit(SyncUiState(lastSyncedAt: DateTime(2026, 7, 5, 12, 0)));
    await tester.pump();
    expect(find.text('마지막 동기화: 2026.07.05 12:00'), findsOneWidget);
  });
}
