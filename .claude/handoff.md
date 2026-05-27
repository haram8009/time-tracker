# Time Tracker — Handoff Document
**Date:** 2026-05-27  
**Project dir:** `/Users/haram/dev/time-tracker/src`  
**Platform:** Flutter (Dart), iOS + Android  
**Next session focus:** 이슈 #18 구현 (낮은 우선순위) 또는 GitHub 이슈 목록 확인 후 신규 작업

---

## Suggested Skills
- `/caveman` — **세션 시작 즉시 호출. 이 프로젝트의 기본 응답 스타일.**
- `/code-review` — 각 이슈 구현 완료 후 diff 리뷰
- `/verify` — 알림/UI 변경 후 실제 앱 동작 확인 시

---

## 프로젝트 개요

PRD: `/Users/haram/dev/time-tracker/PRD.md`  
실제 소스: `/Users/haram/dev/time-tracker/src/` (lib/, test/ 모두 여기)

10분 단위 그리드 기반 시간 추적 앱. 하루 144칸 그리드에서 셀 탭/드래그로 카테고리 지정, 카메라롤 사진 자동 썸네일, 누적 데이터 분석.

**패키지:** `sqflite`, `photo_manager`, `flutter_local_notifications`, `flutter_riverpod`, `shared_preferences`, `timezone`, `fl_chart`  
**상태관리:** Riverpod (`StateNotifierProvider` / `StreamProvider` / `FutureProvider`)

---

## 현재 상태 (2026-05-27 기준)

```
flutter analyze   → 0 issues ✓
flutter test      → 92 passed ✓
```

**GitHub 이슈 #14~#17:** 구현 완료. 이슈 close 필요:
```bash
gh issue close 14 15 16 17
```

**GitHub 이슈 #2~#12:** 아직 OPEN. 사용자 직접 실행 필요:
```bash
gh issue close 2 3 4 5 6 7 8 9 10 11 12
```

---

## 이번 세션에서 한 일

### 이슈 #14 — NotificationPort 인터페이스 추출 (resolves #14)
- `lib/core/notifications/notification_port.dart` 신규 생성
  - `abstract class NotificationPort { initialize(), cancelById(), scheduleAtTime() }`
  - `class FlutterLocalNotificationsAdapter implements NotificationPort`
  - `notificationPortProvider` Riverpod Provider
- `notification_scheduler.dart` — 글로벌 `_plugin` 제거, 함수들이 `NotificationPort port` 파라미터 수신
- `settings_service.dart` — `NotificationPort` 생성자 주입
- `main.dart` — `FlutterLocalNotificationsAdapter` 직접 생성 후 `ProviderScope` override
- `grid_screen.dart` — `ref.read(notificationPortProvider)` 로 port 전달
- **테스트:** `test/core/notifications/notification_scheduler_test.dart` 추가 (FakeNotificationPort)

### 이슈 #15 — PreferencesPort + SettingsService DI (resolves #15)
- `lib/core/notifications/notification_settings.dart` 신규 생성 — `NotificationSettings` 모델 분리
- `lib/core/services/preferences_port.dart` 신규 생성
  - `abstract class PreferencesPort { getBool/getInt/setBool/setInt }`
  - `class SharedPrefsAdapter implements PreferencesPort`
  - `sharedPrefsAdapterProvider` (ProviderScope에서 override 필요)
- `settings_service.dart` — `PreferencesPort` + `NotificationPort` 생성자 주입, `_load()` 동기화
- `notification_scheduler.dart` → `notification_settings.dart` import로 순환 의존성 제거
- `main.dart` — `SharedPrefsAdapter` 초기화 후 ProviderScope override
- **테스트:** `test/core/services/settings_service_test.dart` 추가 (FakePrefs + FakeNotifs)

### 이슈 #16 — AnalyticsViewModel 추출 + 히트맵 임계값 설정화 (resolves #16)
- `lib/features/analytics/analytics_view_model.dart` 신규 생성
  - `enum AnalyticsPeriod { day, week, month, heatmap }`
  - `AnalyticsViewModel(PreferencesPort)` — heatmapThreshold 상태 관리
  - `static dateRangeFor(period)`, `static labelFor(period)` 순수 메서드
  - `analyticsViewModelProvider`
- `analytics_screen.dart` — VM 사용, `_Period` enum 제거, 하드코딩된 `< 5` → VM의 threshold
- `settings_screen.dart` — 히트맵 최소 기록 수 ±1 조절 UI 추가
- **테스트:** `test/features/analytics/analytics_view_model_test.dart` 추가

### 이슈 #17 — GridScreenViewModel.saveBlock + 알림 이관 (resolves #17)
- `grid_screen_view_model.dart` — `saveBlock(TimeBlock)` 메서드 추가
  - `store.insert(block)` 후 오늘 날짜면 `scheduleSmartNotification` 호출
  - `NotificationPort`는 `_ref.read(notificationPortProvider)`로 접근
- `category_bottom_sheet.dart` — `timeBlockStoreProvider.insert` → `gridScreenViewModelProvider.notifier.saveBlock`
- `grid_screen.dart` — `scheduleSmartNotification` 직접 호출 제거, 관련 import 제거
- **테스트:** `test/features/grid/grid_screen_view_model_test.dart` 추가 (sqflite_ffi + FakeCategoryStore)

---

## 다음 세션 작업

### 이슈 #18 (낮은 우선순위)
**CategoryStore 프리셋 주입 + seedIfNeeded 자동화**  
https://github.com/haram8009/time-tracker/issues/18

핵심 변경:
- `CategoryStore({List<Category>? seedCategories})` 생성자 파라미터 추가
- 첫 DB 접근 전 내부에서 자동 `seedIfNeeded()` 실행 (Completer/lazy init)
- `GridScreenViewModel._init()`에서 `categoryStore.seedIfNeeded()` 호출 제거
- `category_store_test.dart` — 커스텀 시드 주입 테스트 추가

독립 실행 가능. 의존성 없음.

---

## 커밋 규칙 (이슈별)

각 이슈 완료 시:
```
refactor: <설명> (resolves #<이슈번호>)
```

커밋 전 필수:
```bash
flutter analyze   # 0 issues
flutter test      # all pass
```

브랜치: 각 이슈마다 `issue-<번호>-<짧은설명>` 브랜치 생성 권장.

---

## 파일 트리 (핵심)

```
lib/
  core/
    utils/time_utils.dart
    db/
      database_helper.dart          — setDatabaseForTesting/resetForTesting 지원
      time_block_store.dart         — fetchByDate, watchByDate, insert/update/delete
      category_store.dart           — seedIfNeeded, fetchAll, CRUD (리팩터 대상 #18)
    models/                         — TimeBlock, Category, PhotoAsset, CellState
    services/
      photo_library_service.dart    — PhotoDataSource 인터페이스 주입 패턴
      real_photo_data_source.dart   — 어댑터 패턴 선례
      settings_service.dart         — SettingsService(PreferencesPort, NotificationPort) ✓
      preferences_port.dart         — PreferencesPort + SharedPrefsAdapter ✓ (NEW)
    notifications/
      notification_port.dart        — NotificationPort + FlutterLocalNotificationsAdapter ✓ (NEW)
      notification_scheduler.dart   — port 파라미터 수신 ✓
      notification_settings.dart    — NotificationSettings 모델 ✓ (NEW, 분리됨)
      notification_logic.dart       — 순수 계산 로직 (변경 불필요)
  features/
    grid/
      grid_screen_view_model.dart   — saveBlock 구현 완료 ✓
      grid_view_model.dart          — 순수 Dart (변경 불필요)
      grid_screen.dart              — 알림 직접 호출 제거 ✓
      category_bottom_sheet.dart    — vm.saveBlock 호출 ✓
      drag_selection_controller.dart
      edit_block_bottom_sheet.dart  — store.update/delete 직접 (미변경)
      widgets/grid_cell.dart
    analytics/
      analytics_engine.dart         — 순수 계산 (변경 불필요)
      analytics_view_model.dart     — AnalyticsViewModel ✓ (NEW)
      analytics_screen.dart         — VM 사용, 렌더 전용 ✓
    settings/
      settings_screen.dart          — 히트맵 임계값 UI 추가 ✓
  main.dart                         — SharedPrefsAdapter + NotificationPort 초기화 ✓
test/
  core/db/category_store_test.dart
  core/db/time_block_store_test.dart
  core/notifications/notification_logic_test.dart
  core/notifications/notification_scheduler_test.dart  ← NEW
  core/services/photo_library_service_test.dart
  core/services/settings_service_test.dart             ← NEW
  features/grid/drag_selection_controller_test.dart
  features/grid/grid_view_model_test.dart
  features/grid/grid_screen_view_model_test.dart       ← NEW (sqflite_ffi)
  features/analytics/analytics_engine_test.dart
  features/analytics/analytics_view_model_test.dart   ← NEW
  widget_test.dart
```

---

## 아키텍처 패턴 참고

**포트/어댑터 패턴 (일관된 패턴):**
- `PhotoDataSource` / `RealPhotoDataSource` — 선례
- `NotificationPort` / `FlutterLocalNotificationsAdapter` — 완료 #14
- `PreferencesPort` / `SharedPrefsAdapter` — 완료 #15

**main.dart 부트스트랩 패턴:**
```dart
final rawPrefs = await SharedPreferences.getInstance();
final prefsAdapter = SharedPrefsAdapter(rawPrefs);
final port = FlutterLocalNotificationsAdapter();
await port.initialize();
runApp(ProviderScope(
  overrides: [
    sharedPrefsAdapterProvider.overrideWithValue(prefsAdapter),
    notificationPortProvider.overrideWithValue(port),
  ],
  child: const TimeTrackerApp(),
));
```

**테스트 선례:**
- `FakeNotificationPort` — `test/core/notifications/notification_scheduler_test.dart`
- `FakePrefs` + `FakeNotifs` — `test/core/services/settings_service_test.dart`
- sqflite_ffi + `FakeCategoryStore` — `test/features/grid/grid_screen_view_model_test.dart`
- `StateNotifier` 테스트: `grid_view_model_test.dart`

---

## 빠른 컨텍스트 복원

```bash
cd /Users/haram/dev/time-tracker/src
flutter analyze && flutter test
git log --oneline -10
gh issue list
```
