/// page↔date 동기화의 순수 결정 로직. Flutter 위젯/컨트롤러 의존이 전혀 없다.
///
/// echo 억제는 구조적으로 해결됐다(#98): 스와이프 경로는 이 결정을 아예 묻지
/// 않는다(컨트롤러가 이미 목표 페이지). 외부 네비게이션(달력/주간탭/오늘)만
/// [decidePageSync]로 점프 여부를 판단한다.
library;

/// 결정 결과.
sealed class PageSyncDecision {
  const PageSyncDecision();
}

/// 점프 불필요.
class NoOp extends PageSyncDecision {
  const NoOp();

  @override
  bool operator ==(Object other) => other is NoOp;

  @override
  int get hashCode => (NoOp).hashCode;

  @override
  String toString() => 'NoOp()';
}

/// [page]로 점프.
class JumpTo extends PageSyncDecision {
  const JumpTo(this.page);

  final int page;

  @override
  bool operator ==(Object other) => other is JumpTo && other.page == page;

  @override
  int get hashCode => page.hashCode;

  @override
  String toString() => 'JumpTo($page)';
}

/// 외부 네비게이션의 점프 여부 결정.
///
/// - [currentPage] == [targetPage] → [NoOp] (이미 도착)
/// - [currentPage] null(컨트롤러 미부착) 또는 != [targetPage] → [JumpTo]
PageSyncDecision decidePageSync({
  required int? currentPage,
  required int targetPage,
}) {
  if (currentPage == targetPage) return const NoOp();
  return JumpTo(targetPage);
}

/// 날짜 도착 시 세로 스크롤 목적지.
enum ScrollTarget {
  /// 오늘 → 현재 시각 위치로.
  toNow,

  /// 그 외 날짜 → 맨 위로.
  toTop,
}

ScrollTarget decideScrollTarget({required bool isToday}) =>
    isToday ? ScrollTarget.toNow : ScrollTarget.toTop;
