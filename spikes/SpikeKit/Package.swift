// swift-tools-version: 5.10
import PackageDescription

// 엔진과 무관한 벤치 뼈대 — fixture 읽기·채점·속도/메모리 기록·보고서.
// LiteRTSpike 와 MLXSpike 가 같은 채점기를 쓰게 하려고 따로 뗐다.
// 제품 타깃(Package.swift 의 LazyMemoCore 등)은 이 패키지를 모른다.
let package = Package(
    name: "SpikeKit",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "SpikeKit", targets: ["SpikeKit"])],
    targets: [.target(name: "SpikeKit", path: "Sources/SpikeKit")]
)
