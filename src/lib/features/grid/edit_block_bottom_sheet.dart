import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/time_block_store.dart';
import '../../core/models/category.dart';
import '../../core/models/time_block.dart';
import '../../core/utils/time_utils.dart';
import 'grid_screen_view_model.dart';

Future<void> showEditBlockBottomSheet(
  BuildContext context,
  WidgetRef ref,
  TimeBlock block,
  List<Category> categories,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _EditBlockBottomSheet(
      ref: ref,
      block: block,
      categories: categories,
    ),
  );
}

class _EditBlockBottomSheet extends StatefulWidget {
  final WidgetRef ref;
  final TimeBlock block;
  final List<Category> categories;

  const _EditBlockBottomSheet({
    required this.ref,
    required this.block,
    required this.categories,
  });

  @override
  State<_EditBlockBottomSheet> createState() => _EditBlockBottomSheetState();
}

class _EditBlockBottomSheetState extends State<_EditBlockBottomSheet> {
  bool _showCategoryPicker = false;

  Category? get _currentCategory {
    try {
      return widget.categories.firstWhere((c) => c.id == widget.block.categoryId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = _currentCategory;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
              '${formatMinute(widget.block.startMinute)} – ${formatMinute(widget.block.endMinute)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (cat != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: hexToColor(cat.colorHex),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cat.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (_showCategoryPicker) ...[
              Text(
                '카테고리 변경',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.categories.map((c) {
                  final color = hexToColor(c.colorHex);
                  return InkWell(
                    onTap: () async {
                      await widget.ref
                          .read(gridScreenViewModelProvider.notifier)
                          .saveBlock(
                            widget.block.copyWith(categoryId: c.id),
                          );
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        border: Border.all(color: color, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(c.name,
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ] else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _showCategoryPicker = true),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('수정'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final id = widget.block.id;
                        if (id != null) {
                          await widget.ref
                              .read(timeBlockStoreProvider)
                              .delete(id);
                        }
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('삭제'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
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
