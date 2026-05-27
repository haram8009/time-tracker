# Time Tracker — Handoff Document
**Date:** 2026-05-27  
**Project dir:** `/Users/haram/dev/time-tracker/src`  
**Platform:** Flutter (Dart), iOS + Android  
**Next session focus:** iOS 빌드/실기기 검증 → 알림 백그라운드 재스케줄 → GitHub 이슈 close

---

## Suggested Skills
- `/caveman` — **세션 시작 즉시 호출. 이 프로젝트의 기본 응답 스타일.**

---

## 프로젝트 개요

PRD: `/Users/haram/dev/time-tracker/PRD.md`  
실제 소스: `/Users/haram/dev/time-tracker/src/` (lib/, test/ 모두 여기)

10분 단위 그리드 기반 시간 추적 앱. 하루 144칸 그리드에서 셀 탭/드래그로 카테고리 지정, 카메라롤 사진 자동 썸네일, 누적 데이터 분석.

**패키지:** `sqflite`, `photo_manager`, `flutter_local_notifications`, `flutter_riverpod`, `shared_preferences`, `timezone`, `fl_chart`  
**상태관리:** Riverpod (plain `StateNotifierProvider` / `StreamProvider` / `FutureProvider`)

---

## 현재 상태 (2026-05-27 기준)

```
flutter analyze   → 0 issues ✓
flutter test      → 50 passed ✓
```

**구현 완료: 이슈 #2~#12 + 이번 세션 2건**

| 커밋 | 내용 |
|---|---|
| `37c09de` | feat: 커스텀 카테고리 관리 UI — 추가/수정/삭제 + 색상 팔레트 |
| `543a11d` | feat: 멀티셀 드래그 선택 구현 — Listener + NeverScrollablePhysics |

**GitHub 이슈:** #2~#12 OPEN 상태 — 닫아야 함  
*사용자가 직접 실행 필요 (`gh auth login` 미완):*
```bash
gh issue close 2 3 4 5 6 7 8 9 10 11 12
```

---

## 파일 트리 (핵심)

```
lib/
  core/
    utils/time_utils.dart
    db/
      database_helper.dart
      time_block_store.dart      — fetchByDate, fetchByDateRange, watchByDate
      category_store.dart        — CRUD 완료 (insert/update/delete/watchAll)
    models/                      — TimeBlock, Category, PhotoAsset, CellState
    services/
      photo_library_service.dart
      settings_service.dart      — NotificationSettings, SettingsService
    notifications/
      notification_scheduler.dart — initNotifications(), scheduleSmartNotification()
  features/
    grid/
      grid_screen_view_model.dart — GridScreenState + StateNotifier
      grid_view_model.dart        — compute() 순수 Dart
      grid_screen.dart            — Listener 드래그 + NeverScrollablePhysics ✓
      category_bottom_sheet.dart
      edit_block_bottom_sheet.dart
      drag_selection_controller.dart — onDragStart/Update/End/Cancel ✓
      widgets/grid_cell.dart
    analytics/
      analytics_engine.dart       — computeStats, computeHeatmap, daily/weekly/monthly
      analytics_screen.dart       — 일/주/월/히트맵 탭 + PieChart
    settings/
      settings_screen.dart        — 알림 on/off + 취침시간 + 카테고리 관리 ✓
  main.dart                       — ProviderScope + _RootShell (BottomNavigationBar)
test/
  core/db/category_store_test.dart
  core/db/time_block_store_test.dart
  features/grid/drag_selection_controller_test.dart
  features/grid/grid_view_model_test.dart         — 10 tests
  features/analytics/analytics_engine_test.dart  — 15 tests
  widget_test.dart
```

---

## 이번 세션 구현 내용

### 1. 멀티셀 드래그 선택 (`grid_screen.dart`)

**방식:** `Listener`로 `ListView` 전체를 감싸 raw pointer 이벤트 수신  
**핵심 로직:**
- `onPointerDown`: x < 48px(시간 라벨 영역)이면 무시, 시작 위치 기록
- `onPointerMove`: 수직 이동 8px 초과 시 드래그 모드 진입 → `_isDragging = true`
- 드래그 중 `ListView.physics = NeverScrollableScrollPhysics()` 전환 (스크롤 충돌 방지)
- `onPointerUp`: `onDragEnd()` → 카테고리 바텀시트 표시
- `GridCell.onTap: _isDragging ? null : handler` — 드래그 중 탭 이벤트 억제

**셀 인덱스 계산:**
```dart
int _positionToCellIndex(Offset localPos) {
  final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
  return ((localPos.dy + offset) / 32).floor().clamp(0, 143);
}
```

### 2. 커스텀 카테고리 관리 UI (`settings_screen.dart`)

- 설정 화면 하단에 "카테고리 관리" 섹션 추가
- 카테고리 목록: 프리셋(읽기 전용 "기본" 뱃지) / 커스텀(수정·삭제 아이콘)
- "카테고리 추가" 타일 → `AlertDialog` (이름 TextField + 12색 팔레트)
- 수정: 기존값 pre-fill 후 동일 다이얼로그
- 삭제: 확인 다이얼로그 후 `CategoryStore.delete(id)`
- `CategoryStore` CRUD는 이미 완성 — UI만 신규 구현

---

## 아키텍처 요약

**네비게이션:** `_RootShell` → `IndexedStack` + `NavigationBar` (기록/분석 2탭)  
**설정 진입:** GridScreen AppBar 우측 settings 아이콘 → push `SettingsScreen`

**드래그 흐름 (신규):**
1. `Listener.onPointerDown` → 시작 위치 저장
2. `Listener.onPointerMove` (8px 초과) → `_isDragging = true`, `DragSelectionController.onDragStart()`
3. 이후 move → `onDragUpdate()`, 셀 하이라이트 갱신
4. `Listener.onPointerUp` → `onDragEnd()` → 카테고리 바텀시트
5. 바텀시트 닫힘 → `clearSelection()`

**알림 흐름:**
- `initNotifications()` — `main()`에서 시작 시 초기화
- `scheduleSmartNotification(todayBlocks, settings)` — GridScreen data 콜백, 오늘 날짜만
- 로직: 마지막 블록 endMinute + 180분 → 취침시간(23:00~07:00) 내면 스킵

---

## 남은 작업

| 우선순위 | 항목 | 상태 |
|---|---|---|
| 높음 | iOS 빌드/실기기 검증 | 미완 |
| 중간 | GitHub 이슈 #2~#12 close | `gh auth login` 필요 |
| 낮음 | 알림 백그라운드 재스케줄 | 미구현 — 현재 앱 실행 시에만 |
| 낮음 | 히트맵 임계값 조정 가능하게 | 현재 5개 블록 하드코딩 |

---

## 빠른 컨텍스트 복원

```bash
cd /Users/haram/dev/time-tracker/src
flutter analyze && flutter test
git log --oneline -10
```
