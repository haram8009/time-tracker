import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/features/grid/drag_selection_controller.dart';

void main() {
  late DragSelectionController controller;

  setUp(() {
    controller = DragSelectionController();
  });

  tearDown(() {
    controller.dispose();
  });

  group('DragSelectionController', () {
    test('단일 셀 탭 (dragStart + dragEnd): cellIndex=0 → selection=(0, 10)', () {
      controller.onDragStart(0);
      controller.onDragEnd();

      expect(controller.selection, isNotNull);
      expect(controller.selection!.startMinute, equals(0));
      expect(controller.selection!.endMinute, equals(10));
    });

    test('여러 셀 위→아래 드래그: cellIndex 2→5 → startMinute=20, endMinute=60', () {
      controller.onDragStart(2);
      controller.onDragUpdate(5);
      controller.onDragEnd();

      expect(controller.selection, isNotNull);
      expect(controller.selection!.startMinute, equals(20));
      expect(controller.selection!.endMinute, equals(60));
    });

    test('여러 셀 아래→위 드래그: cellIndex 5→2 → startMinute=20, endMinute=60 (순서 무관)', () {
      controller.onDragStart(5);
      controller.onDragUpdate(2);
      controller.onDragEnd();

      expect(controller.selection, isNotNull);
      expect(controller.selection!.startMinute, equals(20));
      expect(controller.selection!.endMinute, equals(60));
    });

    test('dragCancel → selection null', () {
      controller.onDragStart(3);
      controller.onDragUpdate(6);
      controller.onDragCancel();

      expect(controller.selection, isNull);
    });

    test('clearSelection → selection null', () {
      controller.onDragStart(3);
      controller.onDragEnd();
      expect(controller.selection, isNotNull);

      controller.clearSelection();
      expect(controller.selection, isNull);
    });

    test('selectedIndices 정확성: startMinute=20, endMinute=60 → {2,3,4,5}', () {
      controller.onDragStart(2);
      controller.onDragUpdate(5);
      controller.onDragEnd();

      expect(controller.selectedIndices, equals({2, 3, 4, 5}));
    });

    test('경계값: cellIndex=0 → startMinute=0', () {
      controller.onDragStart(0);
      controller.onDragEnd();

      expect(controller.selection!.startMinute, equals(0));
    });

    test('경계값: cellIndex=143 → endMinute=1440', () {
      controller.onDragStart(143);
      controller.onDragEnd();

      expect(controller.selection!.endMinute, equals(1440));
    });
  });
}
