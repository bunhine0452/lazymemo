---
schema_version: 1
type: feature
slug: "site-relaunch-live-capture-hero"
status: done
difficulty: medium
created_at: "2026-09-15T22:41:29+09:00"
session_id: "20260915-003"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "site/ko/index.html"
    op: update
  - path: "site/index.html"
    op: update
  - path: "site/img/capture.png"
    op: update
  - path: "site/img/capture-asking.png"
    op: create
  - path: "site/img/capture-answer.png"
    op: create
  - path: "site/img/capture-applied.png"
    op: create
  - path: "site/img/capture-candidates.png"
    op: create
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
related:
  - ref: "20260915/Features_to_add/2225_feature_capture-assistant-merged.md"
    kind: "followup"
  - ref: "20260915/Features_to_add/1340_feature_site-launch-edition-store-switch.md"
    kind: "followup"
tags:
  - "site"
  - "marketing"
  - "design"
  - "capture"
  - "mcp-tool"
---
[x] 소개 페이지 새 판

## 추가 기능

사용자: 「네가 사진찍은거 랜딩 사이트에도 올려 그리고 랜딩 사이트좀 완전 새롭게 만들어서 센세이션하게」, 그리고 「앱 띄우면 보이는 잠깐 메모 한장 이 문구는 지워도돼. 로고와 lazymemo도」.

- **히어로 = 살아 있는 상자.** 앱의 빠른 입력 말풍선을 HTML 로 그대로 지어 실제 대화를 재생한다: 서술 타자 → 날짜·자리 칩 → ⌘↵ → 「약속 시간이 언제인가요?」+칩 → 「12시야」 → 종이가 잠깐 나옴 → 「치과 언제였지?」 → 읽는 중 → 답+인용+근거. 끝나면 「다시 재생」. `prefers-reduced-motion` 이면 마지막 장면만. 바깥 자원 없음(pages.yml 검사 통과).
- **네 장면**: `scripts/render-ui.sh` 로 떠낸 capture-asking/answer/applied/candidates PNG(밝음·어둠 나란히, `shrink-png.py` 로 40% 절감)를 가로 띠로. 기존 종이·달력·서랍·메뉴 그림과 두 영상은 그대로. 실수로 덮어쓴 기존 site/img 다섯 장은 git 에서 되돌렸다.
- **글과 형**: 헤드라인 「적어 두고 잊어도 됩니다. 물으면 메모가 답하니까.」 대문자 눈썹 라벨·가운뎃점 메타·카드 격자를 걷고, 규칙 넷은 세이지 줄의 문단. 출시 스위치(`data-store`)·App Store 배지·받기·파일·Claude·프라이버시 절은 다른 세션의 미커밋 판을 이어받았다(그 hunk 가 이 커밋에 포함됨).
- 영어판은 한국어판에서 생성(같은 CSS·스크립트, 문구만 영어).
- **앱**: 상자의 머리 줄(로고·lazymemo·「잠깐, 메모 한 장」)을 걷고 닫기 × 만 오른쪽 위 겹침. 렌더 넷을 다시 떠서 사이트에 올렸다.

## 동작 흐름

로컬 서버로 띄워 Chrome 에서 1360·430 폭을 스크린샷으로 점검 — 폰 절의 글 상자가 「복사」 단추의 `.copy` 규칙을 뒤집어쓰던 것(테두리·작은 글자)을 `.words` 로 고쳤고, 매달 아이콘이 없는 페이지에서 허공을 가리키던 말풍선 꼬리를 뺐고, 장면 사이 숨을 늘렸다. 영어 헤드라인은 넉 줄로 접혀 폭·크기를 조정.

## 검증

- 한국어·영어 페이지 모두 외부 자원 grep 통과. Chrome 에서 히어로 재생(서술→되묻기→종이→답)·네 장면 띠·폰 절·받기 절 확인, 430px 폭도 확인.
- 커밋 `b3cc4e7`, 푸시 → pages.yml 이 낸다. 실제 배포 결과 페이지는 확인하지 않았다(워크플로 실행 확인은 별도).