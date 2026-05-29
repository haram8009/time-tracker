import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/category_store.dart';
import '../../core/db/time_block_store.dart';
import '../../core/services/appearance_service.dart';
import '../../core/services/photo_library_service.dart';
import '../../core/utils/time_utils.dart';
import 'category_bottom_sheet.dart';
import 'drag_selection_controller.dart';
import 'edit_block_bottom_sheet.dart';
import 'grid_screen_view_model.dart';
import 'grid_view_model.dart';
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

  bool _isDragging = false;
  bool _isProgrammaticJump = false;
  String _currentDateKey = '';

  static const double _kTimeLabelWidth = 48.0;
  static const double _kCellHeight = 48.0;

  static final DateTime _epoch = DateTime(2020, 1, 1);

  int _dateToPage(DateTime d) =>
      DateTime(d.year, d.month, d.day).difference(_epoch).inDays;

  DateTime _pageToDate(int page) => _epoch.add(Duration(days: page));

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _drag = DragSelectionController();
    _drag.addListener(() => setState(() {}));

    final initialDate = DateTime.now();
    _pageController = PageController(initialPage: _dateToPage(initialDate));
  }

  int _positionToCellIndex(Offset localPos) {
    final rowIndex = (localPos.dy / _kCellHeight).floor().clamp(0, 23);
    final availableWidth = MediaQuery.of(context).size.width - _kTimeLabelWidth;
    final cellWidth = availableWidth / 6;
    final colIndex =
        ((localPos.dx - _kTimeLabelWidth) / cellWidth).floor().clamp(0, 5);
    return (rowIndex * 6 + colIndex).clamp(0, 143);
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (details.localPosition.dx < _kTimeLabelWidth) return;
    HapticFeedback.mediumImpact();
    _drag.onDragStart(_positionToCellIndex(details.localPosition));
    setState(() => _isDragging = true);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_isDragging) return;
    _drag.onDragUpdate(_positionToCellIndex(details.localPosition));
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (!_isDragging) return;
    _drag.onDragEnd();
    setState(() => _isDragging = false);
    final sel = _drag.selection;
    if (sel != null) {
      showCategoryBottomSheet(
        context,
        ref,
        _currentDateKey,
        sel.startMinute,
        sel.endMinute,
      ).then((_) => _drag.clearSelection());
    }
  }

  void _onLongPressCancel() {
    if (_isDragging) {
      _drag.onDragCancel();
      setState(() => _isDragging = false);
    }
  }

  void _scrollToNow() {
    if (!_scrollController.hasClients) return;
    final now = DateTime.now();
    final idx = GridViewModel.minuteToIndex(now.hour * 60 + now.minute);
    final rowIndex = idx ~/ 6;
    final screenH = MediaQuery.of(context).size.height;
    final topPad = MediaQuery.of(context).padding.top + 56;
    final offset = (rowIndex * _kCellHeight - (screenH - topPad) / 2).clamp(
      0.0,
      double.infinity,
    );
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
    _pageController.dispose();
    _drag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayPage = _dateToPage(today);

    // Sync PageController when selectedDate changes externally (e.g. WeekStrip, CalendarModal)
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

          // Sync PageView to externally-driven date change
          final targetPage = _dateToPage(next.selectedDate);
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
              onPressed: () {
                // TODO: Open CalendarModal (#58)
              },
              child: Text(
                '${selectedDate.year}년 ${selectedDate.month}월',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            centerTitle: false,
            actions: [
              if (!_isToday(selectedDate))
                TextButton(
                  onPressed: () {
                    vm.goToToday();
                    _drag.clearSelection();
                  },
                  child: const Text('오늘', style: TextStyle(fontSize: 14)),
                ),
            ],
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
                  final date = _pageToDate(page);
                  vm.goToDate(date);
                  _drag.clearSelection();
                },
                itemBuilder: (context, page) {
                  final pageDate = _pageToDate(page);
                  return _GridPage(
                    date: pageDate,
                    isDragging: _isDragging,
                    drag: _drag,
                    blockStyle: blockStyle,
                    kTimeLabelWidth: _kTimeLabelWidth,
                    kCellHeight: _kCellHeight,
                    onCurrentDateKey: (key) => _currentDateKey = key,
                    onLongPressStart: _onLongPressStart,
                    onLongPressMoveUpdate: _onLongPressMoveUpdate,
                    onLongPressEnd: _onLongPressEnd,
                    onLongPressCancel: _onLongPressCancel,
                  );
                },
              ),
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

  final DateTime date;
  final bool isDragging;
  final DragSelectionController drag;
  final dynamic blockStyle;
  final double kTimeLabelWidth;
  final double kCellHeight;
  final ValueChanged<String> onCurrentDateKey;
  final GestureLongPressStartCallback onLongPressStart;
  final GestureLongPressMoveUpdateCallback onLongPressMoveUpdate;
  final GestureLongPressEndCallback onLongPressEnd;
  final VoidCallback onLongPressCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(gridScreenViewModelProvider.notifier);
    final blocksAsync = ref.watch(timeBlocksStreamProvider(dateKey(date)));
    final categoriesAsync = ref.watch(categoriesAllStreamProvider);

    return blocksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (dbBlocks) => categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (categories) {
          final photosAsync = ref.watch(photosForDateProvider(date));
          onCurrentDateKey(dateKey(date));
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
                                key: ValueKey('${dateKey(date)}-$cellIndex'),
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
                                              dateKey(date),
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
