# Time Tracker — Handoff Document
**Date:** 2026-05-27  
**Project dir:** `/Users/haram/dev/time-tracker/src`  
**Platform:** Flutter (Dart), iOS + Android  
**Next session focus:** GridViewModel 테스트 추가(#4) → 남은 기능 이슈(#9/#10/#11/#12) 구현

---

## Suggested Skills
- `/caveman` — 이 프로젝트의 기본 응답 스타일. 첫 응답 시 반드시 호출.

---

## 프로젝트 개요

PRD: `/Users/haram/dev/time-tracker/PRD.md`  
실제 소스: `/Users/haram/dev/time-tracker/src/` (lib/, test/ 모두 여기)

10분 단위 그리드 기반 시간 추적 앱. 하루 144칸 그리드에서 셀 탭으로 카테고리 지정, 카메라롤 사진 자동 썸네일, 누적 데이터 분석.

**패키지:** `sqflite`, `photo_manager`, `flutter_local_notifications`, `flutter_riverpod`  
**상태관리:** Riverpod (코드 생성 없는 plain `StateNotifierProvider` / `StreamProvider`)

---

## 이번 세션에서 한 일 — 아키텍처 리팩토링

### 배경
`/improve-codebase-architecture` 스킬로 5개 후보를 도출하고, #1+#2+#3을 한 번에 구현했다.

### 변경된 파일 트리

```
lib/
  core/
    utils/
      time_utils.dart              ★ NEW — hexToColor, dateKey, formatMinute 공유 유틸
    db/…                           # 변경 없음
    models/…                       # 변경 없음
    services/…                     # 변경 없음
  features/
    grid/
      grid_screen_view_model.dart  ★ NEW — GridScreenState + GridScreenViewModel(StateNotifier)
      grid_view_model.dart         ★ MODIFIED — 로컬 TimeBlock DTO 삭제, compute()가 categories 받아 Color 변환
      grid_screen.dart             ★ MODIFIED — 얇은 widget으로 단순화
      category_bottom_sheet.dart   ★ MODIFIED — time_utils 사용
      edit_block_bottom_sheet.dart ★ MODIFIED — time_utils 사용
      drag_selection_controller.dart  # 변경 없음
      widgets/grid_cell.dart          # 변경 없음
test/
  widget_test.dart                 ★ MODIFIED — sqflite_ffi 초기화 추가
```

### 핵심 설계 결정

**GridScreenViewModel (StateNotifier):**
- `GridScreenState { selectedDate, dbReady }` 소유
- `_init()`: DB 초기화 + seed — widget에서 완전히 제거됨
- `goToPreviousDay()`, `goToNextDay()`: 날짜 이동
- `blockAtIndex(index, blocks)`: overlap 탐색 로직 (이전 `_blockAtIndex()` 중복 제거)
- Provider: `gridScreenViewModelProvider` (StateNotifierProvider)

**GridViewModel.compute() 시그니처 변경:**
```dart
// Before
static List<CellState> compute({
  required List<TimeBlock> blocks,   // 로컬 DTO (Color 포함)
  required List<PhotoAsset> photos,
  required Set<int> selectedIndices,
})

// After
static List<CellState> compute({
  required List<TimeBlock> blocks,      // core/models/TimeBlock (정식 모델)
  required List<Category> categories,  // Color 변환을 내부에서 처리
  required List<PhotoAsset> photos,
  required Set<int> selectedIndices,
})
```

**_GridScreenState 필드:**  
6개 → 2개 (`_scrollController`, `_drag`). DB init / 날짜 / overlap 로직 전부 viewmodel로 이동.

**time_utils.dart:**  
3개 파일에 복사돼 있던 `_hexToColor`, `_dateKey`, `_formatMinute`/_fmt`를 
`lib/core/utils/time_utils.dart`의 `hexToColor()`, `dateKey()`, `formatMinute()` 로 통합.

**widget_test.dart:**  
ViewModelProvider 생성 시 DB init이 `pump()` 중 발생하므로, 테스트에 sqflite_ffi 초기화 추가.

### 현재 테스트 현황
```
test/
  core/db/category_store_test.dart     # 9개 — 모두 통과
  core/db/time_block_store_test.dart   # 7개 — 모두 통과
  features/grid/drag_selection_controller_test.dart  # 8개 — 모두 통과
  widget_test.dart                     # 1개 — 통과
```
총 25/25 통과. `flutter analyze` 0 issues.

---

## 다음 할 일 (우선순위 순)

### 즉시: GridViewModel.compute() 테스트 추가 (아키텍처 후보 #4)

파일: `test/features/grid/grid_view_model_test.dart` (아직 없음)

테스트해야 할 것:
- 블록 하나 → 해당 셀만 색상이 채워짐 (overlap 로직)
- 블록 경계: startMinute < cellEnd && endMinute > cellStart
- 여러 블록 겹침 → 첫 번째 블록 색상 우선
- 사진 → takenMinute에 해당하는 셀에 thumbnail 배치 (최대 2개)
- selectedIndices → 해당 셀 isSelected=true
- 빈 입력 → 144개 전부 빈 CellState

순수 Dart — mock 불필요, sqflite 불필요.

### 그 다음: 기능 이슈 (#10 → #9 → #11 → #12)

#### #10 날짜 네비게이션 마무리
`GridScreenViewModel`이 이미 날짜 이동을 소유하고 있으므로 여기에 추가:
- `goToNextDay()` — 미래 날짜 이동 불가 제한 (today 초과 시 차단)
- `goToToday()` — 오늘로 즉시 복귀
- AppBar에 "오늘" 버튼 추가 (action)
- 날짜 변경 시 스크롤 재조정: 오늘이면 현재시각, 과거면 상단

#### #9 스마트 알림
```
lib/core/notifications/notification_scheduler.dart  # 아직 비어 있음
lib/features/settings/settings_screen.dart          # 아직 없음
```
- `NotificationScheduler`: 마지막 블록 종료 시각 조회 → 3시간 공백 → 알림
- 취침시간(23:00~07:00) 제외
- 설정 화면: 알림 on/off + 취침시간
- iOS `AppDelegate`에 알림 권한 요청 추가
- `main.dart`에서 `flutter_local_notifications` 초기화

#### #11 분석 - 카테고리 비율 차트
- `lib/features/analytics/analytics_engine.dart` (순수 Dart) 신규
  - `computeDailyStats(List<TimeBlock>, List<Category>) → List<CategoryStat>`
  - `computeWeeklyStats(...)`, `computeMonthlyStats(...)`
- `lib/features/analytics/analytics_screen.dart` — 일/주/월 탭 + 차트
- 차트 패키지: `fl_chart: ^0.69.0` pubspec 추가 필요
- 단위 테스트 필수
- BottomNavigationBar로 메인 화면에서 진입

#### #12 분석 - 시간대 히트맵
- `AnalyticsEngine`에 `computeHeatmap(...)` 추가
- 히트맵 위젯: 시간(Y축) × 요일(X축), 색상 강도 = 빈도
- 데이터 2주 미만이면 안내 메시지
- #11 완료 후 진행

---

## 빠른 컨텍스트 복원용 명령

```bash
cd /Users/haram/dev/time-tracker/src
flutter analyze          # 0 issues 확인
flutter test             # 25 passed 확인
gh issue list            # 남은 이슈 확인
```

---

## 알려진 미구현 / 개선 여지

1. **실제 스와이프 드래그** — `DragSelectionController` 완전히 구현됨. GridCell에서 pan 제스처 + NeverScrollableScrollPhysics 조합 필요.
2. **커스텀 카테고리 추가 UI** — `CategoryStore`의 CRUD는 구현됨. 설정 화면 UI 미구현.
3. **GitHub 이슈 클로즈** — 이슈 #2~#8 구현 완료, GitHub에 아직 OPEN. `gh issue close 2 3 4 5 6 7 8` 실행 필요.
4. **아키텍처 후보 #5** — Store 스트림 알림 심화(변경마다 전체 DB 재조회 → 증분 업데이트). 분석 기능 추가 후 재평가 권장.
