import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/category_store.dart';
import '../../core/db/time_block_store.dart';
import '../../core/services/photo_library_service.dart';
import '../../core/utils/time_utils.dart';
import 'category_bottom_sheet.dart';
import 'drag_selection_controller.dart';
import 'edit_block_bottom_sheet.dart';
import 'grid_screen_view_model.dart';
import 'grid_view_model.dart';
import 'widgets/grid_cell.dart';
import '../settings/settings_screen.dart';
import '../../core/notifications/notification_scheduler.dart';
import '../../core/services/settings_service.dart';

class GridScreen extends ConsumerStatefulWidget {
  const GridScreen({super.key});

  @override
  ConsumerState<GridScreen> createState() => _GridScreenState();
}

class _GridScreenState extends ConsumerState<GridScreen> {
  late final ScrollController _scrollController;
  late final DragSelectionController _drag;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _drag = DragSelectionController();
    _drag.addListener(() => setState(() {}));
  }

  void _scrollToNow() {
    if (!_scrollController.hasClients) return;
    final now = DateTime.now();
    final idx = GridViewModel.minuteToIndex(now.hour * 60 + now.minute);
    const cellH = 32.0;
    final screenH = MediaQuery.of(context).size.height;
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight;
    final offset =
        (idx * cellH - (screenH - topPad) / 2).clamp(0.0, double.infinity);
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _drag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GridScreenState>(gridScreenViewModelProvider, (prev, next) {
      if (prev?.dbReady == false && next.dbReady == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
      } else if (prev?.selectedDate != next.selectedDate) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_isToday(next.selectedDate)) {
            _scrollToNow();
          } else {
            _scrollToTop();
          }
        });
      }
    });

    final vmState = ref.watch(gridScreenViewModelProvider);
    final vm = ref.read(gridScreenViewModelProvider.notifier);

    if (!vmState.dbReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final selectedDate = vmState.selectedDate;
    final blocksAsync =
        ref.watch(timeBlocksStreamProvider(dateKey(selectedDate)));
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    const days = ['월', '화', '수', '목', '금', '토', '일'];
    final d = selectedDate;
    final dateLabel =
        '${d.year}년 ${d.month}월 ${d.day}일 (${days[d.weekday - 1]})';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: '이전 날',
          onPressed: () {
            vm.goToPreviousDay();
            _drag.clearSelection();
          },
        ),
        title: Text(
          dateLabel,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (!_isToday(selectedDate))
            TextButton(
              onPressed: () {
                vm.goToToday();
                _drag.clearSelection();
              },
              child: const Text('오늘', style: TextStyle(fontSize: 14)),
            ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: '다음 날',
            onPressed: () {
              vm.goToNextDay();
              _drag.clearSelection();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '설정',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
        centerTitle: true,
      ),
      body: blocksAsync.when(
        data: (dbBlocks) {
          if (_isToday(selectedDate)) {
            final notifSettings = ref.read(settingsServiceProvider);
            scheduleSmartNotification(
              todayBlocks: dbBlocks,
              settings: notifSettings,
            );
          }
          return categoriesAsync.when(
            data: (categories) {
              final photosAsync =
                  ref.watch(photosForDateProvider(selectedDate));
              final cells = GridViewModel.compute(
                blocks: dbBlocks,
                categories: categories,
                photos: photosAsync.valueOrNull ?? const [],
                selectedIndices: _drag.selectedIndices,
              );
              return ListView.builder(
                controller: _scrollController,
                itemCount: 144,
                itemExtent: 32,
                itemBuilder: (context, index) => GridCell(
                  key: ValueKey(index),
                  index: index,
                  state: cells[index],
                  onTap: () {
                    final existing = vm.blockAtIndex(index, dbBlocks);
                    if (existing != null) {
                      _drag.clearSelection();
                      showEditBlockBottomSheet(
                          context, ref, existing, categories);
                    } else {
                      _drag.onDragStart(index);
                      _drag.onDragEnd();
                      final sel = _drag.selection;
                      if (sel != null) {
                        showCategoryBottomSheet(
                          context,
                          ref,
                          dateKey(selectedDate),
                          sel.startMinute,
                          sel.endMinute,
                        ).then((_) => _drag.clearSelection());
                      }
                    }
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
    );
  }
}
