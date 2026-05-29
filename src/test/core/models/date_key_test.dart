import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/core/models/date_key.dart';

void main() {
  group('DateKey', () {
    group('fromDateTime', () {
      test('strips time component', () {
        final dt = DateTime(2024, 3, 5, 14, 30, 45);
        final key = DateKey.fromDateTime(dt);
        expect(key.year, 2024);
        expect(key.month, 3);
        expect(key.day, 5);
      });

      test('midnight stays same date', () {
        final dt = DateTime(2024, 3, 5);
        final key = DateKey.fromDateTime(dt);
        expect(key, const DateKey(2024, 3, 5));
      });
    });

    group('fromPage / toPage round-trip', () {
      const epoch = DateKey(2020, 1, 1);

      test('page 0 is epoch', () {
        final key = DateKey.fromPage(0, epoch);
        expect(key, epoch);
      });

      test('round-trip preserves value', () {
        const key = DateKey(2024, 3, 5);
        final page = key.toPage(epoch);
        final restored = DateKey.fromPage(page, epoch);
        expect(restored, key);
      });

      test('toPage positive for date after epoch', () {
        const key = DateKey(2020, 1, 2);
        expect(key.toPage(epoch), 1);
      });

      test('toPage negative for date before epoch', () {
        const key = DateKey(2019, 12, 31);
        expect(key.toPage(epoch), -1);
      });

      test('toPage zero for epoch itself', () {
        expect(epoch.toPage(epoch), 0);
      });
    });

    group('isBefore / isAfter', () {
      const a = DateKey(2024, 3, 5);
      const b = DateKey(2024, 3, 6);
      const same = DateKey(2024, 3, 5);

      test('earlier date isBefore later', () {
        expect(a.isBefore(b), isTrue);
      });

      test('later date isAfter earlier', () {
        expect(b.isAfter(a), isTrue);
      });

      test('same date is neither before nor after', () {
        expect(a.isBefore(same), isFalse);
        expect(a.isAfter(same), isFalse);
      });

      test('different year comparison', () {
        const y2023 = DateKey(2023, 12, 31);
        const y2024 = DateKey(2024, 1, 1);
        expect(y2023.isBefore(y2024), isTrue);
        expect(y2024.isAfter(y2023), isTrue);
      });

      test('different month comparison', () {
        const feb = DateKey(2024, 2, 28);
        const mar = DateKey(2024, 3, 1);
        expect(feb.isBefore(mar), isTrue);
        expect(mar.isAfter(feb), isTrue);
      });
    });

    group('toDbString', () {
      test('zero-pads month and day', () {
        expect(const DateKey(2024, 3, 5).toDbString(), '2024-03-05');
      });

      test('double-digit month and day', () {
        expect(const DateKey(2024, 11, 20).toDbString(), '2024-11-20');
      });

      test('appEpoch formats correctly', () {
        expect(DateKey.appEpoch.toDbString(), '2020-01-01');
      });
    });

    group('equality', () {
      test('different instances same date are equal', () {
        const a = DateKey(2024, 3, 5);
        const b = DateKey(2024, 3, 5);
        expect(a, equals(b));
      });

      test('different dates are not equal', () {
        const a = DateKey(2024, 3, 5);
        const b = DateKey(2024, 3, 6);
        expect(a, isNot(equals(b)));
      });

      test('same hashCode for equal instances', () {
        const a = DateKey(2024, 3, 5);
        const b = DateKey(2024, 3, 5);
        expect(a.hashCode, b.hashCode);
      });
    });

    group('yesterday', () {
      test('returns previous day', () {
        const key = DateKey(2024, 3, 5);
        expect(key.yesterday(), const DateKey(2024, 3, 4));
      });

      test('crosses month boundary', () {
        const key = DateKey(2024, 3, 1);
        expect(key.yesterday(), const DateKey(2024, 2, 29)); // 2024 is leap year
      });
    });

    group('add', () {
      test('adds positive duration', () {
        const key = DateKey(2024, 3, 5);
        expect(key.add(const Duration(days: 3)), const DateKey(2024, 3, 8));
      });

      test('adds negative duration', () {
        const key = DateKey(2024, 3, 5);
        expect(key.add(const Duration(days: -5)), const DateKey(2024, 2, 29));
      });
    });

    group('toDateTime', () {
      test('returns midnight DateTime', () {
        const key = DateKey(2024, 3, 5);
        final dt = key.toDateTime();
        expect(dt.year, 2024);
        expect(dt.month, 3);
        expect(dt.day, 5);
        expect(dt.hour, 0);
        expect(dt.minute, 0);
        expect(dt.second, 0);
      });
    });
  });
}
