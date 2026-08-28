# lazymemo 설계문서

> 상태: v1 구현 반영 · 2026-08-28 · 근거: [`.oculpm/discussion/lazymemo-계획서/discussion.md`](../.oculpm/discussion/lazymemo-계획서/discussion.md) (resolved) · 실행 계획: [`.oculpm/planner/lazymemo-v1.md`](../.oculpm/planner/lazymemo-v1.md)

## 1. 개요

lazymemo 는 macOS 바탕화면에 상주하는 메모 + 캘린더 앱이다.

철학은 **"사용자는 게으르다"** 를 전제로 삼는 것이다. 게으름을 고치라고 요구하지 않고, 게으른 채로도 기록이 남게 만든다. 설계상 이는 두 가지 제약으로 번역된다.

1. **마찰 제거** — 앱을 "열어서" 쓰지 않는다. 메모는 항상 바탕화면에 떠 있고, 새 메모는 전역 단축키 한 번으로 시작되며, 저장 버튼은 존재하지 않는다.
2. **정리를 대신 해준다** — 사용자가 "다음 주 화요일에 치과" 라고 말하면 LLM 이 알아서 입력·분류·정리한다. 사용자가 구조를 유지할 필요가 없다.

여기에 두 개의 비기능 요구가 동등한 무게로 붙는다: **메모리를 최소로 쓸 것**, 그리고 **아마추어처럼 보이지 않을 것**. 이 둘이 동시에 걸려 있다는 점이 아래 모든 기술 결정을 지배한다.

## 2. 확정된 결정

| # | 축 | 결정 | 핵심 근거 |
|---|---|---|---|
| D1 | 프레임워크 | **네이티브 SwiftUI + AppKit** | 메모리·Liquid Glass·SF Symbols·한글 IME 를 동시에 만족하는 유일한 선택. 웹뷰는 창당 메모리와 디자인 재구현 비용을 모두 떠안는다 |
| D2 | 창 구조 | **메모당 NSWindow** | 네이티브에서 창당 비용이 싸고 드래그·리사이즈·z-order·접근성을 OS 가 처리한다 |
| D3 | LLM 경로 | **lazymemo 가 MCP 서버** (1차) | Claude Desktop 연동은 이 방향만 성립한다. API 키 불필요, 토큰은 사용자 구독 부담 |
| D4 | 저장 | **마크다운 파일 정본 + SQLite 파생 인덱스** | 사용자가 직접 열람·이동 가능, MCP 연동이 거의 공짜, 동기화는 폴더 위치로 해결 |
| D5 | 캘린더 | **자체 뷰 우선**, EventKit 은 읽기 전용으로 후순위 | 의존성·권한 0 으로 시작. LLM 이 사용자의 실제 캘린더를 지우는 경로를 처음부터 열지 않는다 |
| D6 | 삭제 | **하드 삭제 금지**, trash 이동 + 보존 기간 | LLM 이 자율 삭제하므로 되돌리기가 선택이 아니라 필수다 |
| D7 | 배포 | **소스 빌드 배포로 시작** (오픈소스) | 공증 없이 가능. 공증은 프레임워크와 무관한 문제라 나중에 붙일 수 있다 |

각 결정의 기각된 대안과 전체 논거는 discussion 문서의 `{#opt-a}`~`{#opt-i}` 에 있다.

## 3. 검증된 기술 전제

아래는 추정이 아니라 2026-08-28 이 개발 머신(macOS 26.5.2, SDK 26.5, Xcode 미설치)에서 **실제로 빌드·실행해 확인**한 결과다. D1 은 이 검증 위에 서 있다.

| 전제 | 검증 방법 | 결과 |
|---|---|---|
| Xcode 없이 빌드 가능 | `swift build` (CommandLineTools만, tools-version 6.2) | ✅ 32.57초 |
| Liquid Glass 사용 가능 | SwiftUI `.glassEffect()` 컴파일 | ✅ SDK 26.5 에 존재 |
| 메뉴바 상주 | `NSStatusItem` + `NSImage(systemSymbolName:)` | ✅ |
| 바탕화면 레벨 창 | `NSWindow.level = CGWindowLevelForKey(.desktopIconWindow) + 1` | ✅ |
| Dock 아이콘 없는 상주 | `.accessory` + `LSUIElement` | ✅ |
| 유료 계정 없이 서명 | `codesign -s -` (ad-hoc) + 수동 `.app` 조립 | ✅ |
| 공증 없는 다운로드 배포 | quarantine 부여 후 `spctl -a -t exec` | ❌ `rejected` → D7 로 회피 |

마지막 항목이 핵심이다. Gatekeeper 거부는 **다운로드된 앱 번들**에 걸리는 것이라 Tauri·Electron 으로 만들어도 동일하다. 즉 공증은 프레임워크 선택 기준이 아니며, 로컬 빌드 산출물에는 `com.apple.quarantine` 이 붙지 않아 개발과 본인 사용에는 아무 제약이 없다.

## 4. 시스템 구조

**프로세스가 둘이다.** stdio MCP 는 클라이언트가 서버 프로세스를 띄우는 구조라, Claude Desktop 이 실행 중인 앱에 붙을 수 없다. 성립하는 형태는 `lazymemo-mcp` 라는 별도 실행 파일이 뜨고 **같은 Vault 를 직접 만지는** 것이다. D4(파일이 정본) 덕분에 두 프로세스의 계약이 파일 그 자체가 되어 이 구조가 거의 공짜다. 대가는 하나 — 앱이 외부 변경을 알아야 하므로 FSEvents 감시가 필요하다.

```
┌──────────────────┐         ┌─────────────────────────────────┐
│  Claude Desktop  │──stdio──▶  lazymemo-mcp  (별도 프로세스)   │
└──────────────────┘         │   └─ MemoTools → MemoService     │
                             └──────────────┬──────────────────┘
                                            │
┌───────────────────────────────────────────┼──────────────────┐
│  LazyMemo.app (LSUIElement, .accessory)   │                  │
│   ├─ MenuBarController   (NSStatusItem, 목록·최근 삭제)       │
│   ├─ QuickCapture        (전역 단축키 ⌥⌘N → NSPopover)        │
│   ├─ NoteWindowManager   (메모당 NSWindow, 레벨·Space·복원)   │
│   ├─ CalendarWindow      (바탕화면 캘린더 뷰)                 │
│   └─ MemoStore  (@MainActor, 관찰 가능)                       │
│         └─ VaultWatcher  (FSEvents — 바깥에서 온 변경 감지)   │
├───────────────────────────────────────────┼──────────────────┤
│  Domain — LazyMemoCore (AppKit 비의존)     ▼                  │
│   ├─ MemoService   ← 앱과 MCP 가 공유하는 유일한 규칙 지점     │
│   ├─ MemoVault     (파일 CRUD, trash)                         │
│   ├─ MemoIndex     (SQLite 파생 인덱스)                       │
│   └─ LayoutStore   (창 위치·크기·디스플레이)                  │
├──────────────────────────────────────────────────────────────┤
│  Storage                                                     │
│   ├─ Vault  : 마크다운 파일  ← 정본                           │
│   └─ Derived: index.sqlite, layout.json ← 재생성 가능          │
└──────────────────────────────────────────────────────────────┘
```

**단방향 원칙:** MCP 와 UI 는 모두 `MemoService` 를 통해서만 데이터를 건드린다. `MemoService` 는 항상 파일에 먼저 쓰고, 그 다음 인덱스에 변경을 통지한다. 인덱스는 절대 정본이 될 수 없다.

**규칙을 한 곳에만 둔다.** 앱과 MCP 가 각자 파일을 다루면 "삭제는 휴지통 이동뿐"(D6) 같은 약속이 두 번 구현되고, 한쪽만 고쳐지는 순간 깨진다. `MemoService` 가 그 단일 지점이다.

## 5. 데이터 설계

### 5.1 디렉터리 레이아웃

```
<Vault>/                          # 기본 ~/Documents/lazymemo (설정으로 이동 가능)
  notes/2026/08/<ulid>.md         # ← 정본. 사용자·LLM·동기화의 대상
  .trash/<ulid>.md                # 삭제 보존 (D6)

<App Support>/lazymemo/           # ← 전부 파생. 지워도 Vault 만 있으면 복원됨
  index.sqlite
  layout.json
  settings.json
```

**Vault 를 사용자 문서 영역에 두는 이유:** 사용자가 Finder 로 열어볼 수 있어야 잠금이 없고, 폴더를 iCloud Drive 로 옮기는 것만으로 동기화가 해결된다. 별도 백엔드를 만들지 않는다.

**창 위치를 메모 파일이 아니라 `layout.json` 에 두는 이유:** 메모 파일은 사용자와 LLM 이 읽고 쓰는 대상이다. 창을 드래그할 때마다 정본 파일이 갱신되면 동기화 충돌과 무의미한 diff 가 생기고, LLM 이 파일을 다시 쓰면서 좌표를 날릴 위험이 있다. UI 상태는 기계 영역에 격리한다.

### 5.2 메모 파일 형식

```markdown
---
id: 01K3ZQ8F7N2R4M6X8B0V5T9WQY   # ULID (시간 정렬 가능)
created: 2026-08-28T16:29:50+09:00
updated: 2026-08-28T16:29:50+09:00
due: 2026-09-01                   # 선택 — 날짜만 (마감·목표)
at: 2026-09-01T14:00:00+09:00     # 선택 — 시각까지 (약속)
tags: [약속, 병원]
color: yellow
pinned: false
---
치과 예약 — 강남역 3번 출구
```

- 본문은 순수 마크다운. 앱이 없어도 읽힌다.
- `due` 와 `at` 이 캘린더 표시의 유일한 근거다. **둘 다 없으면 그냥 메모, 있으면 캘린더에도 나타난다.** 메모와 일정을 별도 타입으로 나누지 않는 것이 핵심 단순화다 — LLM 이 "약속"과 "목표"를 구분해 저장할 필요 없이 날짜 필드만 채우면 된다.
- 알 수 없는 frontmatter 키는 보존한다 (사용자가 직접 넣은 필드를 앱이 지우지 않는다).
- 휴지통에 있는 동안에는 `deleted:` 가 추가된다. 보존 기간 계산의 근거를 인덱스가 아니라 파일에 두어, 인덱스를 지워도 살아남게 한다.
- 시각은 **초 단위까지만** 적는다. 사람이 읽을 파일이기 때문이며, 그 대가로 모델도 초 미만 정밀도를 들고 있지 않는다 — 안 그러면 저장 직후 메모리와 디스크가 어긋난다.

### 5.3 파생 인덱스

`index.sqlite` 는 날짜 범위 쿼리와 전문 검색만 담당한다. 순수 파일 스캔으로는 캘린더의 "이번 달 일정" 쿼리가 메모 수에 비례해 느려지기 때문이다.

- 스키마: `memos(id, path, created, updated, due, at, color, pinned, mtime)` + `memos_fts(body)` (FTS5, `tokenize='trigram'`)
- **한국어 검색은 두 경로로 나뉜다.** `unicode61` 토크나이저는 한글 부분 일치를 못 하고, `trigram` 은 3글자 미만을 색인하지 않는다 (실측: `강남역`은 찾고 `남역`은 못 찾음). `병원`·`약속` 같은 두 글자 검색이 흔하므로 3글자 미만은 LIKE 스캔으로 떨어뜨린다.
- **불변식: 인덱스는 언제든 Vault 전체 스캔으로 재생성 가능해야 한다.** 인덱스에만 존재하는 정보를 만들지 않는다.
- 기동 시 파일 mtime 과 인덱스를 대조해 변경분만 갱신하고, 불일치가 감지되면 통째로 재생성한다.

## 6. 삭제와 되돌리기 (D6)

LLM 이 자율적으로 삭제하는 이상, 첫 오작동에 사용자 신뢰가 끝난다. 따라서 삭제 경로를 구조적으로 안전하게 만든다.

- `MemoStore.delete(id)` 는 **파일을 지우지 않는다.** `.trash/` 로 이동시키고 인덱스에서 내린다.
- 하드 삭제는 보존 기간 경과 후 앱이 수행하며, MCP 도구로는 **노출하지 않는다.** LLM 이 도달할 수 있는 코드 경로에 하드 삭제가 없다.
- `restore_memo` 로 되돌릴 수 있고, 메뉴바에 "최근 삭제" 동선을 둔다.
- 파일 이동이라 비용이 사실상 0 이다 — 이 안전장치는 D4(파일 기반) 덕분에 싸게 얻어진다.

## 7. 창 시스템

메모 하나 = `NSWindow` 하나 (D2).

- `styleMask: .borderless`, `isOpaque = false`, `backgroundColor = .clear`, 내용은 `NSHostingView` 로 SwiftUI 부착
- `level = CGWindowLevelForKey(.desktopIconWindow) + 1` — 바탕화면 위, 일반 창 아래
- `collectionBehavior = [.canJoinAllSpaces, .stationary]` — Space 를 옮겨도 따라오고 Mission Control 에서 흔들리지 않는다
- `.resizable` 을 함께 준다 — 테두리가 없어도 가장자리 끌기가 살아난다
- 위치·크기는 디스플레이 UUID 와 함께 `layout.json` 에 저장. 복원 시 **어느 화면에도 닿지 않을 때만** 주 디스플레이 안으로 끌어온다. 사용자가 일부러 화면 밖으로 걸쳐 놓은 창은 건드리지 않는다
- **창을 닫는 것은 삭제가 아니라 숨김이다.** `layout.json` 의 `hidden` 으로 기록하고 메뉴에서 다시 연다
- **동시에 띄우는 창은 24개까지.** "메모는 항상 바탕화면에 있다"는 약속과 메모리 예산이 부딪히는 지점이고, LLM 이 한 번에 여러 장을 만들 수 있다. 넘치는 메모는 메뉴 목록에서 연다

**구현 함정:** `NSHostingView` 의 기본 `sizingOptions` 는 SwiftUI 뷰의 이상적 크기를 창에 반영한다. `sizingOptions = []` 로 끄고 `contentView` 를 붙인 **뒤에** `setFrame` 을 불러야 `layout.json` 이 정본이 된다. 그러지 않으면 창 크기 복원이 조용히 깨진다.

**이 영역이 프로젝트 최대 리스크다.** Stage Manager, Mission Control, "월페이퍼 클릭 시 데스크탑 표시", 전체화면 앱, 다중 디스플레이 연결/해제가 각각 창 레벨 동작을 바꿀 수 있고 문서화가 부족하다. 그래서 계획상 다른 기능보다 **먼저 스파이크**로 검증한다 (`{#window-spike}`).

## 8. 빠른 입력

"게으름 타파"가 실제로 구현되는 지점이다.

- 전역 단축키 **⌥⌘N** → `NSPopover` 즉시 표시 → 커서 활성. **목표 150ms, 실측 중앙값 12.5ms.** 팝오버와 뷰를 앱 기동 시 미리 만들어 두고 표시만 토글하며, 애니메이션은 끈다.
- 단축키는 Carbon `RegisterEventHotKey` 로 등록한다. `CGEventTap` 은 손쉬운 사용 권한을 요구하는데, 첫 실행에서 사용자를 시스템 설정으로 보내면 "게으름 타파" 전제가 그 자리에서 무너진다. ⌘Space·⌃Space·⌃⌥Space 는 Spotlight 와 입력 소스 전환이 쓰므로 피했다.
- 한 상자가 **입력과 검색을 겸한다.** 치면 기존 메모가 걸러지고, 그대로 Return 이면 새 메모가 된다. 모드 전환이 없어야 조작 수가 준다.
- 저장 버튼 없음. 입력이 멈추면 디바운스 후 자동 저장, 팝오버가 닫히면 즉시 flush.
- 편집기는 `NSTextView` 기반. **한글 IME 조합을 OS 에 맡기는 것이 목적이며, 이는 D1 의 주요 근거 중 하나다.** 조합 중 상태를 가로채는 로직을 넣지 않는다.

**조합을 지키는 세 규칙** (`MemoTextSync`, 테스트로 고정):

1. `hasMarkedText()` 면 모델의 문자열을 되밀지 않는다 — 자모가 흩어진다.
2. 내용이 같아도 대입하지 않는다 — 대입만으로 선택 범위가 초기화된다.
3. 반영할 때 커서를 원래 자리로 되돌린다 — 안 그러면 문서 끝으로 튄다.

자동 저장도 조합 중에는 걸지 않는다. 그러지 않으면 파일에 `ㅊ` 같은 중간 자모가 저장된다.

## 9. LLM 연동 (D3)

### 9.1 방향

Claude Desktop 은 외부 앱이 프롬프트를 보내고 결과를 받는 경로를 제공하지 않는다 (URL 스킴은 단방향, AppleScript 비활성 — 실측 확인). 성립하는 유일한 연동은 **lazymemo 가 MCP 서버가 되고 Claude Desktop 이 이를 호출**하는 방향이다.

부수 효과가 크다: API 키가 필요 없고 토큰 비용을 사용자 Claude 구독이 부담한다. 오픈소스 저장소에 키를 넣을 수 없다는 제약과도 맞아떨어진다.

### 9.2 도구 인터페이스 (초안)

| 도구 | 인자 | 비고 |
|---|---|---|
| `list_memos` | `query?`, `tag?`, `from?`, `to?`, `limit?` | 인덱스 경유 |
| `create_memo` | `text`, `due?`, `at?`, `tags?`, `color?` | 날짜 필드가 있으면 캘린더에도 반영 |
| `update_memo` | `id`, `text?`, `due?`, `at?`, `tags?` | 미지정 필드는 보존 |
| `delete_memo` | `id` | **trash 이동만.** 하드 삭제 아님 |
| `restore_memo` | `id` | trash 에서 복원 |
| `list_trash` | — | 휴지통 목록. `restore_memo` 에 넘길 id 를 얻는 유일한 길이라 추가했다 |

`update_memo` 는 넘기지 않은 필드를 보존하고, 빈 문자열을 넘기면 그 날짜를 지운다. 도구 인자 오류는 JSON-RPC 오류가 아니라 `isError: true` 결과로 돌려준다 — 모델이 읽고 스스로 고칠 수 있어야 하기 때문이다.

앱 내부 버튼으로 LLM 을 부르는 기능(F-2)은 후순위다. 필요해지면 `claude` CLI 서브프로세스 경로로 붙인다 — 사용자 구독 인증을 재사용할 수 있어 키 요구를 계속 피할 수 있다.

### 9.3 프라이버시

메모 본문이 외부로 나가는 경로는 MCP 연동뿐이며, 이는 사용자가 `claude_desktop_config.json` 에 직접 등록해야 활성화된다. 즉 **기본 상태에서 lazymemo 는 네트워크를 쓰지 않는다.** README 에 명시한다.

## 10. 캘린더 (D5)

`due` / `at` 을 가진 메모가 캘린더에 나타난다 — 별도 이벤트 타입은 없다 (§5.2).

- 1차: 자체 캘린더 뷰. 월/주 그리드를 바탕화면에 배치 (DesktopCal 레퍼런스).
- 쿼리는 SQLite 인덱스의 날짜 범위 조회로 처리.
- EventKit 연동은 **읽기 전용으로만** 후순위 검토. 쓰기를 열면 LLM 이 사용자의 실제 캘린더를 수정·삭제할 수 있게 되어 위험이 급상승한다.

## 11. 성능 예산 — 실측 결과

| 항목 | 목표 | 실측 | 근거·방법 |
|---|---|---|---|
| 메모 10장 표시 시 RSS | ≤ 100MB | **88.8MB** | `scripts/verify-performance.sh` (release 빌드, 창 10개 확인 후 3초 안정화) |
| idle CPU | 0% | **0.0%** | 같은 스크립트, `top` 순간 표본 3회 중 최댓값 |
| 단축키 → 커서 표시 | ≤ 150ms | **중앙값 12.5ms** (최소 4.1 / 최대 34.3) | `scripts/measure-capture.sh`, release 12회 |
| 생각 → 저장 조작 수 | ≤ 2회 | **2회** | ⌥⌘N → 타자 → (자동 저장). 저장 버튼 없음 |
| 재부팅 후 복원 | 100% | **통과** | `scripts/verify-restore.sh` — 껐다 켠 뒤 창 좌표·크기·내용 일치 |
| 한글 IME 조합 오류 | 0건 | **테스트 6건 통과** | `MemoTextSyncTests` — `setMarkedText` 로 조합 상태를 만들어 검증 |

두 가지를 밝혀 둔다.

- **RSS 88.8MB 는 예산에 여유가 크지 않다.** 창 24개 상한(§7)이 이 숫자를 지키는 장치다. 상한을 올리려면 먼저 재측정해야 한다.
- **지연 측정은 단축키 이후 구간만 잰다.** 전역 단축키를 프로그램으로 누르려면 손쉬운 사용 권한이 필요해서, Carbon 이 이벤트를 넘겨주는 시간은 빠져 있다. 예산 대비 여유가 10배라 그 몫을 더해도 안전하다고 본다.

## 12. 배포 (D7)

오픈소스. 공증 없이 시작한다.

1. **소스 빌드 (1차)** — `swift build` 한 줄. quarantine 이 붙지 않아 Gatekeeper 문제가 발생하지 않는다.
2. **Homebrew cask** — 사용자가 늘면. 오픈소스 맥 앱의 표준 경로.
3. **Developer ID + 공증** — 더 늘면. `notarytool` 이 CommandLineTools 에 이미 있어 인증서만 발급받으면 CI 에서 자동화된다. **지금 결정할 필요가 없다.**

GitHub Releases 로 바이너리만 뿌리는 방식은 권하지 않는다. macOS 15 부터 우클릭-열기 우회가 사라져 사용자가 시스템 설정까지 들어가야 하므로 마찰이 크다.

## 13. 미결 사항

**사람이 눈으로 확인해야 하는 것** (자동화 불가 — 화면 기록 권한과 물리 조작이 필요하다)

- Stage Manager 를 켠 상태에서 바탕화면 창이 어떻게 보이는가 (`{#env-stage-manager}`)
- "월페이퍼 클릭 시 데스크탑 표시"에 메모 창도 함께 쓸려나가는가 (`{#env-wallpaper-click}`) — 깨지면 `desktopIconWindow + 1` 레벨 자체를 다시 봐야 한다
- 유리 재질과 hover 조작 버튼의 실제 인상 (§7 의 "아마추어처럼 보이지 않을 것")
- ⌥⌘N 이 사용자의 다른 앱과 충돌하지 않는가

**미룬 결정**

- EventKit 읽기 연동 도입 시점 (D5 의 후순위)
- 앱 안에서 LLM 을 부르는 경로 — `claude` CLI 서브프로세스 (F-2)
- Homebrew cask 등록 시점
- 메모 수천 장 규모의 인덱스 갱신 전략 (현재 설계는 수백 장 기준)
- 창 24개 상한을 사용자가 조절할 수 있게 할 것인가

## 14. 참조

- 결정 근거 전문: [`.oculpm/discussion/lazymemo-계획서/discussion.md`](../.oculpm/discussion/lazymemo-계획서/discussion.md)
- 실행 계획: [`.oculpm/planner/lazymemo-v1.md`](../.oculpm/planner/lazymemo-v1.md)
- 레퍼런스 제품: Windows Sticky Notes, DesktopCal, macOS Stickies.app, Raycast Notes
