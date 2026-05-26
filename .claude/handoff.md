# Time Tracker — Handoff Document
**Date:** 2026-05-27  
**Project dir:** `/Users/haram/dev/time-tracker`  
**Platform:** Flutter (Dart), iOS + Android  
**Next session focus:** 남은 이슈 (#9 알림, #10 날짜 네비 마무리, #11/#12 분석) 구현

---

## Suggested Skills
- `/caveman` — 이 프로젝트의 기본 응답 스타일. 첫 응답 시 반드시 호출.

---

## 프로젝트 개요

PRD: `/Users/haram/dev/time-tracker/PRD.md`

10분 단위 그리드 기반 시간 추적 앱. 하루 144칸 그리드에서 셀 탭으로 카테고리 지정, 카메라롤 사진 자동 썸네일, 누적 데이터 분석.

**패키지:** `sqflite`, `photo_manager`, `flutter_local_notifications`, `flutter_riverpod`  
**상태관리:** Riverpod (코드 생성 없는 plain `Provider` / `StreamProvider`)

---

## 구현 완료 (이슈 #2~#8 — GitHub은 아직 OPEN 상태, 수동 close 필요)

### 파일 트리
```
lib/
  main.dart                          # ProviderScope + TimeTrackerApp → GridScreen
  core/
    db/
      database_helper.dart           # SQLite 싱글톤, setDatabaseForTesting/resetForTesting
      category_store.dart            # CategoryStore + categoryStoreProvider + categoriesStreamProvider
      time_block_store.dart          # TimeBlockStore + timeBlockStoreProvider + timeBlocksStreamProvider
    models/
      category.dart                  # Category {id, name, colorHex, isPreset}
      time_block.dart                # TimeBlock {id, date, startMinute, endMinute, categoryId, note}
      cell_state.dart                # CellState {categoryColor?, thumbnails, isSelected}
      photo_asset.dart               # PhotoAsset {takenMinute, thumbnailBytes}
    services/
      photo_library_service.dart     # PhotoLibraryService + photosForDateProvider
  features/
    grid/
      grid_screen.dart               # 메인 화면 (실제 DB 연동, 날짜 네비 기본 구현)
      grid_view_model.dart           # GridViewModel.compute() — 순수 Dart
      drag_selection_controller.dart # DragSelectionController (ChangeNotifier)
      category_bottom_sheet.dart     # 카테고리 선택 바텀시트 → TimeBlockStore.insert()
      edit_block_bottom_sheet.dart   # 기존 블록 수정/삭제 바텀시트
      widgets/
        grid_cell.dart               # GridCell (32px 높이, onTap 콜백)
```

### 테스트 현황
```
test/
  core/db/category_store_test.dart     # 9개 테스트 — 모두 통과
  core/db/time_block_store_test.dart   # 7개 테스트 — 모두 통과
  features/grid/drag_selection_controller_test.dart  # 8개 테스트 — 모두 통과
  widget_test.dart                     # 기본 스모크 테스트
```
총 24/24 통과. `flutter analyze` 이슈 없음.

### 핵심 설계 결정
- `DatabaseHelper.resetForTesting()` — 테스트 간 DB 격리 (tearDown에서 호출)
- `GridCell.onTap` 콜백 — 셀 탭 시 빈 셀이면 카테고리 바텀시트, 기존 블록이면 수정 바텀시트
- 드래그 선택은 현재 **탭 = 단일 셀 선택**으로 구현 (실제 스와이프 드래그는 scroll 충돌로 미구현)
- `GridViewModel.TimeBlock` (로컬, `dart:ui.Color` 포함) vs `core/models/TimeBlock` (DB용) — GridScreen에서 변환
- `PhotoAsset` 모델은 `lib/core/models/photo_asset.dart` (grid_view_model에서도 import)
- iOS `Info.plist`에 `NSPhotoLibraryUsageDescription` 추가 완료
- Android `AndroidManifest.xml`에 `READ_MEDIA_IMAGES` 권한 추가 완료

---

## 남은 이슈 (모두 OPEN)

### #10 날짜 네비게이션 — **거의 완료, 마무리 필요**
`grid_screen.dart`에 이전/다음 날 버튼 이미 구현됨.  
**남은 것:**
- 미래 날짜로 이동 불가 제한 (`_selectedDate` >= today 체크)
- 오늘로 바로 돌아오는 "오늘" 버튼 (AppBar action)
- 날짜 변경 시 `_scrollController`를 그 날짜에 맞게 재조정 (오늘이면 현재시각, 과거면 상단)

### #9 스마트 알림 — `lib/core/notifications/` 아직 비어있음
구현할 것:
- `NotificationScheduler` (`flutter_local_notifications`)
- 앱 포그라운드 진입 시 → 마지막 블록 종료 시각 조회 → 3시간 공백이면 알림
- 취침시간(23:00~07:00) 제외
- `lib/features/settings/` 화면: 알림 on/off 토글 + 취침시간 설정
- iOS: `AppDelegate` 에 알림 권한 요청 추가 필요
- `flutter_local_notifications` 초기화는 `main.dart`에서 `WidgetsFlutterBinding.ensureInitialized()` 후

### #11 분석 - 카테고리 비율 차트
- `lib/features/analytics/analytics_engine.dart` (순수 Dart) 신규 생성
  - `computeDailyStats(List<TimeBlock>, List<Category>) → List<CategoryStat>`
  - `computeWeeklyStats(...)`, `computeMonthlyStats(...)`
- `lib/features/analytics/analytics_screen.dart` — 일/주/월 탭 + 파이차트 또는 바차트
- 차트 패키지: pubspec에 없음, `fl_chart` 추가 권장 (`fl_chart: ^0.69.0`)
- 단위 테스트 필수 (duration totals, percentages 정확성)
- 메인 화면 하단에 BottomNavigationBar 또는 FAB로 진입점 추가

### #12 분석 - 시간대 히트맵
- `AnalyticsEngine`에 `computeHeatmap(blocks, {Category? filter}) → Map<int hour, int count>` 추가
- 히트맵 위젯: Y축 시간(0~23), X축 요일/날짜, 색상 강도 = 빈도
- 분석 화면에 탭으로 추가
- 데이터 2주 미만이면 안내 메시지
- #10 (날짜 네비) 선행 필요

---

## 알려진 미구현 / 개선 여지

1. **실제 스와이프 드래그** — 현재 탭으로만 단일 셀 선택. `DragSelectionController`는 완전히 구현됨. GridCell에서 `GestureDetector`의 pan 제스처 + `ScrollPhysics.NeverScrollableScrollPhysics`를 조합해 드래그 구현 가능하나 스크롤과의 충돌 해결 필요.
2. **커스텀 카테고리 추가 UI** — `CategoryStore`의 insert/update/delete는 구현됨. settings 화면에서 UI 필요.
3. **GitHub 이슈 클로즈** — 이슈 #2~#8 구현 완료됐으나 GitHub에 아직 OPEN. 수동으로 `gh issue close 2 3 4 5 6 7 8` 실행 필요.

---

## 빠른 컨텍스트 복원용 명령

```bash
cd /Users/haram/dev/time-tracker
flutter analyze          # 분석 (0 issues 확인)
flutter test             # 전체 테스트 (24 passed 확인)
gh issue list            # 남은 이슈 확인
```
