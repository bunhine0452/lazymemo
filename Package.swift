// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LazyMemo",
    // 표에 없는 말을 하는 사람에게는 영어를 보인다. 한국어 원문은 코드의 열쇠 그대로라
    // 표가 비어 있어도 한국어 사용자는 아무것도 잃지 않는다 (Words.swift).
    defaultLocalization: "en",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .executable(name: "LazyMemo", targets: ["LazyMemo"]),
        .executable(name: "lazymemo-mcp", targets: ["LazyMemoMCP"]),
        .library(name: "LazyMemoUI", targets: ["LazyMemoUI"]),
        .library(name: "LazyMemoPlaces", targets: ["LazyMemoPlaces"]),
        .library(name: "LazyMemoCore", targets: ["LazyMemoCore"]),
        .library(name: "LazyMemoReminders", targets: ["LazyMemoReminders"]),
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
            path: "Sources/LazyMemoMCP",
            resources: [.process("Resources")]
        ),
        // 앱 셸 — AppKit/SwiftUI. 도메인 로직을 두지 않는다.
        .target(
            name: "LazyMemoUI",
            dependencies: ["LazyMemoCore", "LazyMemoPlaces", "LazyMemoReminders"],
            path: "Sources/LazyMemoUI",
            resources: [.process("Resources")]
        ),
        // 다시 보기 — 기기별 로컬 알림과 그 설정 화면. 폰과 맥이 같이 쓰고, Core 에
        // 두지 않는 이유는 MCP 서버·테스트까지 UserNotifications 를 들지 않게 하려는 것.
        .target(
            name: "LazyMemoReminders",
            dependencies: ["LazyMemoCore"],
            path: "Sources/LazyMemoReminders",
            resources: [.process("Resources")]
        ),
        // 자리를 지도의 점으로 — MapKit 에 묻는 일. 폰과 맥의 종이가 같이 쓰고,
        // Core 에 두지 않는 이유는 MCP 서버까지 MapKit 을 들지 않게 하려는 것.
        .target(
            name: "LazyMemoPlaces",
            dependencies: ["LazyMemoCore"],
            path: "Sources/LazyMemoPlaces"
        ),
        // 도메인·저장 계층 — AppKit 비의존. 테스트와 MCP 서버가 공유한다.
        .target(
            name: "LazyMemoCore",
            path: "Sources/LazyMemoCore",
            resources: [.process("Resources")]
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
        .testTarget(
            name: "LazyMemoRemindersTests",
            dependencies: ["LazyMemoReminders"],
            path: "Tests/LazyMemoRemindersTests"
        ),
    ]
)
