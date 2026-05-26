import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/photo_asset.dart';

class PhotoLibraryService {
  final Map<String, Uint8List> _cache = {};

  Future<PermissionState> requestPermission() =>
      PhotoManager.requestPermissionExtend();

  Future<List<PhotoAsset>> fetchForDate(DateTime date) async {
    final ps = await requestPermission();
    if (!ps.hasAccess) return [];

    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final filterOption = FilterOptionGroup(
      createTimeCond: DateTimeCond(min: dayStart, max: dayEnd),
      orders: [
        const OrderOption(type: OrderOptionType.createDate, asc: true),
      ],
    );

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
      filterOption: filterOption,
    );

    if (paths.isEmpty) return [];

    final count = await paths.first.assetCountAsync;
    if (count == 0) return [];

    final assets = await paths.first.getAssetListRange(
      start: 0,
      end: count.clamp(0, 200),
    );

    final result = <PhotoAsset>[];
    for (final asset in assets) {
      final takenAt = asset.createDateTime;
      final minute = ((takenAt.hour * 60 + takenAt.minute) ~/ 10) * 10;

      Uint8List? bytes;
      if (_cache.containsKey(asset.id)) {
        bytes = _cache[asset.id];
      } else {
        bytes = await asset.thumbnailDataWithSize(const ThumbnailSize(64, 64));
        if (bytes != null) _cache[asset.id] = bytes;
      }

      if (bytes != null) {
        result.add(PhotoAsset(takenMinute: minute, thumbnailBytes: bytes));
      }
    }

    return result;
  }

  void clearCache() => _cache.clear();
}

final photoLibraryServiceProvider = Provider<PhotoLibraryService>(
  (ref) => PhotoLibraryService(),
);

final photosForDateProvider =
    FutureProvider.family<List<PhotoAsset>, DateTime>((ref, date) async {
  return ref.watch(photoLibraryServiceProvider).fetchForDate(date);
});
