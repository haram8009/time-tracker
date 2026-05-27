import 'package:photo_manager/photo_manager.dart';

import 'photo_library_service.dart';

class RealPhotoDataSource implements PhotoDataSource {
  @override
  Future<PermissionState> requestPermission() =>
      PhotoManager.requestPermissionExtend();

  @override
  Future<List<RawPhotoInfo>> photosForDate(DateTime date) async {
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

    return assets
        .map((a) => RawPhotoInfo(
              id: a.id,
              takenAt: a.createDateTime,
              loadThumb: (size) => a.thumbnailDataWithSize(size),
            ))
        .toList();
  }
}
