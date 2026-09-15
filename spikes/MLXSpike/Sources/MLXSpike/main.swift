import Foundation
import SpikeKit

// mlx-spike — Qwen3-4B-Instruct-2507/MLX 비교 경로. litert-spike 와 같은 bench 인자.
//   swift run -c release mlx-spike bench --model ~/Library/Caches/lazymemo-models/Qwen3-4B-Instruct-2507-4bit \
//       --fixtures ../../Tests/Fixtures/Assistant --out ../../docs/research/local-model-benchmark-<date>-mlx.md

func expand(_ path: String) -> String { (path as NSString).expandingTildeInPath }

var values: [String: String] = [:]
var flags: Set<String> = []
let argv = CommandLine.arguments
let command = argv.count > 1 ? argv[1] : "help"
var i = 2
while i < argv.count {
    let a = argv[i]
    if a.hasPrefix("--") {
        let key = String(a.dropFirst(2))
        if i + 1 < argv.count, !argv[i + 1].hasPrefix("--") { values[key] = argv[i + 1]; i += 2 } else { flags.insert(key); i += 1 }
    } else { i += 1 }
}

do {
    guard command == "bench" else {
        print("사용법: mlx-spike bench --model <dir> --fixtures <dir> [--out <md>] [--repeat N] [--speed-repeat N] [--kinds …] [--no-speed] [--no-quality] [--device …] [--context 4096]")
        exit(0)
    }
    guard let model = values["model"].map(expand) else { throw SpikeError.missingArgument("--model") }
    guard FileManager.default.fileExists(atPath: model) else { throw SpikeError.modelNotFound(model) }
    guard let fixtures = values["fixtures"].map(expand) else { throw SpikeError.missingArgument("--fixtures") }
    let generator = MLXGenerator(directory: URL(fileURLWithPath: model), maxContext: values["context"].flatMap(Int.init) ?? 4096)
    let options = BenchOptions(
        repeats: values["repeat"].flatMap(Int.init) ?? 1,
        speedRepeats: values["speed-repeat"].flatMap(Int.init) ?? 3,
        kinds: values["kinds"].map { Set($0.split(separator: ",").compactMap { QuestionKind(rawValue: String($0)) }) },
        skipSpeed: flags.contains("no-speed"), skipQuality: flags.contains("no-quality"),
        deviceNote: values["device"] ?? "", verbose: flags.contains("verbose"))
    let report = try await BenchRunner(generator: generator, fixturesDirectory: URL(fileURLWithPath: fixtures), options: options).run()
    let markdown = report.markdown()
    if let out = values["out"].map(expand) {
        try markdown.write(toFile: out, atomically: true, encoding: .utf8)
        print("보고서: \(out)")
    } else { print(markdown) }
} catch {
    FileHandle.standardError.write("실패: \(error)\n".data(using: .utf8)!)
    exit(1)
}
