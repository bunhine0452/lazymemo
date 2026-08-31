---
schema_version: 1
type: feature
slug: "survive-reboot-login-item-welcome"
status: done
difficulty: low
created_at: "2026-08-29T17:57:17+09:00"
session_id: "20260829-003"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/LoginItem.swift"
    op: create
  - path: "Sources/LazyMemoUI/WelcomeNote.swift"
    op: create
  - path: "Sources/LazyMemoCore/Storage/SettingsStore.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Tests/LazyMemoUITests/WelcomeNoteTests.swift"
    op: create
related: []
tags:
  - "login-item"
  - "onboarding"
  - "menubar"
  - "settings"
  - "mcp-tool"
---
[x] 재부팅을 넘긴다 — 로그인 항목 스위치와, 안내서 대신 놓이는 첫 장

## 추가 기능

**이 앱은 켜져 있지 않으면 아무것도 아니다.** 바탕화면의 종이도, ⌥⌘N 도, 시각이 되어 나오는 일정도 전부 앱이 살아 있어야 성립한다. 그런데 재부팅 뒤에 앱을 다시 켜는 것은 게으른 사람이 **가장 안 하는 일**이고, v1 에는 로그인 항목이 없었다(`SMAppService` 0건). README 도 "open dist/LazyMemo.app" 이 전부였다.

그리고 처음 켠 사람에게 앱은 메뉴바 아이콘 하나가 전부라, 단축키를 모르면 **앱이 있다는 것조차 모른다.**

## 동작 흐름

**① 로그인 항목** (`LoginItem`) — `SMAppService.mainApp` 을 등록/해제한다. 권한을 묻지 않으므로 첫 실행에서 사용자를 시스템 설정으로 보내지 않는다는 §8 의 원칙을 지킨 채로 재부팅을 넘긴다. 메뉴 → 설정의 **맨 위**에 둔다: 거기 있는 항목 중 유일하게 안 켜면 앱 전체가 없어지는 것이다.

- `swift run` 으로 띄운 개발 빌드는 `.app` 번들이 아니라 등록할 몸이 없다. 그때는 스위치를 흐리게 두고 "앱 번들로 실행할 때만 됩니다" 라고 적는다 — 켤 수 없는 스위치를 멀쩡한 척 보여 주지 않는다.
- 실패를 따로 알리지 않는다. 메뉴는 열 때마다 다시 지어지고 상태를 `SMAppService.status` 로 되읽으므로, 실패하면 체크가 그냥 안 켜진다. **화면이 실제 상태를 말하는 것**이 성공/실패를 따로 알리는 것보다 정확하다.

**기본값은 꺼짐이다.** 사용자가 켜지 않은 채로 시스템 상태(로그인 항목)를 말없이 바꾸지 않는다. 대신 첫 장이 그 스위치가 어디 있는지 적어 둔다.

**② 첫 장** (`WelcomeNote`) — 온보딩 화면을 짓지 않는다. 그것은 철학 4("앱은 자기를 드러내지 않는다")를 첫 화면에서 깨는 일이다. 안내서를 앱이 아니라 **메모로** 준다: 이 앱이 무엇을 하는 물건인지 그 물건 자체로 보여 주고, 다 읽으면 그냥 지우면 된다 — 지우는 법까지 그 종이 안에 적혀 있어 읽는 것과 배우는 것이 한 번에 끝난다.

체크상자를 쓴 것도 같은 이유다. 눌러서 뒤집히는 것을 손으로 겪어 보는 것이 "체크상자를 누르면 됩니다" 라고 적는 것보다 짧다.

놓을지 말지는 **둘을 함께** 본다 — 인사한 적이 없고(`Settings.greeted`), 메모도 하나 없을 때만. `settings.json` 은 파생물이라 지워질 수 있는데(§5.1), 그때 쓰던 사람에게 안내 종이가 한 장 더 생기면 그건 안내가 아니라 치울 거리다. 인사했다는 사실은 **종이를 만들기 전에** 적는다 — 만들다 실패하는 상황이 이어지면 켤 때마다 한 장씩 쌓일 수 있다.

## 검증

- `./scripts/test.sh` — 313개 통과 (`WelcomeNoteTests` 5건 신규).
- 처음 켜면 한 장 · 두 번 켜도 한 장 · 그 장을 지워도 다시 안 놓는다 · 메모가 있는 사람에게는 설정이 지워져도 안 끼어든다 · 첫 장에 ⌥⌘N·「내일 3시」·「로그인할 때 시작」·휴지통·체크상자가 모두 적혀 있다.
- 빈 Vault 로 실제 앱을 띄워 `LAZYMEMO_MENU=1` 로 확인 — 「메모 1장 / ▪︎ 여기 적으면 됩니다」가 목록에 서고, 설정 하위 항목이 5개에서 6개로 늘었다.

## 메모

로그인 항목의 **기본값을 켜짐으로 둘지는 사용자에게 물어야 할 결정**이라 껐다. 게으름을 전제로 하는 앱에서 "설정에 들어가 켜세요" 는 사실상 아무도 안 켠다는 뜻이지만, 사용자가 켠 적 없는 시스템 상태를 앱이 말없이 바꾸는 것도 이 앱이 지켜 온 태도가 아니다. 지금은 첫 장이 그 자리를 알려 주는 선에서 멈춘다.