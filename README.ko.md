# Time Tracker

하루를 어떻게 보냈는지 소급 입력하는 미니멀 iOS/Android 앱. 타이머 없이, 10분 단위 그리드를 드래그하고 카테고리를 탭 한 번으로 지정한다.

[English README](README.md)

## 스크린샷

<!-- TODO: 스크린샷/GIF 추가 예정 — 랜딩페이지 준비 중 -->

## 주요 기능

- **10분 단위 그리드** — 144칸으로 하루 전체를 한눈에
- **롱프레스 드래그** — 자연스럽게 시간 범위 선택, 모드 전환 없음
- **카테고리 원탭** — 바텀 시트에서 수면·업무·운동·식사 등 즉시 지정
- **사진 썸네일 자동 표시** — 카메라롤 사진이 촬영 시간 셀에 자동으로 표시되어 기억 회상 보조
- **분석** — 일·주·월 카테고리별 통계와 시간대 히트맵
- **로컬 저장** — 기기 내 저장, 계정 불필요

## 기술 스택

| 영역 | 라이브러리 |
|---|---|
| UI | Flutter, Riverpod |
| 저장소 | sqflite |
| 사진 | photo_manager |
| 차트 | fl_chart |
| 알림 | flutter_local_notifications |
| 설정 | shared_preferences |

## 아키텍처

```
lib/
├── features/         # 화면 단위 UI
├── core/             # 모델, 테마, 공유 위젯
└── services/         # 크로스커팅 서비스

core/
├── TimeBlockStore    — SQLite CRUD + 반응형 스트림
├── CategoryStore     — 프리셋 및 사용자 정의 카테고리
├── GridViewModel     — 순수 함수 기반 셀 상태 계산
├── DragSelectionReducer — 제스처 → 선택 범위 (순수, 테스트됨)
├── AnalyticsEngine   — 집계 쿼리 (일/주/월)
└── NotificationScheduler — 로컬 알림, 활동 공백 감지
```

주요 설계 결정은 [`docs/adr/`](docs/adr/)에 기록되어 있습니다.

## 시작하기

```bash
cd src
flutter pub get
flutter run
```

Flutter 3.x 및 iOS/Android 기기 또는 시뮬레이터가 필요합니다.
