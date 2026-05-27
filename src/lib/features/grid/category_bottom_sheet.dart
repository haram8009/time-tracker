import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/category_store.dart';
import '../../core/models/category.dart';
import '../../core/models/time_block.dart';
import '../../core/utils/time_utils.dart';
import 'grid_screen_view_model.dart';

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
      ref: ref,
      date: date,
      startMinute: startMinute,
      endMinute: endMinute,
    ),
  );
}

class _CategoryBottomSheet extends StatelessWidget {
  final WidgetRef ref;
  final String date;
  final int startMinute;
  final int endMinute;

  const _CategoryBottomSheet({
    required this.ref,
    required this.date,
    required this.startMinute,
    required this.endMinute,
  });

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);

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
              '${formatMinute(startMinute)} – ${formatMinute(endMinute)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '카테고리 선택',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            categoriesAsync.when(
              data: (categories) => _CategoryList(
                categories: categories,
                hexToColor: hexToColor,
                onSelect: (category) async {
                  await ref.read(gridScreenViewModelProvider.notifier).saveBlock(
                        TimeBlock(
                          date: date,
                          startMinute: startMinute,
                          endMinute: endMinute,
                          categoryId: category.id!,
                        ),
                      );
                  if (context.mounted) Navigator.of(context).pop();
                },
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
