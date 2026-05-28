# PRD: 시간 추적 앱 (Time Tracker)

## Problem Statement

바쁜 일상에서 하루 시간을 어떻게 쓰는지 파악하기 어렵다. 기존 타임트래커 앱은 매 활동마다 버튼을 눌러야 하거나 입력이 번거로워서 지속적으로 사용하기 힘들다. 사용자는 10분 단위로 하루를 돌아보며 최소한의 마찰로 시간을 기록하고, 자신의 시간 소모 패턴을 분석하고 싶다.

## Solution

10분 단위 그리드 기반의 소급 입력 방식 시간 추적 앱. 하루를 144개의 10분짜리 셀로 표시하고, 손가락 드래그로 시간 범위를 선택한 후 바텀 시트에서 카테고리를 탭 한 번으로 지정한다. 카메라롤의 사진이 촬영 시간에 맞는 셀에 자동으로 썸네일로 표시되어 기억 회상을 돕는다. 누적된 데이터로 카테고리별 시간 비율과 시간대별 패턴을 분석해 준다.

## User Stories

1. As a user, I want to see today's 24 hours displayed as a grid of 10-minute cells, so that I can visually understand my day at a glance.
2. As a user, I want to drag across multiple grid cells to select a time range, so that I can log what I did during that period without tapping each cell individually.
3. As a user, I want a bottom sheet to appear immediately after selecting a time range, so that I can assign a category without extra navigation steps.
4. As a user, I want to see preset categories (수면, 업무, 운동, 식사, 이동, 여가) ready to use on first launch, so that I can start tracking without any setup.
5. As a user, I want to create custom categories with a name and color, so that I can track activities specific to my lifestyle.
6. As a user, I want to edit or delete custom categories, so that I can keep my category list organized.
7. As a user, I want assigned time blocks to display as colored fills in the grid cells, so that I can instantly see which parts of my day are logged.
8. As a user, I want to tap an existing time block to edit or delete it, so that I can correct mistakes without re-doing the whole entry.
9. As a user, I want photos from my camera roll to automatically appear as thumbnails in the grid cells matching their taken time, so that I can recall what I was doing during that period.
10. As a user, I want to grant photo library access once and have thumbnails appear automatically thereafter, so that the experience is frictionless.
11. As a user, I want to navigate to previous days, so that I can retroactively fill in time I forgot to log.
12. As a user, I want the app to send a push notification when I have not logged anything for 3+ hours during waking hours, so that I am reminded to fill in my time without being bombarded with alerts.
13. As a user, I want to control notification settings (enable/disable, quiet hours), so that I can customize how the app prompts me.
14. As a user, I want to see a daily summary of time spent per category as a bar or pie chart, so that I can understand how I spent a specific day.
15. As a user, I want to see a weekly summary of category time ratios, so that I can spot patterns across the week.
16. As a user, I want to see a monthly summary of category time ratios, so that I can track long-term trends.
17. As a user, I want to see a heatmap of which hours of the day I use for which categories, so that I can understand my habitual routines.
18. As a user, I want to filter analytics by category, so that I can focus on a specific area of my life.
19. As a user, I want my data to be stored locally on my device without requiring an account, so that I can use the app immediately with full privacy.
20. As a user, I want the app to launch quickly to the current day's grid, so that logging feels effortless and casual.

## Implementation Decisions

### Modules

**1. TimeBlockStore**
- Central data layer using SQLite (via `sqflite` package)
- Manages CRUD for time blocks: `{id, date, startMinute, endMinute, categoryId, note?}`
- `startMinute` and `endMinute` are integers 0–1440 (minutes since midnight), stored in 10-minute increments
- Exposes reactive streams so the UI updates automatically on changes
- Deep module: all persistence logic lives here; UI never touches the database directly

**2. CategoryStore**
- Manages preset and custom categories: `{id, name, color, isPreset}`
- Seeded with default presets on first launch
- Persisted in SQLite alongside time blocks
- Exposes category list as a reactive stream

**3. PhotoLibraryService**
- Requests photo library permission on first use
- Queries local camera roll by time range (iOS: PHPhotoLibrary, Android: MediaStore via Flutter plugin)
- Returns a list of `{assetId, takenAt, thumbnailBytes}` for a given date
- Caches thumbnail bytes in memory per session to avoid repeated I/O
- Plugin: `photo_manager`

**Grid Cell Dimensions**
- Cell height: 48px (≈1.2:1 aspect ratio with 6-column layout — visually balanced, touch-friendly)
- Time label column: 48px wide
- 6 data columns: `(screenWidth - 48) / 6` each
- Total grid height: `24 rows × 48px = 1152px`

**4. GridViewModel**
- Computes which cells are filled, their colors, and which cells have photo thumbnails
- Input: time blocks for the day + photo assets for the day
- Output: list of `CellState {categoryColor?, thumbnailBytes?, isSelected}`
- Pure logic, easily unit-testable with no Flutter dependencies

**5. DragSelectionController**
- Tracks the user's drag gesture across the grid
- Outputs `selectedRange: (startMinute, endMinute)` during and after drag
- Cancels selection if user scrolls vertically past the grid
- Isolated from category assignment logic

**6. AnalyticsEngine**
- Reads all time blocks from TimeBlockStore for a date range
- Computes: category duration totals, percentages, hour-of-day frequency heatmap
- Returns plain data structs (no UI logic)
- Deep module: complex aggregation logic behind a simple query interface

**7. NotificationScheduler**
- Monitors time elapsed since last logged block during waking hours (configurable, default 07:00–23:00)
- Fires a local push notification if gap exceeds 3 hours
- Uses `flutter_local_notifications` + a background isolate or periodic check on app foreground
- Respects user's notification enable/disable and quiet hours preferences

### Data Schema (SQLite)

```
categories (id, name, colorHex, isPreset)
time_blocks (id, date TEXT, startMinute INT, endMinute INT, categoryId, note TEXT)
```

### Key Interaction Flow

1. App launches → shows today's grid (current time scrolled into view)
2. User drags across cells → DragSelectionController highlights selection
3. Finger lifts → bottom sheet slides up with category list
4. User taps category → TimeBlockStore.insert() → grid re-renders
5. PhotoLibraryService pre-fetches thumbnails for the day in the background and overlays them on matching cells

## Testing Decisions

Good tests verify **external behavior**, not implementation details. Test what goes in and what comes out — not which private methods are called.

### Modules to test

- **GridViewModel** — given a set of time blocks and photos, assert correct `CellState` output. Pure Dart, no mocks needed.
- **AnalyticsEngine** — given a list of time blocks, assert correct duration totals, percentages, and heatmap buckets. Pure Dart.
- **TimeBlockStore** — integration tests against an in-memory SQLite instance. Assert insert, update, delete, and range queries behave correctly.
- **DragSelectionController** — unit test gesture state machine: drag start, drag update, drag end, cancel. Assert output `selectedRange` is always snapped to 10-minute boundaries.

### Not tested (acceptable)
- UI widgets (brittle, slow, low ROI for this app's complexity)
- PhotoLibraryService (requires real device APIs)
- NotificationScheduler (requires OS scheduler)

## Out of Scope

- Cloud sync or multi-device support (v2)
- Social or sharing features
- Web or desktop versions
- Time block notes/descriptions (v2)
- AI-generated insights or natural language summaries
- iCloud Photos integration (no public API)
- Export to CSV/PDF

## Further Notes

- MVP priority order: Grid UI → Category assignment → Local persistence → Photo thumbnails → Analytics → Smart notifications
- Photo thumbnails are a key differentiator but should not block the MVP. Build behind a feature flag and ship when stable.
- The 10-minute grid granularity is fixed. Sub-10-minute precision is intentionally excluded to keep the UI scannable.
- Flutter package choices: `sqflite` (database), `photo_manager` (photos), `flutter_local_notifications` (push), `riverpod` (state management).
