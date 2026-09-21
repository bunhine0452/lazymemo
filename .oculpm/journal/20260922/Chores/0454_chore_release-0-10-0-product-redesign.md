---
schema_version: 1
type: chore
slug: "release-0-10-0-product-redesign"
status: done
difficulty: high
created_at: "2026-09-22T04:54:13+09:00"
session_id: "20260922-003"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "54528a1e-487d-482a-9760-2f4dc8885b53"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/Memo.swift"
    op: update
  - path: ".github/workflows/ci.yml"
    op: update
  - path: "ios/LazyMemo.xcodeproj/project.pbxproj"
    op: update
  - path: "Sources/LazyMemoCore/Version.swift"
    op: update
  - path: "Resources/Info.plist"
    op: update
  - path: "README.md"
    op: update
  - path: "docs/CHANGELOG.md"
    op: update
related:
  - ref: "20260922/Chores/0250_chore_handoff-release-regressions-pass.md"
    kind: "followup"
  - ref: "20260921/Chores/2315_chore_release-0-9-4-testflight.md"
    kind: "followup"
tags:
  - "release"
  - "testflight"
  - "ci"
  - "swift-6.3"
  - "plan:lazymemo-product-value"
  - "mcp-tool"
---
[x] 0.10.0 배포 — 적은 것을 놓치지 않게(인계서 묶음 1~5): GitHub 판 + TestFlight 아이폰·맥, 그리고 CI 의 Swift 6.3.3 이 Memo 를 잘못 풀던 것

사용자: 「배포해」. 0.9.4 → **0.10.0** — 입력·정리·상태의 계약을 일부러 바꾼 판이라 셋째 자리가 아니다.

## 한 일

- 커밋 넷: 다른 세션의 폰 달력 넘김 수정(`c4220c1`, 일지 있음) · 묶음 1~5(`1ad88ad`) · 9/18~22 일지·플랜 기록(`a98fa0d`) · 판 올림(`75b03b6` — `MARKETING_VERSION` 여섯 자리·`Version.swift`·`Info.plist` 0.10.0 (22), README 「이번 판 — 0.10.0」, 0.9.4 는 CHANGELOG). 이어 `94b9811` 고침과 `c865339` CI.
- TestFlight: 아이폰·맥 각각 `Upload succeeded` **두 번** — 첫 업로드(03:31·03:34) 뒤 아래 고침을 넣고 다시(04:41·04:44). ASC 가 빌드 번호를 올린다. dSYM 경고는 지난 판과 같다(추론 엔진 프레임워크).
- GitHub 판: 태그 `v0.10.0` → release 워크플로 → `lazymemo-0.10.0.zip`(24.9MB)+sha256, 홈브루 탭 갱신. ad-hoc 서명(서명·공증 시크릿 없음 — 지난 판들과 같다). 소개 페이지는 pages 워크플로가 밀었다.
- `build/ios`(281MB)·홈의 DerivedData 삭제, `clean.sh`.

## CI 가 죽던 것 — 원인과 고침

태그를 밀자 release·ci 둘 다 시험 프로세스가 **signal 5/6** 로 죽었다(「freed pointer was not the last allocation」). 로컬(Xcode 27, Swift 6.4)은 1,142 초록. 러너는 macOS 26.6.2 / Xcode 26.6 / Swift 6.3.3 이고 Xcode 27 은 없다.

진단 가지(`ci-diag`)에서 **캐시 없이 직렬**로 돌리니 `RoutePlannerTests.fullConversation` 에서 매번 죽었고, 자국을 심으니 길을 적는 Task 클로저의 **끝**(몸통은 다 돈 뒤)이었다. 0.9.4 소스로는 같은 직렬 주행이 1,092개를 다 돈다. 0.9.4 에 `Memo`/`MemoFile` 의 새 필드 넷(kept·conflictOf·done·archived)만 얹어도 죽는다 — **`Memo` 가 256바이트(0.9.4)에서 320바이트로 넘어가자** 6.3.3 이 그것을 든 비동기 프레임의 task 할당을 LIFO 로 안 풀었다. 고침: 드물게 찍히는 표시 여섯(deleted·tidied·kept·conflictOf·done·archived)을 불변 `Marks` 상자로(`Memo` 320→232바이트, 바깥 이름·값 의미·파일 형식 그대로, `==` 는 내용). 캐시 없이 직렬 1,142 통과 → 태그를 고친 커밋으로 옮겨(아직 아무것도 안 나간 태그) 다시 밀었다.

덤으로 본 것: ci 의 `.build` 캐시가 `restore-keys` 로 옛 빌드를 물어 오면 새 구조체 배치와 낡은 오브젝트가 섞여 **다른 신호(10)** 로 죽는다. 정확히 같은 소스가 아니면 `swift package clean` 하도록 했다(artifacts·checkouts 는 남긴다). 재시도한 release 첫 판은 시험 시작 직후 SIGPIPE(13) — 러너 쪽 파이프, 다시 돌리니 통과.

## 검증

- 러너: 캐시 없이 직렬 `Test run with 1142 tests in 172 suites passed`, release 워크플로 success(시험 통과·묶기·내보내기·탭 갱신). 로컬: 전체 1,142 통과, `Memo` 232바이트 확인.
- TestFlight 처리 완료·테스터 배포는 ASC 에서 사용자가 본다.

## 메모

- 이 판의 TestFlight 첫 업로드 둘(빌드 번호 낮은 쪽)은 상자 고침 전의 소스다 — 동작은 같지만 ASC 에서 뒤의 빌드를 쓰면 된다.
- `Memo` 에 필드를 더 얹을 때는 232바이트를 넘기지 말 것 — 넘겨야 하면 상자에 넣는다. 러너에 Xcode 27 이 오면 이 제약은 풀린다.