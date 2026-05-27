# Time Tracker — Claude 작업 지침

## 이슈 연결 규칙

**작업 시작 시:**
- 작업은 깃헙 레포의 이슈를 기반으로 진행한다.
- 번호 없이 작업 요청이 오면: `gh issue list` 실행 후 어떤 이슈인지 내용을 읽고 작업을 시작한다.
- 세션에서 커밋타이밍이 왔을 때 커밋 메시지에 작업중인 이슈넘버를 태그한다.
- 작업단위마다 새로운 브랜치를 생성하여 작업한다.
- 해당 이슈의 요구사항을 충족하여 작업 완료가 되는 커밋에서는 `resolve #<이슈번호>`로 이슈를 close한다.
- 작업 완료시 작업한 브랜치/워크트리를 정리한다.

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
