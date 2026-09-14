---
schema_version: 1
type: bug
slug: "phone-shows-mac-photos"
status: done
difficulty: medium
created_at: "2026-09-15T01:48:22+09:00"
session_id: "mcp-20260915-014822"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "a21353b2-7510-4482-806f-384b70daace4"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/LazyMemo/PhotoCards.swift"
    op: create
  - path: "ios/LazyMemo/MemoEditorView.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/AttachmentStore.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/AttachmentAvailabilityTests.swift"
    op: create
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
  - path: "ios/LazyMemoUITests/ShotTests.swift"
    op: update
  - path: "ios/LazyMemo/en.lproj/Localizable.strings"
    op: update
  - path: "docs/MOBILE_DESIGN.md"
    op: update
related:
  - ref: "20260829/Bugs/0227_bug_dawn-keyword-photo-paste-paper-opacity.md"
    kind: "followup"
  - ref: "20260913/Features_to_add/0239_feature_mac-icloud-sync-and-developer-id.md"
    kind: "followup"
tags:
  - "ios"
  - "photos"
  - "icloud"
  - "mcp-tool"
---
[x] 맥에서 붙인 사진이 폰에서 안 보였다 — 폰 종이 머리에 사진 띠, iCloud 자리표는 청해서 기다린다

## 발생 원인

둘이 겹쳤다.

1. **폰 편집 화면은 사진을 그리지 않았다.** MOBILE_DESIGN §5 「사진 — 1차에서 뺀다」 그대로였다. `PaperTextView` 는 `UITextView` 하나라 본문의 `![](attachments/…)` 가 글자로만 보였다 — 사진을 붙인 사람에게는 「안 된다」다.
2. **iCloud 가 자리만 잡아 둔 사진은 청하지 않았다.** 메모 파일은 `MemoVault.requestMissingDownloads` 가 `.<이름>.md.icloud` 를 보고 내려받기를 청하지만, 사진은 메모가 아니라 거기 끼지 않았다(iCloud 동기화 일지가 "사진은 청하지 않는다" 고 적어 두었다). 그려 주더라도 폰에는 `.<ulid>.png.icloud` 만 있어 그림이 없는 상태.

## 해결 방법

- **`AttachmentStore.availability(of:)`** (Core) — 파일이 있으면 `.present`, 자리표만 있으면 `startDownloadingUbiquitousItem` 을 청하고 `.downloading`, 둘 다 없으면 `.missing`. Vault 밖 경로는 `.missing`.
- **`PhotoLoader`·`PhotoCardsView`·`PhotoViewer`** (폰) — 본문의 `MarkdownScanner.imagePaths` 를 읽어 자리 카드처럼 **종이 머리**에 앉힌다(`safeAreaInset(.top)`, 자리 카드 다음, 키보드가 오르면 접음). 한 장이면 전폭, 여럿이면 페이지 스크롤. 높이 180pt 뚜껑, 누르면 검은 바탕 전체 화면. `.downloading` 은 「iCloud 에서 내려받는 중」 카드로 0.7초마다 다시 보고(상한 60회), 오면 그림으로 바뀐다. `.missing` 은 「아직 없는 사진 — 다른 기기가 올리면 보여요」. 화면에 드는 것은 ImageIO 로 900px 다운샘플, 원본은 펼칠 때만 4096px 로 읽는다.
- 본문의 `![](…)` 줄은 감추지 않는다 — 폰은 마크다운을 꾸미지 않고, 지우면 사진이 떨어진다는 뜻이라.
- 시험 도우미 `scrolledRow` — 「지금」 띠가 목록 머리를 차지하면서 아래 줄이 첫 화면 밖·펜 바 뒤로 갔다. 줄을 찾을 때 밀어 올리고, 펜에 반쯤 가렸으면 한 번 더 민다.

## 검증

- `./scripts/test.sh` 768 통과 — 새 `AttachmentAvailabilityTests` 3개(저장한 것·자리표·없음/Vault 밖).
- XCUITest `testPhotoFromMacShowsOnThePaper` — 맥 형식 그대로 `attachments/<ulid>.png` 와 본문 참조를 심고, 종이 머리의 사진 → 전체 화면 → 닫기. 폰 스모크 15개 전부 통과, `uitest.sh --shots` 로 `shot-photo.png` 눈으로 확인. `check-l10n.sh --ios` 빠짐 0.
- 실기기에서 iCloud 자리표가 실제로 내려오는 것은 손검증 남음 (시뮬레이터에는 iCloud 가 없다).

## 메모

폰에서 사진을 **붙이는** 것과 공유 시트의 사진 받기는 여전히 다음 판이다 (§16).