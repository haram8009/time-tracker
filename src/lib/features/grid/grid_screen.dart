import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/category_store.dart';
import '../../core/db/time_block_store.dart';
import '../../core/logic/grid_layout_calculator.dart';
import '../../core/models/date_key.dart';
import '../../core/models/time_block_style.dart';
import '../../core/services/appearance_service.dart';
import '../../core/services/photo_library_service.dart';
import 'category_bottom_sheet.dart';
import 'drag_selection_controller.dart';
import 'edit_block_bottom_sheet.dart';
import 'grid_gesture_handler.dart';
import 'grid_screen_view_model.dart';
import 'calendar_modal.dart';
import 'grid_view_model.dart';
import 'week_strip.dart';
import 'widgets/grid_cell.dart';
import 'widgets/time_block_overlay.dart';

class GridScreen extends ConsumerStatefulWidget {
  const GridScreen({super.key});

  @override
  ConsumerState<GridScreen> createState() => _GridScreenState();
}

class _GridScreenState extends ConsumerState<GridScreen> {
  late final ScrollController _scrollController;
  late final PageController _pageController;
  late final DragSelectionController _drag;
  late final GridLayoutCalculator _calculator;
  late final GridGestureHandler _gestureHandler;

  bool _isDragging = false;
  bool _isProgrammaticJump = false;
  DateKey _currentDateKey = DateKey.today();

  static const double _kTimeLabelWidth = 48.0;
  static const double _kCellHeight = 48.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _drag = DragSelectionController();
    _drag.addListener(() => setState(() {}));

    _calculator = const GridLayoutCalculator(
      columnCount: 6,
      cellHeight: _kCellHeight,
      timeLabelWidth: _kTimeLabelWidth,
    );

    _gestureHandler = GridGestureHandler(
      calculator: _calculator,
      drag: _drag,
      onDraggingChanged: (v) => setState(() => _isDragging = v),
      onSelectionComplete: (sel) => showCategoryBottomSheet(
        context,
        ref,
        _currentDateKey,
        sel.startMinute,
        sel.endMinute,
      ).then((_) => _drag.clearSelection()),
      onSelectionCancelled: () {},
    );

    final initialPage = DateKey.today().toPage(DateKey.appEpoch);
    _pageController = PageController(initialPage: initialPage);
  }

  void _scrollToNow() {
    if (!_scrollController.hasClients) return;
    final now = DateTime.now();
    final idx = GridViewModel.minuteToIndex(now.hour * 60 + now.minute);
    final screenH = MediaQuery.of(context).size.height;
    final topPad = MediaQuery.of(context).padding.top + 56;
    final offset = _calculator.scrollTargetForIndex(idx, screenH, topPad);
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

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    _drag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _gestureHandler.gridSize = MediaQuery.of(context).size;

    final todayPage = DateKey.today().toPage(DateKey.appEpoch);

    // Sync PageController when selectedDate changes externally (e.g. WeekStrip, CalendarModal)
    ref.listen<GridScreenState>(gridScreenViewModelProvider, (prev, next) {
      if (prev?.dbReady == false && next.dbReady == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
      } else if (prev?.selectedDate != next.selectedDate) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (DateKey.today() == next.selectedDate) {
            _scrollToNow();
          } else {
            _scrollToTop();
          }

          // Sync PageView to externally-driven date change
          final targetPage = next.selectedDate.toPage(DateKey.appEpoch);
          if (_pageController.hasClients &&
              _pageController.page?.round() != targetPage) {
            _isProgrammaticJump = true;
            _pageController.jumpToPage(targetPage);
          }
        });
      }
    });

    final vmState = ref.watch(gridScreenViewModelProvider);
    final vm = ref.read(gridScreenViewModelProvider.notifier);
    final blockStyle = ref.watch(appearanceServiceProvider);

    if (!vmState.dbReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final selectedDate = vmState.selectedDate;
    final isGlass = blockStyle == TimeBlockStyle.liquidGlass;
    final weekStripBg = isGlass
        ? Colors.transparent
        : Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        physics: _isDragging ? const NeverScrollableScrollPhysics() : null,
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            title: TextButton(
              onPressed: () => showCalendarModal(
                context: context,
                selectedDate: selectedDate,
                onDateSelected: (date) {
                  vm.goToDate(date);
                  _drag.clearSelection();
                },
              ),
              child: Text(
                '${selectedDate.year}년 ${selectedDate.month}월',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            centerTitle: false,
            actions: [
              if (DateKey.today() != selectedDate)
                TextButton(
                  onPressed: () {
                    vm.goToToday();
                    _drag.clearSelection();
                  },
                  child: const Text('오늘', style: TextStyle(fontSize: 14)),
                ),
            ],
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _WeekStripDelegate(
              selectedDate: selectedDate,
              backgroundColor: weekStripBg,
              onDateSelected: (date) {
                vm.goToDate(date);
                _drag.clearSelection();
              },
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 24 * _kCellHeight,
              child: PageView.builder(
                controller: _pageController,
                itemCount: todayPage + 1,
                onPageChanged: (page) {
                  if (_isProgrammaticJump) {
                    _isProgrammaticJump = false;
                    return;
                  }
                  final date = DateKey.fromPage(page, DateKey.appEpoch);
                  vm.goToDate(date);
                  _drag.clearSelection();
                },
                itemBuilder: (context, page) {
                  final pageDate = DateKey.fromPage(page, DateKey.appEpoch);
                  return _GridPage(
                    date: pageDate,
                    isDragging: _isDragging,
                    drag: _drag,
                    blockStyle: blockStyle,
                    kTimeLabelWidth: _kTimeLabelWidth,
                    kCellHeight: _kCellHeight,
                    onCurrentDateKey: (key) => _currentDateKey = key,
                    onLongPressStart: _gestureHandler.handleLongPressStart,
                    onLongPressMoveUpdate: _gestureHandler.handleLongPressMoveUpdate,
                    onLongPressEnd: _gestureHandler.handleLongPressEnd,
                    onLongPressCancel: _gestureHandler.handleLongPressCancel,
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
    required this.drag,
    required this.blockStyle,
    required this.kTimeLabelWidth,
    required this.kCellHeight,
    required this.onCurrentDateKey,
    required this.onLongPressStart,
    required this.onLongPressMoveUpdate,
    required this.onLongPressEnd,
    required this.onLongPressCancel,
  });

  final DateKey date;
  final bool isDragging;
  final DragSelectionController drag;
  final dynamic blockStyle;
  final double kTimeLabelWidth;
  final double kCellHeight;
  final ValueChanged<DateKey> onCurrentDateKey;
  final GestureLongPressStartCallback onLongPressStart;
  final GestureLongPressMoveUpdateCallback onLongPressMoveUpdate;
  final GestureLongPressEndCallback onLongPressEnd;
  final VoidCallback onLongPressCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(gridScreenViewModelProvider.notifier);
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
          onCurrentDateKey(date);
          final cells = GridViewModel.compute(
            blocks: dbBlocks,
            categories: categories,
            photos: photosAsync.valueOrNull ?? const [],
            selectedIndices: drag.selectedIndices,
          );
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPressStart: onLongPressStart,
            onLongPressMoveUpdate: onLongPressMoveUpdate,
            onLongPressEnd: onLongPressEnd,
            onLongPressCancel: onLongPressCancel,
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
                                          drag.clearSelection();
                                          showEditBlockBottomSheet(
                                            context,
                                            ref,
                                            existing,
                                            categories,
                                          );
                                        } else {
                                          drag.onDragStart(cellIndex);
                                          drag.onDragEnd();
                                          final sel = drag.selection;
                                          if (sel != null) {
                                            showCategoryBottomSheet(
                                              context,
                                              ref,
                                              date,
                                              sel.startMinute,
                                              sel.endMinute,
                                            ).then(
                                              (_) => drag.clearSelection(),
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
              ],
            ),
          );
        },
      ),
    );
  }
}

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
