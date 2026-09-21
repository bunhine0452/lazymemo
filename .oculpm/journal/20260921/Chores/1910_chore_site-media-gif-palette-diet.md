---
schema_version: 1
type: chore
slug: "site-media-gif-palette-diet"
status: done
difficulty: low
created_at: "2026-09-21T19:10:51+09:00"
session_id: "20260921-001"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "0b60d3b9-67f4-4690-9c09-74b70b505cd7"
language: "ko"
verified_by_user: false
files_touched:
  - path: "site/media/demo.gif"
    op: update
  - path: "site/media/phone.gif"
    op: update
  - path: "site/media/route.gif"
    op: update
  - path: "scripts/record-demo.sh"
    op: update
  - path: "ios/scripts/record-demo.sh"
    op: update
related: []
tags:
  - "footprint"
  - "site"
  - "media"
  - "gif"
  - "clean"
  - "mcp-tool"
---
[x] site/media GIF 셋을 다시 뽑아 9.2MB→6.6MB, 홈의 낡은 DerivedData 220MB 회수

## 한 일

플랜 `lazymemo-footprint` 의 마지막 항목 `#site-media`.

- **mp4 우선 재생 확인** — 세 자리(맥 데모·폰·가는 길) 모두 `<video autoplay muted loop playsinline poster=…><source src="….mp4"><img src="….gif"></video>` 라 GIF 는 `<video>` 를 못 그리는 브라우저의 폴백일 뿐, 보통은 내려받지도 않는다. GIF 가 진짜로 보이는 자리는 README(GitHub 가 mp4 를 못 그린다)의 demo·phone 둘.
- **팔레트 재압축** — mp4 원본에서 `max_colors 160/128 → 96`, `bayer_scale 4 → 5`(디더 잡음이 LZW 를 망친다), 맥 데모 fps 12 → 10, 폰·가는 길은 8 그대로. 가는 길은 360px 로 따로 뽑혀 있던 것을 다른 폰 GIF 와 같은 300px 로. demo 2.73→2.31MB · phone 3.14→2.73MB · route 3.28→1.59MB, 합 9.15→6.63MB (−28%). 6fps·80색까지 내리면 5.4MB 지만 타자·창 움직임이 끊겨 보여 안 했다.
- 두 녹화 스크립트(`scripts/record-demo.sh`·`ios/scripts/record-demo.sh`)의 ffmpeg 팔레트 설정을 같은 값으로 — 다음에 다시 찍어도 같은 무게.
- **홈의 `~/Library/Developer/Xcode/DerivedData/LazyMemo-bgsjk…` 220MB** 를 지웠다(Xcode 꺼진 상태, 9/18 일지가 봤던 잔재). `.build` 는 2.5GB(out 1.1·ios 1.1·artifacts 0.2) — 규칙이 정한 평상시 크기라 `--all` 은 안 돌렸다.

## 검증

- 원본·새 인코딩의 같은 시각 프레임을 나란히 붙여(ffmpeg hstack) 눈으로 봤다 — 맥 데모(달력·종이·서랍), 폰(키보드·칩), 가는 길(링크 입력) 셋 다 색 띠나 깨짐 없이 구분이 안 간다.
- `du -sh site/media` 13M → 10M. 파일 하나 4MB 이하 규칙 유지.

## 메모

- gifsicle 이 없어 ffmpeg 만 썼다. 더 줄이려면 `--lossy` 가 있는 gifsicle 이 다음 손.
- 바뀐 GIF 세 벌은 git 에 약 6.6MB 를 더한다(.git 34MB) — 미디어는 자주 갈지 않는다.