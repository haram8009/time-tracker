/// page↔date 동기화에서 PageView 컨트롤러를 목표 페이지로
/// 점프시킬지 말지를 판단하는 순수 결정 로직.
///
/// Flutter 위젯/컨트롤러 의존이 전혀 없다.
library;

/// 페이지 변경 출처.
enum PageChangeSource {
  /// 사용자 스와이프發. 컨트롤러가 이미 목표 페이지에 있음.
  swipe,

  /// 외부(달력/오늘 버튼 등)發. 컨트롤러 점프가 필요할 수 있음.
  external,
}

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

/// 점프 여부 결정.
///
/// - [source] `swipe` → 항상 [NoOp] (echo 점프 금지)
/// - [source] `external` 이고 [currentPage] == [targetPage] → [NoOp]
/// - [source] `external` 이고 ([currentPage] null 또는 != [targetPage]) → [JumpTo]
///
/// [currentPage]는 컨트롤러 미부착 시 null.
PageSyncDecision decidePageSync({
  required PageChangeSource source,
  required int? currentPage,
  required int targetPage,
}) {
  if (source == PageChangeSource.swipe) return const NoOp();
  if (currentPage == targetPage) return const NoOp();
  return JumpTo(targetPage);
}
