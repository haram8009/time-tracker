import 'dart:typed_data';

class PhotoAsset {
  final int takenMinute; // 자정 기준 분, 10분 단위 스냅
  final Uint8List thumbnailBytes;

  const PhotoAsset({
    required this.takenMinute,
    required this.thumbnailBytes,
  });
}
