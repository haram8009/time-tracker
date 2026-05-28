# Time Tracker

A minimal iOS/Android app for logging how you spend your day — no timers, no friction. Tap back through your day on a 10-minute grid and assign categories in one tap.

[한국어 README](README.ko.md)

## Screenshot

<!-- TODO: add screenshots/GIF — landing page coming soon -->

## Features

- **10-minute grid** — 144 cells represent your full day at a glance
- **Long-press drag** — select a time range naturally, no mode switching
- **One-tap category** — assign sleep, work, exercise, meals, and more from a bottom sheet
- **Photo thumbnails** — camera roll photos appear automatically in matching time cells to jog your memory
- **Analytics** — daily, weekly, and monthly summaries with category breakdowns and hourly heatmaps
- **Local-first** — all data stored on-device, no account required

## Tech Stack

| Layer | Libraries |
|---|---|
| UI | Flutter, Riverpod |
| Persistence | sqflite |
| Photos | photo_manager |
| Charts | fl_chart |
| Notifications | flutter_local_notifications |
| Prefs | shared_preferences |

## Architecture

```
lib/
├── features/         # Screen-level UI
├── core/             # Models, theme, shared widgets
└── services/         # Cross-cutting services

core/
├── TimeBlockStore    — SQLite CRUD + reactive streams
├── CategoryStore     — preset & custom categories
├── GridViewModel     — pure-function cell state computation
├── DragSelectionReducer — gesture → selected range (pure, tested)
├── AnalyticsEngine   — aggregation queries (daily/weekly/monthly)
└── NotificationScheduler — local push, waking-hours gap detection
```

Key design choices are documented in [`docs/adr/`](docs/adr/).

## Getting Started

```bash
cd src
flutter pub get
flutter run
```

Requires Flutter 3.x and a connected iOS or Android device/simulator.
