// swift-tools-version: 5.10
import PackageDescription

// Qwen3-4B-Instruct-2507/MLX 비교 경로 — 명세 §7. mlx-swift-lm 3.31.4 태그 고정 (`main` 추적 금지).
// 출하 타깃이 아니다. 최종 선택에 필요 없으면 이 패키지는 제품에 들어가지 않는다.
let package = Package(
    name: "MLXSpike",
    platforms: [.macOS(.v14), .iOS(.v17)],
    dependencies: [
        .package(path: "../SpikeKit"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", exact: "3.31.4"),
    ],
    targets: [
        .executableTarget(
            name: "mlx-spike",
            dependencies: [
                "SpikeKit",
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
            ],
            path: "Sources/MLXSpike"
        ),
    ]
)
