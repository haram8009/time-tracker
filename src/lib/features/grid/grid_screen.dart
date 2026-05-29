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
  late final DragSelectionController _drag;

  bool _isDragging = false;
  String _currentDateKey = '';

  static const double _kTimeLabelWidth = 48.0;
  static const double _kCellHeight = 48.0;
  static const double _kExpandedHeight = 192.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _drag = DragSelectionController();
    _drag.addListener(() => setState(() {}));
  }

  int _positionToCellIndex(Offset localPos) {
    final rowIndex = (localPos.dy / _kCellHeight)
        .floor()
        .clamp(0, 23);
    final availableWidth = MediaQuery.of(context).size.width - _kTimeLabelWidth;
    final cellWidth = availableWidth / 6;
    final colIndex = ((localPos.dx - _kTimeLabelWidth) / cellWidth)
        .floor()
        .clamp(0, 5);
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
    final blockStyle = ref.watch(appearanceServiceProvider);

    if (!vmState.dbReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final selectedDate = vmState.selectedDate;
    final blocksAsync = ref.watch(
      timeBlocksStreamProvider(dateKey(selectedDate)),
    );
    final categoriesAsync = ref.watch(categoriesAllStreamProvider);

    const days = ['월', '화', '수', '목', '금', '토', '일'];
    final d = selectedDate;
    final dateLabel =
        '${d.year}년 ${d.month}월 ${d.day}일 (${days[d.weekday - 1]})';

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        physics: _isDragging ? const NeverScrollableScrollPhysics() : null,
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: _kExpandedHeight,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: '이전 날',
              onPressed: () {
                vm.goToPreviousDay();
                _drag.clearSelection();
              },
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
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: kToolbarHeight,
                    left: 16,
                    right: 16,
                    bottom: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isToday(selectedDate)
                            ? '오늘'
                            : '${d.month}월 ${d.day}일 (${days[d.weekday - 1]})',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: blocksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
              data: (dbBlocks) => categoriesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('오류: $e')),
                data: (categories) {
                  final photosAsync = ref.watch(
                    photosForDateProvider(selectedDate),
                  );
                  _currentDateKey = dateKey(selectedDate);
                  final cells = GridViewModel.compute(
                    blocks: dbBlocks,
                    categories: categories,
                    photos: photosAsync.valueOrNull ?? const [],
                    selectedIndices: _drag.selectedIndices,
                  );
                  return SizedBox(
                    height: 24 * _kCellHeight,
                    child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPressStart: _onLongPressStart,
                    onLongPressMoveUpdate: _onLongPressMoveUpdate,
                    onLongPressEnd: _onLongPressEnd,
                    onLongPressCancel: _onLongPressCancel,
                    child: Stack(
                      children: [
                      Column(
                      children: List.generate(24, (rowIndex) {
                        return SizedBox(
                          height: _kCellHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: _kTimeLabelWidth,
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
                                    key: ValueKey(cellIndex),
                                    index: cellIndex,
                                    state: cells[cellIndex],
                                    onTap: _isDragging
                                        ? null
                                        : () {
                                            final existing = vm.blockAtIndex(
                                              cellIndex,
                                              dbBlocks,
                                            );
                                            if (existing != null) {
                                              _drag.clearSelection();
                                              showEditBlockBottomSheet(
                                                context,
                                                ref,
                                                existing,
                                                categories,
                                              );
                                            } else {
                                              _drag.onDragStart(cellIndex);
                                              _drag.onDragEnd();
                                              final sel = _drag.selection;
                                              if (sel != null) {
                                                showCategoryBottomSheet(
                                                  context,
                                                  ref,
                                                  dateKey(selectedDate),
                                                  sel.startMinute,
                                                  sel.endMinute,
                                                ).then(
                                                  (_) =>
                                                      _drag.clearSelection(),
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
                        cellHeight: _kCellHeight,
                        timeLabelWidth: _kTimeLabelWidth,
                      ),
                    ],
                  ),
                    ),
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
