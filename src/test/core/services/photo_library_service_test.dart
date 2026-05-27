import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:time_tracker/core/services/photo_library_service.dart';

class _FakeSource implements PhotoDataSource {
  final PermissionState permission;
  final List<RawPhotoInfo> photos;

  _FakeSource({required this.permission, this.photos = const []});

  @override
  Future<PermissionState> requestPermission() async => permission;

  @override
  Future<List<RawPhotoInfo>> photosForDate(DateTime date) async => photos;
}

RawPhotoInfo _photo({
  required String id,
  required DateTime takenAt,
  Uint8List? bytes,
}) =>
    RawPhotoInfo(
      id: id,
      takenAt: takenAt,
      loadThumb: (_) async => bytes,
    );

void main() {
  group('PhotoLibraryService', () {
    test('권한 거부 → 빈 리스트', () async {
      final svc = PhotoLibraryService(
        _FakeSource(permission: PermissionState.denied),
      );
      final result = await svc.fetchForDate(DateTime(2026, 5, 27));
      expect(result, isEmpty);
    });

    test('권한 승인 + 사진 없음 → 빈 리스트', () async {
      final svc = PhotoLibraryService(
        _FakeSource(permission: PermissionState.authorized),
      );
      final result = await svc.fetchForDate(DateTime(2026, 5, 27));
      expect(result, isEmpty);
    });

    test('takenAt → takenMinute 10분 단위 스냅', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final svc = PhotoLibraryService(
        _FakeSource(
          permission: PermissionState.authorized,
          photos: [
            _photo(
              id: 'a',
              takenAt: DateTime(2026, 5, 27, 9, 37), // 9시 37분 → 570분 → 스냅 570
              bytes: bytes,
            ),
          ],
        ),
      );
      final result = await svc.fetchForDate(DateTime(2026, 5, 27));
      expect(result.length, 1);
      expect(result[0].takenMinute, 570); // (9*60+37)~/10*10 = 573~/10*10 = 57*10 = 570
      expect(result[0].thumbnailBytes, bytes);
    });

    test('thumbnail null → 결과 제외', () async {
      final svc = PhotoLibraryService(
        _FakeSource(
          permission: PermissionState.authorized,
          photos: [
            _photo(id: 'a', takenAt: DateTime(2026, 5, 27, 8, 0), bytes: null),
          ],
        ),
      );
      final result = await svc.fetchForDate(DateTime(2026, 5, 27));
      expect(result, isEmpty);
    });

    test('캐시 — 동일 id 두 번 조회 시 loadThumb 1회만 호출', () async {
      var loadCount = 0;
      final photo = RawPhotoInfo(
        id: 'cached',
        takenAt: DateTime(2026, 5, 27, 10, 0),
        loadThumb: (_) async {
          loadCount++;
          return Uint8List.fromList([9]);
        },
      );
      final src = _FakeSource(
        permission: PermissionState.authorized,
        photos: [photo],
      );
      final svc = PhotoLibraryService(src);

      await svc.fetchForDate(DateTime(2026, 5, 27));
      await svc.fetchForDate(DateTime(2026, 5, 27));
      expect(loadCount, 1);
    });

    test('clearCache → 다음 조회 시 loadThumb 재호출', () async {
      var loadCount = 0;
      final photo = RawPhotoInfo(
        id: 'x',
        takenAt: DateTime(2026, 5, 27, 10, 0),
        loadThumb: (_) async {
          loadCount++;
          return Uint8List.fromList([1]);
        },
      );
      final src = _FakeSource(
        permission: PermissionState.authorized,
        photos: [photo],
      );
      final svc = PhotoLibraryService(src);

      await svc.fetchForDate(DateTime(2026, 5, 27));
      svc.clearCache();
      await svc.fetchForDate(DateTime(2026, 5, 27));
      expect(loadCount, 2);
    });
  });
}
