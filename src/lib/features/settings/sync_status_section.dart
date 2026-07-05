import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/sync/sync_service.dart';

/// Sync status row for Settings (#95): last successful sync time, current
/// phase, a concise error when the last run failed, and a manual sync action.
/// Renders nothing for guests or guest-only builds — sync state only exists
/// for a signed-in user, and failures never block local tracking.
class SyncStatusSection extends ConsumerWidget {
  const SyncStatusSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(cloudSyncEnabledProvider)) return const SizedBox.shrink();
    final account = ref.watch(authControllerProvider).account;
    if (account == null) return const SizedBox.shrink();

    final sync = ref.watch(syncServiceProvider);
    final syncing = sync.phase == SyncPhase.syncing;
    final failed = sync.phase == SyncPhase.error;

    return ListTile(
      leading: Icon(
        syncing
            ? Icons.cloud_sync
            : failed
                ? Icons.sync_problem
                : Icons.check_circle_outline,
        color: failed ? Theme.of(context).colorScheme.error : null,
      ),
      title: Text(
        syncing
            ? '동기화 중…'
            : failed
                ? '동기화 실패'
                : _lastSyncLabel(sync.lastSyncedAt),
      ),
      subtitle: failed ? Text(sync.error ?? '') : null,
      trailing: syncing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: const Icon(Icons.sync),
              tooltip: '지금 동기화',
              onPressed: () =>
                  ref.read(syncServiceProvider.notifier).sync(account.id),
            ),
    );
  }

  String _lastSyncLabel(DateTime? at) {
    if (at == null) return '아직 동기화되지 않음';
    final local = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '마지막 동기화: ${local.year}.${two(local.month)}.${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
