import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/core/logic/page_sync_decider.dart';

void main() {
  group('decidePageSync()', () {
    test('swipe 출처 → 항상 NoOp (현재==목표)', () {
      final d = decidePageSync(
        source: PageChangeSource.swipe,
        currentPage: 5,
        targetPage: 5,
      );
      expect(d, const NoOp());
    });

    test('swipe 출처 → 항상 NoOp (현재!=목표여도 echo 점프 금지)', () {
      final d = decidePageSync(
        source: PageChangeSource.swipe,
        currentPage: 3,
        targetPage: 5,
      );
      expect(d, const NoOp());
    });

    test('swipe 출처 → 항상 NoOp (현재 null)', () {
      final d = decidePageSync(
        source: PageChangeSource.swipe,
        currentPage: null,
        targetPage: 5,
      );
      expect(d, const NoOp());
    });

    test('external + 현재==목표 → NoOp', () {
      final d = decidePageSync(
        source: PageChangeSource.external,
        currentPage: 7,
        targetPage: 7,
      );
      expect(d, const NoOp());
    });

    test('external + 현재!=목표 → JumpTo(목표)', () {
      final d = decidePageSync(
        source: PageChangeSource.external,
        currentPage: 2,
        targetPage: 9,
      );
      expect(d, const JumpTo(9));
    });

    test('external + 현재==null → JumpTo(목표)', () {
      final d = decidePageSync(
        source: PageChangeSource.external,
        currentPage: null,
        targetPage: 4,
      );
      expect(d, const JumpTo(4));
    });
  });
}
