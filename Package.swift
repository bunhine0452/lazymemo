// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LazyMemo",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "LazyMemo", targets: ["LazyMemo"]),
        .executable(name: "lazymemo-mcp", targets: ["LazyMemoMCP"]),
        .library(name: "LazyMemoUI", targets: ["LazyMemoUI"]),
        .library(name: "LazyMemoCore", targets: ["LazyMemoCore"]),
    ],
    targets: [
        // 진입점만. 실행 파일 타깃은 테스트에서 import 할 수 없으므로
        // main.swift 한 줄 빼고 전부 LazyMemoUI 로 내렸다.
        .executableTarget(
            name: "LazyMemo",
            dependencies: ["LazyMemoUI"],
            path: "Sources/LazyMemo"
        ),
        // MCP 서버 — Claude Desktop 이 stdio 로 띄우는 별도 프로세스.
        // AppKit 에 의존하지 않으며 LazyMemoCore 만 공유한다 (설계문서 §9).
        .executableTarget(
            name: "LazyMemoMCP",
            dependencies: ["LazyMemoCore"],
            path: "Sources/LazyMemoMCP"
        ),
        // 앱 셸 — AppKit/SwiftUI. 도메인 로직을 두지 않는다.
        .target(
            name: "LazyMemoUI",
            dependencies: ["LazyMemoCore"],
            path: "Sources/LazyMemoUI",
            resources: [.process("Resources")]
        ),
        // 도메인·저장 계층 — AppKit 비의존. 테스트와 MCP 서버가 공유한다.
        .target(
            name: "LazyMemoCore",
            path: "Sources/LazyMemoCore"
        ),
        .testTarget(
            name: "LazyMemoCoreTests",
            dependencies: ["LazyMemoCore"],
            path: "Tests/LazyMemoCoreTests"
        ),
        .testTarget(
            name: "LazyMemoUITests",
            dependencies: ["LazyMemoUI"],
            path: "Tests/LazyMemoUITests"
        ),
    ]
)
