# Time Tracker — Domain Glossary

## Core Concepts

**Cell**
10분 단위 그리드의 최소 단위. 하루 144개. index 0 = 00:00, index 143 = 23:50.

**GridRow**
1시간(60분)을 나타내는 그리드 행. 6개의 Cell로 구성. 총 24개의 GridRow가 하루를 표현.

**TimeBlock**
연속된 하나 이상의 Cell에 할당된 카테고리 기록. `{id, date, startMinute, endMinute, categoryId}`. Cell 단위로 저장되지 않고, 시작/끝 분(minute)으로 저장.

**Category**
TimeBlock에 할당되는 활동 유형. `{id, name, colorHex, isPreset}`. 프리셋(수면, 업무 등)과 사용자 정의 카테고리로 구분.

**DragSelection**
롱프레스 후 드래그로 선택된 Cell 범위. startIndex~endIndex 사이의 모든 Cell을 선형 연속 선택. 선택 완료 후 카테고리 바텀시트로 진입.

**LongPressDrag**
그리드의 주 입력 제스처. 셀을 롱프레스하면 햅틱+시각 피드백과 함께 드래그 선택 모드 진입. 일반 스크롤과 드래그 선택을 구분하는 메커니즘.

**BlockMerge**
새 TimeBlock이 기존 TimeBlock과 인접하거나 겹치고, 같은 Category인 경우 단일 TimeBlock으로 합치는 동작. 양쪽에 같은 카테고리 블록이 있을 경우 세 블록 전체를 병합.

**CasualCategoryCreation**
카테고리 선택 바텀시트 내에서 이름만 입력해 새 카테고리를 즉시 생성하는 흐름. 색상은 자동 배정. 설정 화면 진입 없이 인라인으로 완료.
