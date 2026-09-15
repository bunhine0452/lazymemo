# lazymemo 개인정보 처리방침 · Privacy Policy

> 2026-09-13 · 맥 0.4.0 · 아이폰 0.1.0 (시험판). 근거는 [README 의 프라이버시 절](../README.md#프라이버시)과 코드다 — 이 문서가 코드보다 더 많이 약속하지 않는다.

## 한 문장

**lazymemo 는 서버가 없고, 계정이 없고, 당신에 대해 아무것도 모으지 않는다.** 메모는 당신 기기의 마크다운 파일이고, 두 기기 사이를 오가는 것은 당신의 iCloud 다.

## 무엇이 어디로 가나

기본 상태의 lazymemo 는 아무 데도 접속하지 않는다. 아래는 그 기본에서 벗어나는 전부이고, 하나도 빠짐없이 적는다.

| 무엇 | 나가는 것 | 어디로 | 언제 |
|---|---|---|---|
| **iCloud 동기화** | 메모 파일 전부(본문·날짜·장소·사진) | **당신의 iCloud** (애플이 옮기고 보관한다) | 맥에서 「iCloud 로 동기화…」를 **직접 누를 때**, 아이폰은 iCloud Drive 가 켜져 있을 때 |
| 지금 여기 (맥 `⌥⌘L` · 폰의 핀) | 좌표 하나 | 애플 지오코딩 (주소로 바꾸려고) | **누를 때마다**, 그때만 |
| 자리 카드 (폰) | 장소 이름 하나 | 애플 지도 검색 (좌표로 바꾸려고) | 장소가 붙은 메모를 **열 때** — 파일에 좌표가 있으면 안 나간다 |
| 「가는 길」 (폰) | 좌표와 이름 | 누른 지도 앱 (카카오맵·네이버 지도·애플 지도) | **누를 때마다** |
| Claude 연동 (맥, MCP) | 메모 본문 | Claude | `claude_desktop_config.json` 에 **직접 등록**했을 때 |
| 종이 위 ✧ 다듬기 (맥) | 그 메모 본문 | Claude | `claude` 가 깔려 있고 **누를 때마다** |
| 아침 브리핑 (맥) | 메모 제목과 시각 | Claude | 설정에서 **직접 켤 때만** (기본 꺼짐) |
| 이 기기의 비서 — 묻기·시키기·오늘·다듬기 (맥·폰) | **메모는 아무것도 안 나간다** — 모델이 이 기기 안에서 읽고 답한다 | — | 모델 파일(약 2.6GB)을 **「받기」를 직접 누를 때** 한 번 Hugging Face 에서 내려받는다. 그때 나가는 것은 파일 요청뿐이다. 모델은 iCloud·백업 밖 앱 폴더에 있고 앱 안에서 지울 수 있다 |
| 링크를 카드로 펼치기 (맥) | 주소 하나 | 그 주소 | 기본 켜짐 · 끌 수 있다 |
| 새 판 확인 (맥) | 주소 하나 (판 번호도 안 보낸다) | GitHub | 기본 켜짐 · 끌 수 있다 |

**우리에게 오는 것은 없다.** 분석 도구도, 추적기도, 광고 식별자도, 크래시 리포터도 없다. 소개 페이지도 바깥 요청이 하나도 없다.

## 권한

첫 실행에는 하나도 묻지 않는다.

- **위치 (사용 중)** — 맥의 `⌥⌘L` 이나 폰의 핀을 **처음 누를 때** 한 번. 한 번 재고 끊는다. 거절하면 다시 묻지 않는다. 폰은 「항상」 권한을 요구하지 않는다.
- **위치 (항상, 맥만)** — 「가면 떠오르게 하기」를 설정에서 **직접 켤 때만.** 좌표가 이미 적힌 메모 근처에 도착했다는 사실만 받고, 위치를 저장하지도 내보내지도 않는다.
- **캘린더 (읽기, 맥만)** — 달력 창을 처음 열 때 한 번.
- **알림** — 요구하지 않는다.

## 어디에 저장되나

- 맥: `~/Documents/lazymemo/` 또는 당신이 고른 폴더. 파생물(인덱스·창 위치·설정)은 `~/Library/Application Support/lazymemo/`.
- 아이폰: iCloud Drive 의 「LazyMemo」 폴더(컨테이너 `iCloud.io.github.bunhine0452.lazymemo`). iCloud 가 꺼져 있으면 기기 안(App Group `group.io.github.bunhine0452.lazymemo`)에만.
- 삭제한 메모는 `.trash/` 에 30일 남았다가 앱이 지운다. **lazymemo 를 지워도 메모 파일은 남는다.**

## 어린이

lazymemo 는 나이를 묻지 않고 아무것도 모으지 않는다.

## 바뀌면

이 문서와 README 프라이버시 절이 같이 바뀌고, 릴리스 노트에 적힌다.

## 연락

GitHub: https://github.com/bunhine0452/lazymemo/issues

---

# Privacy Policy (English)

> 2026-09-13 · Mac 0.4.0 · iPhone 0.1.0 (beta). This document promises no more than the code does.

**lazymemo has no server, no accounts, and collects nothing about you.** Your memos are Markdown files on your device; what travels between your devices is your own iCloud.

## What leaves the device, and where it goes

By default lazymemo connects to nothing. The table below is the complete list of exceptions.

| What | Data sent | To | When |
|---|---|---|---|
| **iCloud sync** | your memo files (text, dates, places, photos) | **your iCloud** (Apple transports and stores them) | on Mac only after you choose "Sync to iCloud…"; on iPhone whenever iCloud Drive is on |
| "Here" (Mac `⌥⌘L` · the pin on iPhone) | one coordinate | Apple geocoding (to turn it into an address) | each time you press it, and only then |
| Place cards (iPhone) | one place name | Apple Maps search (to turn it into a coordinate) | when you open a memo that has a place; not sent if the file already holds a coordinate |
| "Directions" (iPhone) | a coordinate and a name | the map app you tap (Kakao Map, Naver Map, Apple Maps) | each time you press it |
| Claude integration (Mac, MCP) | memo text | Claude | only after you register it in `claude_desktop_config.json` yourself |
| ✧ Tidy on a note (Mac) | that memo's text | Claude | only if the `claude` CLI is installed, each time you press it |
| Morning brief (Mac) | memo titles and times | Claude | only if you turn it on in Settings (off by default) |
| Link cards (Mac) | one URL | that site | on by default; can be turned off |
| On-device assistant — ask, do, today, tidy (Mac · iPhone) | **none of your memos** — the model reads and answers on this device | — | the model file (about 2.6 GB) is downloaded once from Hugging Face **when you press "Download"**; only that file request leaves. The model lives in the app folder outside iCloud and backups, and can be deleted in the app |
| Update check (Mac) | one URL (not even the version) | GitHub | on by default; can be turned off |

**Nothing comes to us.** No analytics, no trackers, no advertising identifiers, no crash reporter. The website makes no external requests either.

## Permissions

Nothing is asked at first launch.

- **Location (When In Use)** — asked once, the first time you press `⌥⌘L` (Mac) or the pin (iPhone). One fix, then off. If you decline, it never asks again. The iPhone app never requests "Always".
- **Location (Always, Mac only)** — only if you enable "Surface when I get there" in Settings yourself. It only receives the fact that you arrived near a memo that already has coordinates; it neither stores nor sends your location.
- **Calendar (read, Mac only)** — once, the first time you open the calendar window.
- **Notifications** — never requested.

## Where data lives

- Mac: `~/Documents/lazymemo/` or a folder you choose. Derived data (index, window layout, settings) in `~/Library/Application Support/lazymemo/`.
- iPhone: the "LazyMemo" folder in iCloud Drive (container `iCloud.io.github.bunhine0452.lazymemo`). With iCloud off, on-device only (App Group `group.io.github.bunhine0452.lazymemo`).
- Deleted memos stay in `.trash/` for 30 days, then the app removes them. **Uninstalling lazymemo leaves your memo files in place.**

## Children

lazymemo does not ask for age and collects nothing.

## Changes

This document and the README privacy section change together, and release notes say so.

## Contact

GitHub: https://github.com/bunhine0452/lazymemo/issues

---

## App Store Connect 「앱 개인정보」 응답 (초안 — 제출 전에 확인)

- **Data Not Collected** — 개발자에게 오는 데이터가 없다. 위치는 기기 안에서 쓰이고 애플 지오코딩에만 좌표가 가며, 메모는 사용자의 iCloud 로 간다(애플 정의의 「수집」— 개발자 서버로 전송 — 이 아니다).
- 추적(Tracking): 없음.
- 서드파티 SDK: 없음.
- 개인정보 처리방침 URL: https://bunhine0452.github.io/lazymemo/privacy/ (`site/privacy/index.html` — 이 문서를 그대로 얹은 것. 둘은 같이 고친다).
- 지원 URL: https://github.com/bunhine0452/lazymemo/issues · 마케팅 URL: https://bunhine0452.github.io/lazymemo/ko/
