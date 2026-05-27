import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/category_store.dart';
import '../../core/db/database_helper.dart';
import '../../core/db/time_block_store.dart';
import '../../core/models/time_block.dart';
import '../../core/notifications/notification_port.dart';
import '../../core/notifications/notification_scheduler.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/time_utils.dart';
import 'grid_view_model.dart';

class GridScreenState {
  final DateTime selectedDate;
  final bool dbReady;

  const GridScreenState({required this.selectedDate, required this.dbReady});

  GridScreenState copyWith({DateTime? selectedDate, bool? dbReady}) {
    return GridScreenState(
      selectedDate: selectedDate ?? this.selectedDate,
      dbReady: dbReady ?? this.dbReady,
    );
  }
}

class GridScreenViewModel extends StateNotifier<GridScreenState> {
  final Ref _ref;

  GridScreenViewModel(this._ref)
      : super(GridScreenState(
          selectedDate: DateTime.now(),
          dbReady: false,
        )) {
    _init();
  }

  Future<void> _init() async {
    await DatabaseHelper.instance.database;
    await _ref.read(categoryStoreProvider).seedIfNeeded();
    state = state.copyWith(dbReady: true);
  }

  void goToPreviousDay() =>
      state = state.copyWith(
        selectedDate: state.selectedDate.subtract(const Duration(days: 1)),
      );

  void goToNextDay() {
    final next = state.selectedDate.add(const Duration(days: 1));
    final today = DateTime.now();
    if (next.year > today.year ||
        (next.year == today.year && next.month > today.month) ||
        (next.year == today.year &&
            next.month == today.month &&
            next.day > today.day)) {
      return;
    }
    state = state.copyWith(selectedDate: next);
  }

  void goToToday() =>
      state = state.copyWith(selectedDate: DateTime.now());

  TimeBlock? blockAtIndex(int index, List<TimeBlock> blocks) {
    final cellStart = GridViewModel.indexToMinute(index);
    final cellEnd = cellStart + 10;
    for (final b in blocks) {
      if (b.startMinute < cellEnd && b.endMinute > cellStart) return b;
    }
    return null;
  }

  Future<void> saveBlock(TimeBlock block) async {
    final store = _ref.read(timeBlockStoreProvider);
    await store.insert(block);

    final todayKey = dateKey(DateTime.now());
    if (block.date == todayKey) {
      final todayBlocks = await store.fetchByDate(todayKey);
      final settings = _ref.read(settingsServiceProvider);
      final port = _ref.read(notificationPortProvider);
      await scheduleSmartNotification(
        todayBlocks: todayBlocks,
        settings: settings,
        port: port,
      );
    }
  }
}

final gridScreenViewModelProvider =
    StateNotifierProvider<GridScreenViewModel, GridScreenState>(
        (ref) => GridScreenViewModel(ref));
