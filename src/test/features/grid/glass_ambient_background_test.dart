import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/core/models/time_block_style.dart';
import 'package:time_tracker/core/services/appearance_service.dart';
import 'package:time_tracker/core/services/preferences_port.dart';
import 'package:time_tracker/core/theme/app_theme.dart';
import 'package:time_tracker/features/grid/widgets/glass_ambient_background.dart';

class _FakePrefs implements PreferencesPort {
  final Map<String, Object> _store = {};

  _FakePrefs({TimeBlockStyle? style}) {
    if (style != null) {
      _store['appearance_block_style'] = style.index;
    }
  }

  @override
  bool? getBool(String key) => _store[key] as bool?;

  @override
  int? getInt(String key) => _store[key] as int?;

  @override
  Future<void> setBool(String key, bool value) async => _store[key] = value;

  @override
  Future<void> setInt(String key, int value) async => _store[key] = value;
}

Widget _wrap(
  Widget child,
  TimeBlockStyle style, {
  Brightness brightness = Brightness.light,
}) {
  return ProviderScope(
    overrides: [
      appearanceServiceProvider.overrideWith(
        (ref) => AppearanceService(_FakePrefs(style: style)),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('GlassAmbientBackground', () {
    testWidgets('liquidGlass → gradient Container in tree', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GlassAmbientBackground(
            brightness: Brightness.light,
            child: SizedBox.expand(),
          ),
          TimeBlockStyle.liquidGlass,
        ),
      );

      // Find a Container with a gradient decoration
      final containers = tester.widgetList<Container>(
        find.byType(Container),
      );
      final hasGradient = containers.any((c) {
        final deco = c.decoration;
        return deco is BoxDecoration && deco.gradient != null;
      });
      expect(hasGradient, isTrue);
    });

    testWidgets('tintBar → no gradient Container (just child)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GlassAmbientBackground(
            brightness: Brightness.light,
            child: SizedBox.expand(),
          ),
          TimeBlockStyle.tintBar,
        ),
      );

      final containers = tester.widgetList<Container>(
        find.byType(Container),
      );
      final hasGradient = containers.any((c) {
        final deco = c.decoration;
        return deco is BoxDecoration && deco.gradient != null;
      });
      expect(hasGradient, isFalse);
    });

    testWidgets('liquidGlass + dark → uses dark palette (contains 0xFF2A1F3D)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GlassAmbientBackground(
            brightness: Brightness.dark,
            child: SizedBox.expand(),
          ),
          TimeBlockStyle.liquidGlass,
          brightness: Brightness.dark,
        ),
      );

      final containers = tester.widgetList<Container>(
        find.byType(Container),
      );
      Container? gradientContainer;
      for (final c in containers) {
        final deco = c.decoration;
        if (deco is BoxDecoration && deco.gradient != null) {
          gradientContainer = c;
          break;
        }
      }
      expect(gradientContainer, isNotNull);

      final gradient =
          (gradientContainer!.decoration as BoxDecoration).gradient
              as LinearGradient;
      expect(
        gradient.colors,
        containsAll(AppTheme.ambientGradientDark.colors),
      );
      expect(
        gradient.colors,
        contains(const Color(0xFF2A1F3D)),
      );
    });
  });
}
