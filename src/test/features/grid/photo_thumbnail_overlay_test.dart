import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/core/models/cell_state.dart';
import 'package:time_tracker/features/grid/widgets/photo_thumbnail_overlay.dart';

// Valid 1×1 transparent PNG (kTransparentImage from transparent_image pkg)
final Uint8List _kTestPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

Finder _descendantsOf(Type overlayType, Type childType) {
  return find.descendant(
    of: find.byType(overlayType),
    matching: find.byType(childType),
  );
}

void main() {
  group('PhotoThumbnailOverlay', () {
    testWidgets('no thumbnails → no ClipRRect inside overlay', (tester) async {
      final cells = List.generate(144, (_) => const CellState());

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 400,
            height: 400,
            child: PhotoThumbnailOverlay(
              cells: cells,
              cellHeight: 48,
              timeLabelWidth: 48,
            ),
          ),
        ),
      );

      expect(_descendantsOf(PhotoThumbnailOverlay, ClipRRect), findsNothing);
    });

    testWidgets('two cells with thumbnails → two Positioned inside overlay', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final cells = List.generate(144, (i) {
        if (i == 0 || i == 7) {
          return CellState(thumbnails: [_kTestPng]);
        }
        return const CellState();
      });

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 400,
            height: 1152,
            child: PhotoThumbnailOverlay(
              cells: cells,
              cellHeight: 48,
              timeLabelWidth: 48,
            ),
          ),
        ),
      );

      // 2 cells with thumbnails → 2 Positioned widgets in the overlay Stack
      expect(
        _descendantsOf(PhotoThumbnailOverlay, Positioned),
        findsNWidgets(2),
      );
    });

    testWidgets('overlay contains IgnorePointer when thumbnails present', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Suppress RenderFlex overflow errors that occur in test environments
      // due to Image.memory pre-decode layout behavior.
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.library == 'rendering library') return;
        originalOnError?.call(details);
      };
      addTearDown(() { FlutterError.onError = originalOnError; });

      final cells = List.generate(144, (i) {
        return i == 0
            ? CellState(thumbnails: [_kTestPng])
            : const CellState();
      });

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 400,
            height: 1152,
            child: PhotoThumbnailOverlay(
              cells: cells,
              cellHeight: 48,
              timeLabelWidth: 48,
            ),
          ),
        ),
      );

      expect(
        _descendantsOf(PhotoThumbnailOverlay, IgnorePointer),
        findsOneWidget,
      );
    });
  });
}
