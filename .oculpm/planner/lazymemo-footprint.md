---
oculpm_plan: v1
id: lazymemo-footprint
title: "프로젝트 용량 다이어트 — 7.1GB 중 파생물 6.9GB 를 걷고, 다시 자라지 않게"
status: done
created: 2026-09-16
updated: 2026-09-21
owner: claude-code
---

2026-09-16 실측: 프로젝트 7.1GB 중 소스·문서·git 은 30MB 남짓, 나머지는 전부 재생성 가능한 파생물이다 — spike 의 LiteRT-LM git 전체 클론 2.7GB(제품 패키지는 9/15 에 래퍼 vendoring 으로 이미 회피), 메인 .build 3.1GB(xcodebuild 잔재 out·xc-mac 포함), 업로드 끝난 xcarchive 261MB. 지우는 것과 함께 clean.sh 가 전부를 알게 하고, 제품 번들에 LiteRT dylib 이 빠져 있는 문제(build-app.sh 가 복사하지 않음 · 136MB fat)를 결정 항목으로 남긴다.

## 지금 걷는다 — 전부 재생성 가능한 파생물 {#reclaim}
- [x] spikes/LiteRTSpike/.build 3.6GB — LiteRT-LM git 클론 2.7GB·checkouts 539MB·artifacts 220MB·산출물 205MB {#spike-build}
- [x] 메인 .build 3.1GB — out 920MB·xc-mac 328MB(xcodebuild 잔재, 스크립트 참조 없음)·ios 895MB(시뮬레이터 derived data)·arm64-apple-macosx 797MB·artifacts 220MB {#main-build}
- [x] build/ 261MB — TestFlight 업로드 끝난 xcarchive 239MB · render-ui PNG 22MB {#build-dir}
- [x] ~/Library/Developer/Xcode/DerivedData/LazyMemo-* 1.0GB — 프로젝트 밖이지만 이 프로젝트 것, Xcode 꺼진 상태에서 {#derived-data}

## 다시 자라지 않게 {#prevent}
- [x] spike 가 LiteRT-LM 저장소를 통째로 받지 않게 — 루트 패키지의 vendored LiteRTLM 을 product 로 열고 spike 는 path 의존 (제품 패키지의 9/15 결정을 spike 에도) {#spike-no-clone}
- [x] scripts/clean.sh 가 spike .build · build/ · xcodebuild 잔재(out·xc-mac) · Xcode DerivedData 까지 안다 — --all 이 진짜 전부, 기본은 캐시만 {#clean-script}
- [x] README 「개발」절에 무엇이 어디에 얼마나 쌓이는지 표와 회수 명령 한 줄 {#docs-footprint}

## 제품이 받는 용량 — 결정이 필요한 것 {#product}
- [x] build-app.sh 가 libCLiteRTLM_mac.dylib(136MB fat) 을 번들에 넣지 않는다 — 실행 파일은 @rpath/@loader_path 로 찾으므로 GitHub 판은 켜지지 않을 것. 넣을지(arm64 thin 68MB)·GitHub 판에서 로컬 비서를 뺄지 결정 {#bundle-dylib}
- [x] site/media GIF 5.6MB(phone 3.8·demo 1.8) — 팔레트 재압축, mp4 우선 재생 확인 {#site-media}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-09-16T14:57:16+09:00 | #spike-build | claude-code | ☐→x | .oculpm/journal/20260916/Chores/1457_chore_footprint-diet-7gb-to-80mb.md | 3.6GB 삭제. 재빌드 시 423MB(클론 0) |
| 2026-09-16T14:57:25+09:00 | #main-build | claude-code | ☐→x | .oculpm/journal/20260916/Chores/1457_chore_footprint-diet-7gb-to-80mb.md | 3.1GB 삭제. out·xc-mac 은 xcodebuild 잔재가 아니라 Swift 6.2 swift build 의 자리 — 항목 문구 정정 |
| 2026-09-16T14:57:32+09:00 | #build-dir | claude-code | ☐→x | .oculpm/journal/20260916/Chores/1457_chore_footprint-diet-7gb-to-80mb.md | 261MB 삭제 |
| 2026-09-16T14:57:39+09:00 | #derived-data | claude-code | ☐→x | .oculpm/journal/20260916/Chores/1457_chore_footprint-diet-7gb-to-80mb.md | 1.0GB 삭제 (Xcode 닫힌 상태 확인) |
| 2026-09-16T14:57:47+09:00 | #spike-no-clone | claude-code | ☐→x | .oculpm/journal/20260916/Chores/1457_chore_footprint-diet-7gb-to-80mb.md | 루트 LiteRTLM product + spike path 의존. 빌드 7초, repositories 0B |
| 2026-09-16T14:57:54+09:00 | #clean-script | claude-code | ☐→x | .oculpm/journal/20260916/Chores/1457_chore_footprint-diet-7gb-to-80mb.md | --all 이 spike·build·dist·DerivedData 까지, 빌드 프로세스 가드 (실제로 한 번 걸림) |
| 2026-09-16T14:58:01+09:00 | #docs-footprint | claude-code | ☐→x | .oculpm/journal/20260916/Chores/1457_chore_footprint-diet-7gb-to-80mb.md | README 「개발」절 표 + clean.sh 두 모드 |
| 2026-09-16T14:58:12+09:00 | #bundle-dylib | claude-code | ☐→! | .oculpm/journal/20260916/Chores/1457_chore_footprint-diet-7gb-to-80mb.md | 사용자 결정 대기 — otool 로 @rpath 링크 확인. v0.4.0 은 LiteRT 이전이라 무사, 다음 GitHub 판부터 문제 |
| 2026-09-16T16:14:04+09:00 | #bundle-dylib | claude-code | !→x | .oculpm/journal/20260916/Bugs/1613_bug_bundle-litert-engine-dylib.md | 넣기로 결정 — arm64 thin 65MB, 번들 70MB·zip 23MB. 앱 실행 손검증은 사용자 몫 |
| 2026-09-21T19:10:54+09:00 | #site-media | claude-code | ☐→x |  | GIF 셋 9.2→6.6MB, mp4 우선 확인, 녹화 스크립트 설정 반영 |
<!-- oculpm:plan-log end -->
