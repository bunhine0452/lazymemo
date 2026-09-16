// swift-tools-version: 5.10
import PackageDescription

// LiteRT-LM v0.16.0 spike — 명세 §7. 엔진은 루트 패키지가 들여온 래퍼(Sources/LiteRTLM, v0.16.0 고정)를
// path 로 빌려 쓴다 — `.package(url:…, exact:)` 로 받으면 모델 자산이 든 저장소를 2.7GB 복제한다
// (Sources/LiteRTLM/README.md 와 같은 이유). 의존 방향은 spike → 루트 한쪽이라 제품 타깃
// (Core/MCP/Share Extension)은 여전히 이 spike 를 모른다.
let package = Package(
    name: "LiteRTSpike",
    // 루트 패키지의 최소 판을 따른다 — 그보다 낮으면 SwiftPM 이 product 를 내주지 않는다.
    platforms: [.macOS("26.0"), .iOS("26.0")],
    dependencies: [
        .package(path: "../SpikeKit"),
        .package(name: "LazyMemo", path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "litert-spike",
            dependencies: [
                "SpikeKit",
                .product(name: "LiteRTLM", package: "LazyMemo"),
            ],
            path: "Sources/LiteRTSpike"
        ),
    ]
)
