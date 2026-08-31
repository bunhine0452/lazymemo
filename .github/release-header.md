macOS 바탕화면에 상주하는 메모 + 캘린더. **사용자는 게으르다**를 전제로 설계했다.

메모는 당신 컴퓨터의 마크다운 파일이다. **lazymemo 를 지워도 메모는 남는다.**

## 설치

```sh
brew tap bunhine0452/lazymemo
brew install --cask lazymemo
```

또는 소스에서 — **이쪽이 1차 배포 경로다.**

```sh
git clone https://github.com/bunhine0452/lazymemo.git
cd lazymemo && ./scripts/build-app.sh && open dist/LazyMemo.app
```

macOS 26 (Tahoe) 이상. Xcode 는 필요 없다 (`xcode-select --install`).

**이 앱은 아직 공증받지 않았다.** 그래서 cask 는 설치 뒤 검역 딱지를 떼어 낸다 —
미봉책이고, Developer ID 를 받는 즉시 사라진다. 붙어 있는 `lazymemo-{{VERSION}}.zip` 을
직접 내려받아 쓰면 그 딱지가 그대로 붙어 macOS 15 부터는 열리지 않으므로,
brew 를 쓰거나 소스에서 빌드하는 편이 맞다.

---
