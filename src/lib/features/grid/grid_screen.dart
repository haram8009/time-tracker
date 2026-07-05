import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/category_store.dart';
import '../../core/db/time_block_store.dart';
import '../../core/models/date_key.dart';
import '../../core/models/time_block_style.dart';
import '../../core/services/appearance_service.dart';
import '../../core/services/photo_library_service.dart';
import 'category_bottom_sheet.dart';
import 'edit_block_bottom_sheet.dart';
import 'grid_coordinator.dart';
import 'grid_gesture_handler.dart';
import 'grid_screen_view_model.dart';
import 'calendar_modal.dart';
import 'grid_view_model.dart';
import 'week_strip.dart';
import 'widgets/grid_cell.dart';
import 'widgets/drag_selection_overlay.dart';
import 'widgets/photo_thumbnail_overlay.dart';
import 'widgets/time_block_overlay.dart';

class GridScreen extends ConsumerStatefulWidget {
  const GridScreen({super.key});

  @override
  ConsumerState<GridScreen> createState() => _GridScreenState();
}

class _GridScreenState extends ConsumerState<GridScreen> {
  late final GridCoordinator _coordinator;
  late final VoidCallback _rebuild;

  static const double _kTimeLabelWidth = kGridTimeLabelWidth;
  static const double _kCellHeight = kGridCellHeight;

  @override
  void initState() {
    super.initState();

    // Date navigation state and page/scroll orchestration live in the
    // provider-owned coordinator (#98); the widget renders and dispatches.
    _coordinator = ref.read(gridCoordinatorProvider.notifier);
    _coordinator.onSelectionComplete = (date, sel) {
      showCategoryBottomSheet(
        context,
        ref,
        date,
        sel.startMinute,
        sel.endMinute,
      ).then((_) => _coordinator.clearSelection());
    };

    _rebuild = () => setState(() {});
    _coordinator.dragState.addListener(_rebuild);
    _coordinator.isDragging.addListener(_rebuild);
  }

  @override
  void dispose() {
    // The coordinator outlives the screen (provider-owned); only detach.
    _coordinator.dragState.removeListener(_rebuild);
    _coordinator.isDragging.removeListener(_rebuild);
    _coordinator.onSelectionComplete = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _coordinator.gestureHandler.gridSize = MediaQuery.of(context).size;
    _coordinator.updateMetrics(
      screenHeight: MediaQuery.of(context).size.height,
      topPad: MediaQuery.of(context).padding.top + 56,
    );

    final todayPage = DateKey.today().toPage(DateKey.appEpoch);

    final selectedDate = ref.watch(gridCoordinatorProvider);
    final blockStyle = ref.watch(appearanceServiceProvider);
    final isGlass = blockStyle == TimeBlockStyle.liquidGlass;
    final weekStripBg = isGlass
        ? Colors.transparent
        : Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      body: CustomScrollView(
        controller: _coordinator.scrollController,
        physics: _coordinator.isDragging.value
            ? const NeverScrollableScrollPhysics()
            : null,
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            title: CalendarHeaderButton(
              label: '${selectedDate.year}년 ${selectedDate.month}월',
              selectedDate: selectedDate,
              onDateSelected: (date) {
                _coordinator.goToDate(date);
                _coordinator.clearSelection();
              },
            ),
            centerTitle: false,
            actions: [
              if (DateKey.today() != selectedDate)
                TodayResetButton(
                  onPressed: () {
                    _coordinator.goToToday();
                    _coordinator.clearSelection();
                  },
                ),
            ],
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _WeekStripDelegate(
              selectedDate: selectedDate,
              backgroundColor: weekStripBg,
              onDateSelected: (date) {
                _coordinator.goToDate(date);
                _coordinator.clearSelection();
              },
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 24 * _kCellHeight,
              child: PageView.builder(
                controller: _coordinator.pageController,
                itemCount: todayPage + 1,
                onPageChanged: _coordinator.onPageChanged,
                itemBuilder: (context, page) {
                  final pageDate = DateKey.fromPage(page, DateKey.appEpoch);
                  return _GridPage(
                    date: pageDate,
                    isDragging: _coordinator.isDragging.value,
                    dragState: _coordinator.dragState,
                    onClearSelection: _coordinator.clearSelection,
                    onDragStarted: _coordinator.onDragStarted,
                    onDragEnded: _coordinator.onDragEnded,
                    blockStyle: blockStyle,
                    kTimeLabelWidth: _kTimeLabelWidth,
                    kCellHeight: _kCellHeight,
                    gestureHandler: _coordinator.gestureHandler,
                  );
                },
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single page in the PageView — renders the grid for one [date].
class _GridPage extends ConsumerWidget {
  const _GridPage({
    required this.date,
    required this.isDragging,
    required this.dragState,
    required this.onClearSelection,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.blockStyle,
    required this.kTimeLabelWidth,
    required this.kCellHeight,
    required this.gestureHandler,
  });

  final DateKey date;
  final bool isDragging;
  final ValueListenable<DragSelectionState> dragState;
  final VoidCallback onClearSelection;
  final void Function(int) onDragStarted;
  final VoidCallback onDragEnded;
  final dynamic blockStyle;
  final double kTimeLabelWidth;
  final double kCellHeight;
  final GridGestureHandler gestureHandler;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(gridScreenViewModelProvider);
    final blocksAsync = ref.watch(timeBlocksStreamProvider(date));
    final categoriesAsync = ref.watch(categoriesAllStreamProvider);

    return blocksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (dbBlocks) => categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (categories) {
          final photosAsync = ref.watch(photosForDateProvider(date.toDateTime()));
          final cells = GridViewModel.compute(
            blocks: dbBlocks,
            categories: categories,
            photos: photosAsync.valueOrNull ?? const [],
            selectedIndices: dragState.value.selectedIndices,
          );
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPressStart: gestureHandler.handleLongPressStart,
            onLongPressMoveUpdate: gestureHandler.handleLongPressMoveUpdate,
            onLongPressEnd: gestureHandler.handleLongPressEnd,
            onLongPressCancel: gestureHandler.handleLongPressCancel,
            child: Stack(
              children: [
                Column(
                  children: List.generate(24, (rowIndex) {
                    return SizedBox(
                      height: kCellHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: kTimeLabelWidth,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Text(
                                  '${rowIndex.toString().padLeft(2, '0')}:00',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF8E8E93),
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          ...List.generate(6, (col) {
                            final cellIndex = rowIndex * 6 + col;
                            return Expanded(
                              child: GridCell(
                                key: ValueKey('${date.toDbString()}-$cellIndex'),
                                index: cellIndex,
                                state: cells[cellIndex],
                                onTap: isDragging
                                    ? null
                                    : () {
                                        final existing = vm.blockAtIndex(
                                          cellIndex,
                                          dbBlocks,
                                        );
                                        if (existing != null) {
                                          onClearSelection();
                                          showEditBlockBottomSheet(
                                            context,
                                            ref,
                                            existing,
                                            categories,
                                          );
                                        } else {
                                          onDragStarted(cellIndex);
                                          onDragEnded();
                                          final sel = dragState.value.selection;
                                          if (sel != null) {
                                            showCategoryBottomSheet(
                                              context,
                                              ref,
                                              date,
                                              sel.startMinute,
                                              sel.endMinute,
                                            ).then(
                                              (_) => onClearSelection(),
                                            );
                                          }
                                        }
                                      },
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ),
                TimeBlockOverlay(
                  blocks: dbBlocks,
                  categories: categories,
                  style: blockStyle,
                  cellHeight: kCellHeight,
                  timeLabelWidth: kTimeLabelWidth,
                ),
                DragSelectionOverlay(
                  selectedIndices: dragState.value.selectedIndices,
                  cellHeight: kCellHeight,
                  timeLabelWidth: kTimeLabelWidth,
                ),
                PhotoThumbnailOverlay(
                  cells: cells,
                  cellHeight: kCellHeight,
                  timeLabelWidth: kTimeLabelWidth,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── WeekStrip delegate ────────────────────────────────────────────────────────

class _WeekStripDelegate extends SliverPersistentHeaderDelegate {
  const _WeekStripDelegate({
    required this.selectedDate,
    required this.onDateSelected,
    required this.backgroundColor,
  });

  final DateKey selectedDate;
  final void Function(DateKey) onDateSelected;
  final Color backgroundColor;

  @override
  double get minExtent => WeekStrip.height;

  @override
  double get maxExtent => WeekStrip.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: backgroundColor,
      child: WeekStrip(
        selectedDate: selectedDate,
        onDateSelected: onDateSelected,
      ),
    );
  }

  @override
  bool shouldRebuild(_WeekStripDelegate old) =>
      selectedDate != old.selectedDate || backgroundColor != old.backgroundColor;
}
