import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/core/db/category_store.dart';
import 'package:time_tracker/core/db/time_block_store.dart';
import 'package:time_tracker/core/models/category.dart';
import 'package:time_tracker/core/models/date_key.dart';
import 'package:time_tracker/core/models/photo_asset.dart';
import 'package:time_tracker/core/models/time_block.dart';
import 'package:time_tracker/core/services/photo_library_service.dart';
import 'package:time_tracker/features/grid/grid_view_model.dart';

const _date = DateKey(2026, 7, 1);

final _block = TimeBlock(
  date: _date,
  startMinute: 0,
  endMinute: 60,
  categoryId: 1,
);

const _category = Category(id: 1, name: '업무', colorHex: '#EF5350');

final _photo = PhotoAsset(
  takenMinute: 30,
  thumbnailBytes: Uint8List.fromList([1, 2, 3]),
);

ProviderContainer _container({
  Stream<List<TimeBlock>>? blocks,
  Stream<List<Category>>? categories,
  bool photosFail = false,
}) =>
    ProviderContainer(overrides: [
      timeBlocksStreamProvider.overrideWith(
          (ref, date) => blocks ?? Stream.value([_block])),
      categoriesAllStreamProvider
          .overrideWith((ref) => categories ?? Stream.value([_category])),
      photosForDateProvider.overrideWith((ref, date) async {
        if (photosFail) throw StateError('사진 접근 거부');
        return [_photo];
      }),
    ]);

void main() {
  test('blocks+categories+photos 도착 → 단일 AsyncData로 합성', () async {
    final container = _container();
    addTearDown(container.dispose);

    await container.read(timeBlocksStreamProvider(_date).future);
    await container.read(categoriesAllStreamProvider.future);
    await container.read(photosForDateProvider(_date.toDateTime()).future);

    final data = container.read(gridPageDataProvider(_date)).requireValue;
    expect(data.blocks.single.startMinute, 0);
    expect(data.categories.single.name, '업무');
    expect(data.photos.single.takenMinute, 30);
  });

  test('photos 실패 → 그리드는 뜨고 photos만 빈 리스트로 강등', () async {
    final container = _container(photosFail: true);
    addTearDown(container.dispose);

    await container.read(timeBlocksStreamProvider(_date).future);
    await container.read(categoriesAllStreamProvider.future);
    await container
        .read(photosForDateProvider(_date.toDateTime()).future)
        .catchError((_) => <PhotoAsset>[]);

    final data = container.read(gridPageDataProvider(_date)).requireValue;
    expect(data.blocks, isNotEmpty);
    expect(data.photos, isEmpty);
  });

  test('blocks 에러 → AsyncError 전파', () async {
    final container =
        _container(blocks: Stream.error(StateError('db 실패')));
    addTearDown(container.dispose);

    await expectLater(
        container.read(timeBlocksStreamProvider(_date).future), throwsStateError);

    expect(container.read(gridPageDataProvider(_date)).hasError, isTrue);
  });

  test('categories 아직 로딩 → AsyncLoading', () async {
    final container =
        _container(categories: const Stream.empty(broadcast: true));
    addTearDown(container.dispose);

    await container.read(timeBlocksStreamProvider(_date).future);

    expect(container.read(gridPageDataProvider(_date)).isLoading, isTrue);
  });
}
