import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/category_store.dart';
import '../../core/db/database_helper.dart';
import '../../core/db/time_block_store.dart';
import '../../core/models/category.dart';
import '../../core/models/time_block.dart' as db;
import '../../core/services/photo_library_service.dart';
import 'category_bottom_sheet.dart';
import 'drag_selection_controller.dart';
import 'edit_block_bottom_sheet.dart';
import 'grid_view_model.dart';
import 'widgets/grid_cell.dart';

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class GridScreen extends ConsumerStatefulWidget {
  const GridScreen({super.key});

  @override
  ConsumerState<GridScreen> createState() => _GridScreenState();
}

class _GridScreenState extends ConsumerState<GridScreen> {
  late final ScrollController _scrollController;
  late final DragSelectionController _drag;
  DateTime _selectedDate = DateTime.now();
  bool _dbReady = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _drag = DragSelectionController();
    _drag.addListener(() => setState(() {}));
    _initDb();
  }

  Future<void> _initDb() async {
    await DatabaseHelper.instance.database;
    await ref.read(categoryStoreProvider).seedIfNeeded();
    if (mounted) {
      setState(() => _dbReady = true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
    }
  }

  void _scrollToNow() {
    final now = DateTime.now();
    final idx = GridViewModel.minuteToIndex(now.hour * 60 + now.minute);
    const cellH = 32.0;
    final screenH = MediaQuery.of(context).size.height;
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight;
    final offset = (idx * cellH - (screenH - topPad) / 2).clamp(0.0, double.infinity);
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  String get _dateLabel {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    final d = _selectedDate;
    return '${d.year}년 ${d.month}월 ${d.day}일 (${days[d.weekday - 1]})';
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  db.TimeBlock? _blockAtIndex(int index, List<db.TimeBlock> blocks) {
    final cellStart = GridViewModel.indexToMinute(index);
    final cellEnd = cellStart + 10;
    for (final b in blocks) {
      if (b.startMinute < cellEnd && b.endMinute > cellStart) return b;
    }
    return null;
  }

  void _onCellTap(
    int index,
    List<db.TimeBlock> dbBlocks,
    List<Category> categories,
  ) {
    final existing = _blockAtIndex(index, dbBlocks);
    if (existing != null) {
      _drag.clearSelection();
      showEditBlockBottomSheet(context, ref, existing, categories);
    } else {
      _drag.onDragStart(index);
      _drag.onDragEnd();
      final sel = _drag.selection;
      if (sel != null) {
        showCategoryBottomSheet(
          context,
          ref,
          _dateKey(_selectedDate),
          sel.startMinute,
          sel.endMinute,
        ).then((_) => _drag.clearSelection());
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _drag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_dbReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final blocksAsync = ref.watch(timeBlocksStreamProvider(_dateKey(_selectedDate)));
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: '이전 날',
          onPressed: () => setState(() {
            _selectedDate = _selectedDate.subtract(const Duration(days: 1));
            _drag.clearSelection();
          }),
        ),
        title: Text(
          _dateLabel,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: '다음 날',
            onPressed: () => setState(() {
              _selectedDate = _selectedDate.add(const Duration(days: 1));
              _drag.clearSelection();
            }),
          ),
        ],
        centerTitle: true,
      ),
      body: blocksAsync.when(
        data: (dbBlocks) => categoriesAsync.when(
          data: (categories) {
            final photosAsync = ref.watch(photosForDateProvider(_selectedDate));
            final colorMap = {for (final c in categories) c.id!: _hexToColor(c.colorHex)};
            final vmBlocks = dbBlocks
                .where((b) => colorMap.containsKey(b.categoryId))
                .map((b) => TimeBlock(
                      startMinute: b.startMinute,
                      endMinute: b.endMinute,
                      categoryColor: colorMap[b.categoryId]!,
                    ))
                .toList();

            final cells = GridViewModel.compute(
              blocks: vmBlocks,
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
                onTap: () => _onCellTap(index, dbBlocks, categories),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('오류: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
    );
  }
}
