// swift-tools-version: 5.10
import PackageDescription

// LiteRT-LM v0.16.0 spike — 명세 §7. 태그를 정확히 고정한다 (`main` 추적 금지).
// 제품 Package.swift 와 분리된 독립 패키지라 Core/MCP/Share Extension 은 이 엔진을 모른다.
let package = Package(
    name: "LiteRTSpike",
    platforms: [.macOS(.v14), .iOS(.v17)],
    dependencies: [
        .package(path: "../SpikeKit"),
        .package(url: "https://github.com/google-ai-edge/LiteRT-LM.git", exact: "0.16.0"),
    ],
    targets: [
        .executableTarget(
            name: "litert-spike",
            dependencies: [
                "SpikeKit",
                .product(name: "LiteRTLM", package: "LiteRT-LM"),
            ],
            path: "Sources/LiteRTSpike"
        ),
    ]
)
