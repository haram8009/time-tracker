import 'dart:typed_data';
import 'dart:ui';

class CellState {
  final Color? categoryColor; // null = 빈 셀
  final List<Uint8List> thumbnails; // 사진 썸네일 (최대 2개)
  final bool isSelected; // 드래그 중 선택 상태

  const CellState({
    this.categoryColor,
    this.thumbnails = const [],
    this.isSelected = false,
  });
}
