import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/features/grid/grid_view_model.dart';
import 'package:time_tracker/core/models/category.dart';
import 'package:time_tracker/core/models/date_key.dart';
import 'package:time_tracker/core/models/time_block.dart';
import 'package:time_tracker/core/models/photo_asset.dart';

void main() {
  const cat1 = Category(id: 1, name: 'Work', colorHex: '#FF0000');
  const cat2 = Category(id: 2, name: 'Rest', colorHex: '#0000FF');

  TimeBlock block({
    required int start,
    required int end,
    int categoryId = 1,
  }) =>
      TimeBlock(
        date: DateKey(2026, 5, 27),
        startMinute: start,
        endMinute: end,
        categoryId: categoryId,
      );

  group('GridViewModel.compute', () {
    test('빈 입력 → 144개 전부 빈 CellState', () {
      final cells = GridViewModel.compute(
        blocks: [],
        categories: [],
        photos: [],
        selectedIndices: {},
      );
      expect(cells.length, 144);
      expect(cells.every((c) => c.categoryColor == null), isTrue);
      expect(cells.every((c) => c.thumbnails.isEmpty), isTrue);
      expect(cells.every((c) => !c.isSelected), isTrue);
    });

    test('블록 1개 → categoryColor는 항상 null (오버레이로 이동)', () {
      // Color rendering moved to TimeBlockOverlay; CellState.categoryColor is always null
      final cells = GridViewModel.compute(
        blocks: [block(start: 0, end: 10)],
        categories: [cat1],
        photos: [],
        selectedIndices: {},
      );
      expect(cells[0].categoryColor, isNull);
      expect(cells[1].categoryColor, isNull);
    });

    test('블록 경계 — categoryColor는 항상 null (오버레이로 이동)', () {
      final cells = GridViewModel.compute(
        blocks: [block(start: 10, end: 20)],
        categories: [cat1],
        photos: [],
        selectedIndices: {},
      );
      expect(cells[0].categoryColor, isNull);
      expect(cells[1].categoryColor, isNull);
      expect(cells[2].categoryColor, isNull);
    });

    test('블록 걸침 — categoryColor는 항상 null (오버레이로 이동)', () {
      final cells = GridViewModel.compute(
        blocks: [block(start: 0, end: 30)],
        categories: [cat1],
        photos: [],
        selectedIndices: {},
      );
      expect(cells.every((c) => c.categoryColor == null), isTrue);
    });

    test('겹침 블록 → categoryColor는 항상 null (오버레이로 이동)', () {
      final cells = GridViewModel.compute(
        blocks: [
          block(start: 0, end: 10, categoryId: 1),
          block(start: 0, end: 10, categoryId: 2),
        ],
        categories: [cat1, cat2],
        photos: [],
        selectedIndices: {},
      );
      expect(cells[0].categoryColor, isNull);
    });

    test('카테고리 없는 블록 → 셀 color null', () {
      final cells = GridViewModel.compute(
        blocks: [block(start: 0, end: 10, categoryId: 99)],
        categories: [cat1],
        photos: [],
        selectedIndices: {},
      );
      expect(cells[0].categoryColor, isNull);
    });

    test('사진 → takenMinute 셀에 thumbnail', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final cells = GridViewModel.compute(
        blocks: [],
        categories: [],
        photos: [PhotoAsset(takenMinute: 60, thumbnailBytes: bytes)],
        selectedIndices: {},
      );
      // takenMinute=60 → index 6
      expect(cells[6].thumbnails.length, 1);
      expect(cells[6].thumbnails[0], bytes);
      expect(cells[7].thumbnails, isEmpty);
    });

    test('사진 최대 2개 — 3번째 이후 무시', () {
      final b1 = Uint8List.fromList([1]);
      final b2 = Uint8List.fromList([2]);
      final b3 = Uint8List.fromList([3]);
      final cells = GridViewModel.compute(
        blocks: [],
        categories: [],
        photos: [
          PhotoAsset(takenMinute: 0, thumbnailBytes: b1),
          PhotoAsset(takenMinute: 0, thumbnailBytes: b2),
          PhotoAsset(takenMinute: 0, thumbnailBytes: b3),
        ],
        selectedIndices: {},
      );
      expect(cells[0].thumbnails.length, 2);
      expect(cells[0].thumbnails[0], b1);
      expect(cells[0].thumbnails[1], b2);
    });

    test('selectedIndices → isSelected=true', () {
      final cells = GridViewModel.compute(
        blocks: [],
        categories: [],
        photos: [],
        selectedIndices: {0, 5, 143},
      );
      expect(cells[0].isSelected, isTrue);
      expect(cells[5].isSelected, isTrue);
      expect(cells[143].isSelected, isTrue);
      expect(cells[1].isSelected, isFalse);
      expect(cells[142].isSelected, isFalse);
    });

    test('minuteToIndex / indexToMinute 왕복', () {
      for (var i = 0; i < 144; i++) {
        expect(GridViewModel.minuteToIndex(GridViewModel.indexToMinute(i)), i);
      }
    });

    test('RetiredCategory(isHidden=true) 블록 → categoryColor null (오버레이로 이동)', () {
      const retiredCat = Category(
        id: 3,
        name: '퇴직카테고리',
        colorHex: '#AABBCC',
        isHidden: true,
      );
      final cells = GridViewModel.compute(
        blocks: [
          const TimeBlock(
            date: DateKey(2026, 5, 27),
            startMinute: 0,
            endMinute: 10,
            categoryId: 3,
          )
        ],
        categories: [retiredCat],
        photos: [],
        selectedIndices: {},
      );
      expect(cells[0].categoryColor, isNull);
    });
  });
}
