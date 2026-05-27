import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/category_store.dart';
import '../../core/models/category.dart';
import '../../core/models/time_block.dart';
import '../../core/utils/time_utils.dart';
import 'grid_screen_view_model.dart';

const _colorPalette = [
  '#5C6BC0', '#EF5350', '#66BB6A', '#FFA726', '#26C6DA', '#AB47BC',
  '#EC407A', '#26A69A', '#D4E157', '#8D6E63', '#78909C', '#FF7043',
];

Future<void> showCategoryBottomSheet(
  BuildContext context,
  WidgetRef ref,
  String date,
  int startMinute,
  int endMinute,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _CategoryBottomSheet(
      date: date,
      startMinute: startMinute,
      endMinute: endMinute,
    ),
  );
}

class _CategoryBottomSheet extends ConsumerStatefulWidget {
  final String date;
  final int startMinute;
  final int endMinute;

  const _CategoryBottomSheet({
    required this.date,
    required this.startMinute,
    required this.endMinute,
  });

  @override
  ConsumerState<_CategoryBottomSheet> createState() =>
      _CategoryBottomSheetState();
}

class _CategoryBottomSheetState extends ConsumerState<_CategoryBottomSheet> {
  bool _creating = false;
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String _pickColor(List<Category> categories) {
    final used = categories.map((c) => c.colorHex.toUpperCase()).toSet();
    for (final color in _colorPalette) {
      if (!used.contains(color.toUpperCase())) return color;
    }
    return _colorPalette[categories.length % _colorPalette.length];
  }

  Future<void> _confirmCreate(List<Category> categories) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final created = await ref
        .read(categoryStoreProvider)
        .insert(Category(name: name, colorHex: _pickColor(categories)));

    if (!mounted) return;

    await ref.read(gridScreenViewModelProvider.notifier).saveBlock(
          TimeBlock(
            date: widget.date,
            startMinute: widget.startMinute,
            endMinute: widget.endMinute,
            categoryId: created.id!,
          ),
        );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 8 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${formatMinute(widget.startMinute)} – ${formatMinute(widget.endMinute)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '카테고리 선택',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            categoriesAsync.when(
              data: (categories) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CategoryList(
                    categories: categories,
                    hexToColor: hexToColor,
                    onSelect: (category) async {
                      await ref
                          .read(gridScreenViewModelProvider.notifier)
                          .saveBlock(
                            TimeBlock(
                              date: widget.date,
                              startMinute: widget.startMinute,
                              endMinute: widget.endMinute,
                              categoryId: category.id!,
                            ),
                          );
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: 8),
                  if (_creating)
                    _InlineCreateRow(
                      controller: _nameCtrl,
                      onConfirm: () => _confirmCreate(categories),
                      onCancel: () => setState(() {
                        _creating = false;
                        _nameCtrl.clear();
                      }),
                    )
                  else
                    TextButton.icon(
                      onPressed: () => setState(() => _creating = true),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('새 카테고리'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                ],
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text('오류: $e'),
            ),
            const SizedBox(height: 8),
            if (!_creating)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InlineCreateRow extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _InlineCreateRow({
    required this.controller,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_InlineCreateRow> createState() => _InlineCreateRowState();
}

class _InlineCreateRowState extends State<_InlineCreateRow> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: widget.controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: _hasText ? (_) => widget.onConfirm() : null,
            decoration: const InputDecoration(
              hintText: '카테고리 이름',
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.check),
          onPressed: _hasText ? widget.onConfirm : null,
          color: Theme.of(context).colorScheme.primary,
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel,
        ),
      ],
    );
  }
}

class _CategoryList extends StatelessWidget {
  final List<Category> categories;
  final void Function(Category) onSelect;
  final Color Function(String) hexToColor;

  const _CategoryList({
    required this.categories,
    required this.onSelect,
    required this.hexToColor,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((cat) {
        final color = hexToColor(cat.colorHex);
        return InkWell(
          onTap: () => onSelect(cat),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color, width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  cat.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
