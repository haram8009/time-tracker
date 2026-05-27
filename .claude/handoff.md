# Time Tracker — Handoff Document
**Date:** 2026-05-27  
**Project dir:** `/Users/haram/dev/time-tracker/src`  
**Platform:** Flutter (Dart), iOS + Android  
**Next session focus:** GitHub 이슈 #2~#12 close → 히트맵 임계값 설정화

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
flutter test      → 59 passed ✓
```

**구현 완료: 이슈 #2~#12 전체 + 알림 백그라운드 재스케줄**

| 커밋 | 내용 |
|---|---|
| `6073a52` | feat: 알림 백그라운드 재스케줄 구현 (#9) |
| `3e7ea54` | chore: macOS 플러그인 등록 업데이트 + handoff 갱신 |
| `37c09de` | feat: 커스텀 카테고리 관리 UI — 추가/수정/삭제 + 색상 팔레트 |
| `543a11d` | feat: 멀티셀 드래그 선택 구현 — Listener + NeverScrollablePhysics |

**GitHub 이슈:** #2~#12 OPEN 상태 — 닫아야 함  
*사용자가 직접 실행 필요 (Claude Code 권한 제한):*
```bash
gh issue close 2 3 4 5 6 7 8 9 10 11 12
```
*gh auth는 이미 완료 (haram8009 계정)*

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
      settings_service.dart      — NotificationSettings (loadFromPrefs 포함), SettingsService
    notifications/
      notification_scheduler.dart — initNotifications(), scheduleSmartNotification(), scheduleWeeklyFallbackNotifications()
      notification_logic.dart     — 순수 계산 로직 (fallbackFireMinute, inSleepWindow) ← 신규
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
  main.dart                       — ProviderScope + _RootShell + 시작 시 폴백 알림 예약
test/
  core/db/category_store_test.dart
  core/db/time_block_store_test.dart
  core/notifications/notification_logic_test.dart  — 9 tests ← 신규
  features/grid/drag_selection_controller_test.dart
  features/grid/grid_view_model_test.dart         — 10 tests
  features/analytics/analytics_engine_test.dart  — 15 tests
  widget_test.dart
```

---

## 이번 세션 구현 내용

### 1. iOS 빌드 검증

- `flutter build ios --debug --no-codesign` → 성공 (58.6s)
- iPhone 17 Pro 시뮬레이터 실행 + 그리드 화면 렌더링 정상 확인

### 2. 알림 백그라운드 재스케줄 (`notification_scheduler.dart`, `notification_logic.dart`)

**문제:** 기존엔 `GridScreen` 렌더 시에만 알림 예약 → 앱 미실행 날은 알림 없음

**해결:** 앱 시작 시 앞으로 7일치 폴백 알림 선예약

**알림 흐름 (신규):**
```
앱 시작
  → initNotifications()
  → NotificationSettings.loadFromPrefs()
  → scheduleWeeklyFallbackNotifications()   ← 신규: ID 100~106, 취침 2시간 전 고정

앱 열린 날 GridScreen data 로드
  → scheduleSmartNotification()             ← 기존: ID 1, 마지막 블록 +3시간

설정 변경 (알림 on/off, 취침시간)
  → scheduleWeeklyFallbackNotifications()   ← 신규: 즉시 재스케줄
```

**폴백 시각:** `sleepStartMinute - 120` (취침 23:00 → 폴백 21:00)  
자정 넘김 처리: `target < 0 ? target + 1440 : target`

**ID 체계:**
| 알림 | ID | 발화 기준 |
|---|---|---|
| 스마트 (오늘) | 1 | 마지막 블록 endMinute + 180분 |
| 폴백 day+1 | 100 | 취침 시작 - 120분 (고정) |
| 폴백 day+2 | 101 | 동일 |
| … | … | … |
| 폴백 day+7 | 106 | 동일 |

**변경 파일:**
- `notification_logic.dart` (신규) — `NotificationLogic.fallbackFireMinute`, `NotificationLogic.inSleepWindow`
- `notification_scheduler.dart` — `scheduleWeeklyFallbackNotifications()` 추가, 기존 `_inSleepWindow/_fallbackFireMinute` → `NotificationLogic` 위임
- `settings_service.dart` — `NotificationSettings.loadFromPrefs()` 추가, `setEnabled/setSleepStart/setSleepEnd`에 재스케줄 호출 추가
- `main.dart` — 시작 시 `loadFromPrefs()` + `scheduleWeeklyFallbackNotifications()` 호출

---

## 아키텍처 요약

**네비게이션:** `_RootShell` → `IndexedStack` + `NavigationBar` (기록/분석 2탭)  
**설정 진입:** GridScreen AppBar 우측 settings 아이콘 → push `SettingsScreen`

**드래그 흐름:**
1. `Listener.onPointerDown` → 시작 위치 저장
2. `Listener.onPointerMove` (8px 초과) → `_isDragging = true`, `DragSelectionController.onDragStart()`
3. 이후 move → `onDragUpdate()`, 셀 하이라이트 갱신
4. `Listener.onPointerUp` → `onDragEnd()` → 카테고리 바텀시트
5. 바텀시트 닫힘 → `clearSelection()`

---

## 남은 작업

| 우선순위 | 항목 | 상태 |
|---|---|---|
| 높음 | GitHub 이슈 #2~#12 close | 사용자 직접 실행 필요 (`gh auth` 완료) |
| 낮음 | 히트맵 임계값 조정 가능하게 | 현재 5개 블록 하드코딩 (`analytics_engine.dart`) |

---

## 빠른 컨텍스트 복원

```bash
cd /Users/haram/dev/time-tracker/src
flutter analyze && flutter test
git log --oneline -10
```
