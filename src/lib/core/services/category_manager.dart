import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/category_store.dart';
import '../db/time_block_store.dart';

class CategoryManager {
  const CategoryManager({
    required this.categoryStore,
    required this.timeBlockStore,
  });

  final CategoryStore categoryStore;
  final TimeBlockStore timeBlockStore;

  Future<void> deleteCategory(int id, {required bool keepRecords}) async {
    if (keepRecords) {
      await categoryStore.retire(id);
    } else {
      await categoryStore.deleteWithRecords(id);
    }
  }
}

final categoryManagerProvider = Provider<CategoryManager>((ref) {
  return CategoryManager(
    categoryStore: ref.watch(categoryStoreProvider),
    timeBlockStore: ref.watch(timeBlockStoreProvider),
  );
});
