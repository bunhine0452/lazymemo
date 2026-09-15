# LiteRTLM — Google LiteRT-LM v0.16.0 의 Swift 래퍼, 그대로 들여옴

출처: https://github.com/google-ai-edge/LiteRT-LM 태그 `v0.16.0` (commit 924e79c9), `swift/` 의 소스
(테스트·`apple_fm`·BUILD·Info.plist 제외). 라이선스 Apache 2.0 — `LICENSE` 동봉. **고치지 않는다.**
판을 올릴 때는 이 폴더를 통째로 바꾸고 `Package.swift` 의 xcframework URL·checksum 을 함께 바꾼다.

패키지 의존(`.package(url:…, exact:)`) 대신 소스를 들여온 이유: SwiftPM 이 그 저장소를 통째로
복제하면 2.7GB 다(모델 자산이 git 에 있다). xcframework 두 개(220MB)는 `binaryTarget` 으로 받고
checksum 으로 고정한다 — 같은 판, 같은 바이너리, 디스크만 아낀다.
