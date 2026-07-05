import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/core/logic/page_sync_decider.dart';

void main() {
  group('decidePageSync (외부 네비게이션 전용 — swipe 경로는 결정을 묻지 않음)', () {
    test('현재 == 목표 → NoOp (이미 도착)', () {
      final d = decidePageSync(currentPage: 10, targetPage: 10);
      expect(d, const NoOp());
    });

    test('현재 != 목표 → JumpTo(목표)', () {
      final d = decidePageSync(currentPage: 3, targetPage: 10);
      expect(d, const JumpTo(10));
    });

    test('컨트롤러 미부착(currentPage null) → JumpTo(목표)', () {
      final d = decidePageSync(currentPage: null, targetPage: 7);
      expect(d, const JumpTo(7));
    });
  });

  group('decideScrollTarget (scroll-to-now vs scroll-to-top 분기)', () {
    test('오늘 → toNow', () {
      expect(decideScrollTarget(isToday: true), ScrollTarget.toNow);
    });

    test('다른 날짜 → toTop', () {
      expect(decideScrollTarget(isToday: false), ScrollTarget.toTop);
    });
  });
}
