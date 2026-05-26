import 'dart:math';
import 'package:flutter/foundation.dart';

class DragSelection {
  final int startMinute; // 10분 단위
  final int endMinute; // 10분 단위, startMinute보다 항상 큼

  const DragSelection({
    required this.startMinute,
    required this.endMinute,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DragSelection &&
          runtimeType == other.runtimeType &&
          startMinute == other.startMinute &&
          endMinute == other.endMinute;

  @override
  int get hashCode => startMinute.hashCode ^ endMinute.hashCode;

  @override
  String toString() =>
      'DragSelection(startMinute: $startMinute, endMinute: $endMinute)';
}

class DragSelectionController extends ChangeNotifier {
  DragSelection? _selection;
  int? _dragStartMinute;

  /// 현재 선택 범위 (null = 선택 없음)
  DragSelection? get selection => _selection;

  /// 선택된 셀 인덱스 집합
  Set<int> get selectedIndices {
    if (_selection == null) return {};
    final start = _selection!.startMinute ~/ 10;
    final end = _selection!.endMinute ~/ 10;
    return Set<int>.from(List.generate(end - start, (i) => start + i));
  }

  /// 드래그 시작: cellIndex (0-143)
  void onDragStart(int cellIndex) {
    _dragStartMinute = _snapToGrid(cellIndex * 10);
    _updateSelection(cellIndex);
  }

  /// 드래그 중: cellIndex
  void onDragUpdate(int cellIndex) {
    if (_dragStartMinute == null) return;
    _updateSelection(cellIndex);
  }

  /// 드래그 종료 → selection 확정
  void onDragEnd() {
    _dragStartMinute = null;
    notifyListeners();
  }

  /// 드래그 취소 (스크롤 등) → selection null로
  void onDragCancel() {
    _dragStartMinute = null;
    _selection = null;
    notifyListeners();
  }

  /// 선택 초기화 (바텀시트 닫힌 후)
  void clearSelection() {
    _selection = null;
    _dragStartMinute = null;
    notifyListeners();
  }

  void _updateSelection(int currentCellIndex) {
    if (_dragStartMinute == null) return;
    final currentMinute = _snapToGrid(currentCellIndex * 10);
    final a = _dragStartMinute!;
    final b = currentMinute;
    _selection = DragSelection(
      startMinute: min(a, b),
      endMinute: max(a, b) + 10,
    );
    notifyListeners();
  }

  int _snapToGrid(int minute) => (minute ~/ 10) * 10;
}
