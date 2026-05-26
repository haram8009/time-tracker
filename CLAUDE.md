# Time Tracker — Claude 작업 지침

## 이슈 연결 규칙

**작업 시작 시:**
- 사용자가 `#번호` 또는 이슈 번호를 명시하면 그 번호를 세션 내내 커밋에 사용
- 번호 없이 작업 요청이 오면: `gh issue list` 실행 후 어떤 이슈인지 사용자에게 확인 (추측 금지)

## 커밋 규칙

**커밋 타이밍 — 아래 조건 중 하나 충족 시 커밋:**
- 새 파일/모듈 구현 완료
- `flutter test` 전체 통과 확인 후
- 독립적인 기능 수정 완료

**커밋 전 필수 체크:**
```bash
flutter analyze   # 0 issues
flutter test      # all pass
```

**커밋 메시지 형식:**
```
<타입>: <설명> (#<이슈번호>)
```

타입: `feat` / `fix` / `test` / `refactor` / `chore`

예시:
```
feat: AnalyticsEngine computeDailyStats 구현 (#11)
test: AnalyticsEngine 단위 테스트 추가 (#11)
```

**커밋하지 않을 때:**
- `flutter analyze` 에러 있을 때
- 빌드가 깨진 상태

## Push 정책
- 자동 push 없음. 사용자가 명시적으로 요청 시에만 push.

## 브랜치 규칙
- 현재: main 브랜치 직접 커밋
- 향후 브랜치 필요 시: `issue-<번호>-<짧은설명>` (예: `issue-11-analytics`)

## 프로젝트 컨텍스트
- 상세 컨텍스트: `.claude/handoff.md`
- PRD: `PRD.md`
