import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/core/logic/drag_selection_reducer.dart';
import 'package:time_tracker/core/models/drag_selection_state.dart';

void main() {
  const empty = DragSelectionState();

  group('dragSelectionReducer', () {
    group('DragStarted', () {
      test('단일 셀 → selection=(0, 10)', () {
        final s = dragSelectionReducer(empty, DragStarted(0));
        expect(s.selection, equals(const DragSelection(startMinute: 0, endMinute: 10)));
        expect(s.dragStartMinute, equals(0));
      });

      test('cellIndex=5 → startMinute=50, endMinute=60', () {
        final s = dragSelectionReducer(empty, DragStarted(5));
        expect(s.selection, equals(const DragSelection(startMinute: 50, endMinute: 60)));
      });

      test('경계: cellIndex=143 → startMinute=1430, endMinute=1440', () {
        final s = dragSelectionReducer(empty, DragStarted(143));
        expect(s.selection!.startMinute, equals(1430));
        expect(s.selection!.endMinute, equals(1440));
      });
    });

    group('DragUpdated', () {
      test('위→아래: start=2, update=5 → (20, 60)', () {
        var s = dragSelectionReducer(empty, DragStarted(2));
        s = dragSelectionReducer(s, DragUpdated(5));
        expect(s.selection, equals(const DragSelection(startMinute: 20, endMinute: 60)));
      });

      test('아래→위: start=5, update=2 → (20, 60)', () {
        var s = dragSelectionReducer(empty, DragStarted(5));
        s = dragSelectionReducer(s, DragUpdated(2));
        expect(s.selection, equals(const DragSelection(startMinute: 20, endMinute: 60)));
      });

      test('dragStartMinute 없으면 no-op', () {
        final s = dragSelectionReducer(empty, DragUpdated(5));
        expect(s, equals(empty));
      });

      test('dragStartMinute 유지', () {
        var s = dragSelectionReducer(empty, DragStarted(3));
        s = dragSelectionReducer(s, DragUpdated(6));
        expect(s.dragStartMinute, equals(30));
      });
    });

    group('DragEnded', () {
      test('selection 유지, dragStartMinute=null', () {
        var s = dragSelectionReducer(empty, DragStarted(2));
        s = dragSelectionReducer(s, DragUpdated(5));
        s = dragSelectionReducer(s, DragEnded());
        expect(s.selection, equals(const DragSelection(startMinute: 20, endMinute: 60)));
        expect(s.dragStartMinute, isNull);
      });
    });

    group('DragCancelled', () {
      test('selection=null, dragStartMinute=null', () {
        var s = dragSelectionReducer(empty, DragStarted(3));
        s = dragSelectionReducer(s, DragUpdated(6));
        s = dragSelectionReducer(s, DragCancelled());
        expect(s.selection, isNull);
        expect(s.dragStartMinute, isNull);
      });
    });

    group('selectedIndices', () {
      test('start=2, end=5 → {2,3,4,5}', () {
        var s = dragSelectionReducer(empty, DragStarted(2));
        s = dragSelectionReducer(s, DragUpdated(5));
        expect(s.selectedIndices, equals({2, 3, 4, 5}));
      });

      test('no selection → empty set', () {
        expect(empty.selectedIndices, isEmpty);
      });
    });
  });
}
