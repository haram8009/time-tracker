# CategoryDeletion: 카테고리 삭제 시 기록 처리 방식

카테고리를 삭제할 때 해당 카테고리로 기록된 TimeBlock을 함께 지울지 보존할지 결정해야 한다. 삭제 이유가 두 가지로 나뉘기 때문이다: 실수로 만든 카테고리(기록도 틀린 데이터) vs 더 이상 쓰지 않는 카테고리(기록은 유효한 데이터).

## Decision

삭제 시 선택지를 제공한다.

- **기록도 삭제:** TimeBlock hard delete (categoryId 기준) + Category row hard delete
- **기록 보존:** Category를 RetiredCategory로 전환 (isHidden=1), TimeBlock은 그대로 유지

RetiredCategory의 TimeBlock은 그리드에서 원래 색상으로 표시되고 분석에도 정상 포함된다. 이를 위해 그리드/분석 레이어는 hidden 포함 전체 카테고리를 fetch해 colorMap을 빌드한다. 카테고리 선택 바텀시트만 isHidden=0 필터를 유지한다.

## Considered Options

- **항상 기록도 삭제:** 단순하지만 과거 데이터가 유효한 케이스(은퇴 카테고리)를 커버 못 함
- **항상 기록 보존:** 그리드/분석에서 고아 TimeBlock 표시 로직 필요. 기록도 지우고 싶은 케이스(실수 수정) 불편
- **삭제 시 선택(채택):** 두 케이스 모두 커버. TimeBlock 스키마 변경 없이 Category isHidden 필드 재활용
