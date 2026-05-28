import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/features/grid/widgets/block_renderer.dart';
import 'package:time_tracker/core/models/time_block_style.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(body: SizedBox(width: 100, height: 60, child: child)),
  );
}

void main() {
  group('BlockRenderer', () {
    const color = Color(0xFF4A90D9);
    const label = 'Work';

    testWidgets('tintBar renders with left border', (tester) async {
      await tester.pumpWidget(_wrap(
        const BlockRenderer(
            style: TimeBlockStyle.tintBar,
            color: color,
            label: label,
            height: 40),
      ));
      final container = tester.widget<Container>(
        find
            .descendant(
                of: find.byType(BlockRenderer),
                matching: find.byType(Container))
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isA<Border>());
    });

    testWidgets('card renders with solid color background', (tester) async {
      await tester.pumpWidget(_wrap(
        const BlockRenderer(
            style: TimeBlockStyle.card,
            color: color,
            label: label,
            height: 40),
      ));
      final container = tester.widget<Container>(
        find
            .descendant(
                of: find.byType(BlockRenderer),
                matching: find.byType(Container))
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, equals(color));
    });

    testWidgets('roundedTint renders with borderRadius 8', (tester) async {
      await tester.pumpWidget(_wrap(
        const BlockRenderer(
            style: TimeBlockStyle.roundedTint,
            color: color,
            label: label,
            height: 40),
      ));
      final container = tester.widget<Container>(
        find
            .descendant(
                of: find.byType(BlockRenderer),
                matching: find.byType(Container))
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(8));
    });

    testWidgets('liquidGlass uses BackdropFilter', (tester) async {
      await tester.pumpWidget(_wrap(
        const BlockRenderer(
            style: TimeBlockStyle.liquidGlass,
            color: color,
            label: label,
            height: 40),
      ));
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('label hidden when height < 20', (tester) async {
      await tester.pumpWidget(_wrap(
        const BlockRenderer(
            style: TimeBlockStyle.tintBar,
            color: color,
            label: label,
            height: 10),
      ));
      expect(find.text(label), findsNothing);
    });

    testWidgets('label shown when height >= 20', (tester) async {
      await tester.pumpWidget(_wrap(
        const BlockRenderer(
            style: TimeBlockStyle.tintBar,
            color: color,
            label: label,
            height: 40),
      ));
      expect(find.text(label), findsOneWidget);
    });
  });
}
