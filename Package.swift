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
        .executable(name: "lazymemo-assistant-bench", targets: ["LazyMemoAssistantBench"]),
        .library(name: "LazyMemoUI", targets: ["LazyMemoUI"]),
        .library(name: "LazyMemoPlaces", targets: ["LazyMemoPlaces"]),
        .library(name: "LazyMemoCore", targets: ["LazyMemoCore"]),
        .library(name: "LazyMemoReminders", targets: ["LazyMemoReminders"]),
        .library(name: "LazyMemoSpotlight", targets: ["LazyMemoSpotlight"]),
        .library(name: "LazyMemoAssistant", targets: ["LazyMemoAssistant"]),
        .library(name: "LazyMemoLocalLiteRT", targets: ["LazyMemoLocalLiteRT"]),
        .library(name: "LazyMemoAssistantUI", targets: ["LazyMemoAssistantUI"]),
        // spikes/LiteRTSpike 가 path 의존으로 같은 래퍼를 쓴다 — 저장소 2.7GB 클론을 spike 에서도 피한다 (Sources/LiteRTLM/README.md).
        .library(name: "LiteRTLM", targets: ["LiteRTLM"]),
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
            dependencies: ["LazyMemoCore", "LazyMemoPlaces", "LazyMemoReminders", "LazyMemoSpotlight", "LazyMemoAssistantUI"],
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
        // 메모를 시스템 검색(Spotlight)에 — 앱을 열지 않고도 찾힌다. 폰과 맥이 같이 쓰고,
        // Core 에 두지 않는 이유는 Reminders 와 같다: MCP 서버·테스트까지 CoreSpotlight 를 들지 않게.
        .target(
            name: "LazyMemoSpotlight",
            dependencies: ["LazyMemoCore"],
            path: "Sources/LazyMemoSpotlight",
            resources: [.process("Resources")]
        ),
        // 자리를 지도의 점으로 — MapKit 에 묻는 일. 폰과 맥의 종이가 같이 쓰고,
        // Core 에 두지 않는 이유는 MCP 서버까지 MapKit 을 들지 않게 하려는 것.
        .target(
            name: "LazyMemoPlaces",
            dependencies: ["LazyMemoCore"],
            path: "Sources/LazyMemoPlaces"
        ),
        // 로컬 비서의 계약과 조정자 — 요청·근거·제안된 변경·provider 프로토콜 (docs/JARVIS_IMPLEMENTATION.md §3).
        // 추론 엔진을 링크하지 않는다. 엔진 어댑터는 provider 를 구현하는 별도 타깃에 두고,
        // Core·MCP·Share Extension 은 이 타깃조차 의존하지 않는다.
        .target(
            name: "LazyMemoAssistant",
            dependencies: ["LazyMemoCore"],
            path: "Sources/LazyMemoAssistant"
        ),
        // 비서 화면 — 맥과 폰이 같은 SwiftUI 를 쓴다. 모델 다운로드 패널·질문·제안 실행·되돌리기.
        .target(
            name: "LazyMemoAssistantUI",
            dependencies: ["LazyMemoCore", "LazyMemoAssistant", "LazyMemoLocalLiteRT"],
            path: "Sources/LazyMemoAssistantUI",
            resources: [.process("Resources")]
        ),
        // 앱 파이프라인 벤치 — fixture 80문항을 Coordinator·검증·해석까지 태워 사용자가 받는 결과를 채점한다.
        // 제품 번들에 들어가지 않는 개발용 실행 파일. 실모델은 --model 로 받는다.
        .executableTarget(
            name: "LazyMemoAssistantBench",
            dependencies: ["LazyMemoCore", "LazyMemoAssistant", "LazyMemoLocalLiteRT"],
            path: "Sources/LazyMemoAssistantBench"
        ),
        // LiteRT-LM 엔진 어댑터 — 앱 두 개만 링크한다. 확장·MCP·테스트는 링크하지 않는다.
        .target(
            name: "LazyMemoLocalLiteRT",
            dependencies: ["LazyMemoAssistant", "LiteRTLM"],
            path: "Sources/LazyMemoLocalLiteRT",
            // 래퍼의 Conversation 이 Sendable 이 아니다 — 래퍼와 같은 모드로 컴파일한다.
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Google LiteRT-LM v0.16.0 의 Swift 래퍼를 그대로 들여온 것 (Sources/LiteRTLM/README.md).
        // 바이너리는 공식 릴리스의 xcframework 를 checksum 으로 고정. 래퍼는 Swift 5 모드로 그대로 컴파일.
        .target(
            name: "LiteRTLM",
            dependencies: [
                .target(name: "CLiteRTLM", condition: .when(platforms: [.iOS])),
                .target(name: "CLiteRTLM_mac", condition: .when(platforms: [.macOS])),
            ],
            path: "Sources/LiteRTLM",
            exclude: ["LICENSE", "README.md"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .binaryTarget(
            name: "CLiteRTLM",
            url: "https://github.com/google-ai-edge/LiteRT-LM/releases/download/v0.16.0/CLiteRTLM.xcframework.zip",
            checksum: "4e0f683da07566ee79c143d2d58d387f77052b0e6a41562c969e5d2728fc9f4b"
        ),
        .binaryTarget(
            name: "CLiteRTLM_mac",
            url: "https://github.com/google-ai-edge/LiteRT-LM/releases/download/v0.16.0/CLiteRTLM_mac.xcframework.zip",
            checksum: "3ae6c876abd74614b1869bfc40cb4d0b892981363564740268b1f8ac5cf895a4"
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
            name: "LazyMemoAssistantTests",
            dependencies: ["LazyMemoAssistant"],
            path: "Tests/LazyMemoAssistantTests"
        ),
        // 실모델 스위트 — LAZYMEMO_MODEL_PATH 가 있을 때만 돈다. 평소 `swift test` 에서는 건너뛴다.
        .testTarget(
            name: "LazyMemoLocalLiteRTTests",
            dependencies: ["LazyMemoLocalLiteRT"],
            path: "Tests/LazyMemoLocalLiteRTTests"
        ),
        .testTarget(
            name: "LazyMemoRemindersTests",
            dependencies: ["LazyMemoReminders"],
            path: "Tests/LazyMemoRemindersTests"
        ),
        // 가는 길 — ODsay 응답 읽기·되물음의 갈래·짧은 지도 링크 읽기. 네트워크는 가짜가 선다.
        .testTarget(
            name: "LazyMemoPlacesTests",
            dependencies: ["LazyMemoPlaces", "LazyMemoCore"],
            path: "Tests/LazyMemoPlacesTests",
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "LazyMemoSpotlightTests",
            dependencies: ["LazyMemoSpotlight", "LazyMemoCore"],
            path: "Tests/LazyMemoSpotlightTests"
        ),
    ]
)
