# lazymemo

> macOS 바탕화면에 상주하는 메모 + 캘린더. **사용자는 게으르다**를 전제로 설계했다.

앱을 "열어서" 쓰지 않는다. 메모는 항상 바탕화면에 떠 있고, 새 메모는 `⌥⌘N` 한 번으로 시작되며, **저장 버튼이 없다.** 정리는 Claude 가 대신한다.

메모는 당신 컴퓨터의 마크다운 파일이다. lazymemo 를 지워도 메모는 남는다.

## 요구 사항

- macOS 26 (Tahoe) 이상
- Swift 6.2 이상 — **Xcode 불필요**, Command Line Tools 로 빌드된다
  ```sh
  xcode-select --install
  ```

## 빌드와 실행

```sh
./scripts/build-app.sh     # dist/LazyMemo.app 생성 + ad-hoc 서명
open dist/LazyMemo.app
```

로컬에서 빌드한 앱에는 `com.apple.quarantine` 이 붙지 않아 Gatekeeper 경고 없이 바로 열린다. 이것이 소스 빌드를 1차 배포 경로로 삼은 이유다 ([설계문서 §12](docs/DESIGN.md)).

개발 중 반복 실행은 번들 조립 없이도 된다.

```sh
swift run LazyMemo
```

## 쓰는 법

| | |
|---|---|
| `⌥⌘N` | 빠른 입력. 화면 위쪽 가운데에 뜬다. 치면 기존 메모가 걸러지고, 그대로 Return 이면 새 메모가 된다 |
| 메뉴바 아이콘 **좌클릭** | 빠른 입력 |
| 메뉴바 아이콘 **우클릭** | 메모 목록 · 흐름 · 최근 삭제 · 메모 폴더 열기 |
| 메모 창 드래그 | 어디를 잡아도 끌린다. 가장자리로 크기 조절 |
| 메모 창 `×` | **숨기기다. 삭제가 아니다.** 메뉴에서 다시 연다 |

메모에 날짜가 있으면 캘린더에도 나타난다. 메모와 일정을 따로 만들지 않는다 — `due`(날짜) 또는 `at`(시각) 칸이 채워진 메모가 곧 일정이다.

### 메모는 어디에 있나

```
~/Documents/lazymemo/
  notes/2026/08/01K3ZQ....md   ← 정본. Finder 로 열어도, 텍스트 에디터로 고쳐도 된다
  .trash/                       ← 삭제한 메모 (30일 보존)
```

이 폴더를 iCloud Drive 안으로 옮기면 동기화가 된다. 별도 백엔드가 없다.

`~/Library/Application Support/lazymemo/` 아래는 전부 파생물이다 — 통째로 지워도 위 폴더만 있으면 복원된다.

## Claude 연동 (선택)

lazymemo 는 MCP 서버를 함께 빌드한다. 등록하면 Claude Desktop 에서 이렇게 쓸 수 있다.

> "다음 주 화요일 오후 2시에 치과 예약 잡아줘"
> "이번 달 일정 뭐 있어?"
> "장보기 메모 지워줘"

```sh
./scripts/install-mcp.sh --dry-run   # 무엇이 바뀌는지 먼저 본다
./scripts/install-mcp.sh             # 등록 (기존 설정은 백업된다)
./scripts/install-mcp.sh --remove    # 해제
```

등록 후 Claude Desktop 을 완전히 종료했다가 다시 열어야 한다.

**API 키가 필요 없다.** lazymemo 가 Claude 를 호출하는 것이 아니라 Claude 가 lazymemo 를 호출하는 방향이라, 토큰 비용은 사용자의 Claude 구독이 부담한다.

### 삭제 안전장치

Claude 가 메모를 지울 수 있으므로, **영구 삭제하는 도구를 아예 만들지 않았다.** `delete_memo` 는 `.trash/` 로 옮기는 것까지만 하고 `restore_memo` 로 되돌릴 수 있다. 영구 삭제는 앱이 30일 보존 기간이 지난 뒤에만 수행한다.

이건 규칙이 아니라 배선이다 — MCP 서버가 호출할 수 있는 코드에 하드 삭제 함수 자체가 없다.

## 프라이버시

**기본 상태에서 lazymemo 는 네트워크를 쓰지 않는다.** 메모가 컴퓨터 밖으로 나가는 유일한 경로는 위의 MCP 연동이고, 그건 당신이 직접 등록해야 켜진다. 등록을 해제하면 다시 닫힌다.

## 디자인 철학 — 「흐릿하게 남는다」

사용자가 게으르다는 것을 결함이 아니라 **전제**로 삼는다. 그 전제를 끝까지 밀면 화면은 네 문장으로 정해진다.

**1. 완성을 요구하지 않는다.** 쓰다 만 것, 제목 없는 것, 날짜 없는 것이 정상 상태다. 빈 칸도, 채우라는 표시도, 저장 버튼도 없다.

**2. 시간이 유일한 구조다.** 게으른 사람은 폴더도 태그도 유지하지 않는다. 그래서 캘린더가 격자가 아니라 **흐름**이고, `내일 오후 3시 치과` 라고 적으면 앱이 알아서 날짜를 읽는다. 형식을 배우게 하지 않는다.

**3. 오래된 것은 스스로 물러난다.** 시간이 지난 메모는 조용히 바랜다. 정리하지 않아도 화면이 정돈된다. 다만 **고정한 것과 다가오는 일정은 바래지 않는다.** 포인터를 올리면 즉시 되살아난다.

**4. 앱은 자기를 드러내지 않는다.** 기본 상태의 메모는 글자와 종이뿐이다. 머리글도 아이콘 줄도 색 점도 없고, 조작은 포인터가 올 때 내용 위에 겹쳐 뜬다.

**재질은 하나 — 종이.** 유리(`glassEffect`)를 메모·흐름·빠른 입력에서 차례로 시도했다가 모두 되돌렸다. 반투명한 면 위의 글은 씻겨 나가고, 바탕화면 사진이 무엇이든 글은 읽혀야 한다. 떠 있다는 느낌은 그림자와 크기와 자리가 만든다.

**아이콘은 쓰다 만 메모다.** 첫 줄은 반듯하고 둘째 줄은 끝으로 갈수록 가늘어지며 흘러내린다. 게으름을 그릇의 모양이 아니라 글씨의 태도로 말한다. 디자인 파일이 아니라 **코드가 원본**이다.

```sh
./scripts/make-icon.sh    # Resources/AppIcon.icns + 메뉴바 아이콘 + 미리보기
./scripts/render-ui.sh    # 실제 뷰를 라이트/다크로 렌더 → build/ui/*.png
```

기각한 안들과 자세한 근거는 [설계문서 §14](docs/DESIGN.md) 에 있다.

## 개발

```sh
./scripts/test.sh                 # 단위 테스트 (115개)
./scripts/verify-notes.sh         # 바탕화면 창이 실제로 뜨는지
./scripts/verify-mcp.sh           # MCP 대화 전체 (15항목)
./scripts/verify-restore.sh       # 껐다 켠 뒤 복원
./scripts/verify-performance.sh   # 메모리·CPU 예산
./scripts/measure-capture.sh      # 빠른 입력 지연
./scripts/render-ui.sh            # UI 를 PNG 로 렌더
./scripts/make-icon.sh            # 아이콘 다시 그리기
```

`scripts/test.sh` 는 그냥 `swift test` 가 아니다 — Xcode 없이 swift-testing 을 돌리려면 프레임워크와 실행 시 dylib 이 서로 다른 디렉터리에 있어 rpath 를 두 개 넣어야 한다. 그 지식이 스크립트 안에 있다.

### 구조

```
Sources/
  LazyMemoCore/   도메인·저장. AppKit 비의존이라 GUI 없이 테스트된다
  LazyMemoUI/     AppKit·SwiftUI 셸
  LazyMemo/       진입점 (main.swift 한 줄)
  LazyMemoMCP/    MCP 서버 — Claude Desktop 이 띄우는 별도 프로세스
```

앱과 MCP 서버는 같은 `MemoService` 를 쓴다. "파일에 먼저 쓰고 인덱스에 통지한다", "삭제는 휴지통 이동뿐" 같은 규칙이 두 곳에 따로 있으면 한쪽만 고쳐지는 순간 깨지기 때문이다.

## 설계

- [설계문서](docs/DESIGN.md) — 무엇을 만드는가, 실측 결과
- [결정 근거](.oculpm/discussion/lazymemo-계획서/discussion.md) — 왜 이 결정인가 (기각된 대안 포함)

| | 결정 |
|---|---|
| 프레임워크 | 네이티브 SwiftUI + AppKit (웹뷰 없음) |
| 창 구조 | 메모 하나당 `NSWindow`, 바탕화면 레벨 |
| 저장 | 마크다운 파일이 정본, SQLite 는 파생 인덱스 |
| LLM | lazymemo 가 MCP 서버 — API 키 불필요 |
| 삭제 | 하드 삭제 없음. 휴지통 이동 + 복원 |
| 편집기 | `NSTextView` — 한글 IME 조합을 OS 에 맡긴다 |
| 캘린더 | 격자가 아니라 흐름. 오늘부터 아래로 |
| 마크다운 | 치는 대로 꾸며지되 파일에는 원문 그대로 |
| 첨부 | Vault 안의 진짜 파일. 상대 경로로 참조 |
| 아이콘 | 코드로 그린다. 저장소에 정체 모를 바이너리를 두지 않는다 |

## 라이선스

MIT © 2026 Kim Hyunbin
