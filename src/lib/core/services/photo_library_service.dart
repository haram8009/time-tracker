import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/photo_asset.dart';
import 'real_photo_data_source.dart';

typedef ThumbnailLoader = Future<Uint8List?> Function(ThumbnailSize size);

class RawPhotoInfo {
  final String id;
  final DateTime takenAt;
  final ThumbnailLoader loadThumb;

  const RawPhotoInfo({
    required this.id,
    required this.takenAt,
    required this.loadThumb,
  });
}

abstract class PhotoDataSource {
  Future<PermissionState> requestPermission();
  Future<List<RawPhotoInfo>> photosForDate(DateTime date);
}

class PhotoLibraryService {
  final PhotoDataSource _src;
  final Map<String, Uint8List> _cache = {};

  PhotoLibraryService(this._src);

  Future<List<PhotoAsset>> fetchForDate(DateTime date) async {
    final ps = await _src.requestPermission();
    if (!ps.hasAccess) return [];

    final rawPhotos = await _src.photosForDate(date);
    final result = <PhotoAsset>[];

    for (final raw in rawPhotos) {
      final minute =
          ((raw.takenAt.hour * 60 + raw.takenAt.minute) ~/ 10) * 10;

      Uint8List? bytes;
      if (_cache.containsKey(raw.id)) {
        bytes = _cache[raw.id];
      } else {
        bytes = await raw.loadThumb(const ThumbnailSize(64, 64));
        if (bytes != null) _cache[raw.id] = bytes;
      }

      if (bytes != null) {
        result.add(PhotoAsset(takenMinute: minute, thumbnailBytes: bytes));
      }
    }

    return result;
  }

  void clearCache() => _cache.clear();
}

final photoDataSourceProvider = Provider<PhotoDataSource>(
  (ref) => RealPhotoDataSource(),
);

final photoLibraryServiceProvider = Provider<PhotoLibraryService>(
  (ref) => PhotoLibraryService(ref.watch(photoDataSourceProvider)),
);

final photosForDateProvider =
    FutureProvider.family<List<PhotoAsset>, DateTime>((ref, date) async {
  return ref.watch(photoLibraryServiceProvider).fetchForDate(date);
});
