import Foundation
import LiteRTLM
import SpikeKit

// litert-spike — 명세 §7 spike CLI.
//   smoke : 로드 → 한국어 스트리밍 → 도중 취소 → 해제 → 다시 로드. 수치와 메모리를 찍는다.
//   bench : Tests/Fixtures/Assistant 의 80문항·속도 프롬프트로 채점·속도·메모리 보고서.
// 예)
//   swift run -c release litert-spike smoke --model ~/Library/Caches/lazymemo-models/gemma-4-E2B-it.litertlm
//   swift run -c release litert-spike bench --model … --fixtures ../../Tests/Fixtures/Assistant --out ../../docs/research/local-model-benchmark-2026-09-15.md

struct Args {
    var command: String
    var values: [String: String] = [:]
    var flags: Set<String> = []

    init(_ argv: [String]) {
        command = argv.count > 1 ? argv[1] : "help"
        var i = 2
        while i < argv.count {
            let a = argv[i]
            if a.hasPrefix("--") {
                let key = String(a.dropFirst(2))
                if i + 1 < argv.count, !argv[i + 1].hasPrefix("--") {
                    values[key] = argv[i + 1]; i += 2
                } else { flags.insert(key); i += 1 }
            } else { i += 1 }
        }
    }

    func string(_ key: String) -> String? { values[key] }
    func int(_ key: String, _ fallback: Int) -> Int { values[key].flatMap(Int.init) ?? fallback }
}

func expand(_ path: String) -> String { (path as NSString).expandingTildeInPath }

func makeGenerator(_ args: Args) throws -> LiteRTGenerator {
    guard let model = args.string("model").map(expand) else { throw SpikeError.missingArgument("--model") }
    guard FileManager.default.fileExists(atPath: model) else { throw SpikeError.modelNotFound(model) }
    let backend: Backend = args.string("backend") == "cpu" ? .cpu() : .gpu
    let cache = expand(args.string("cache") ?? "~/Library/Caches/lazymemo-models/litert-cache")
    try? FileManager.default.createDirectory(atPath: cache, withIntermediateDirectories: true)
    // 명세 §4: 폰·M1·8GB 맥 모두 4096. 16GB 이상의 8192 는 별도 실측 뒤.
    let temperature = args.string("temperature").flatMap(Float.init) ?? 1.0
    return LiteRTGenerator(
        modelPath: model, backend: backend, maxNumTokens: args.int("context", 4096), cacheDir: cache, temperature: temperature)
}

setbuf(stdout, nil)  // 스트리밍 글자와 print 의 순서가 섞이지 않게
let args = Args(CommandLine.arguments)
do {
    switch args.command {
    case "smoke":
        try await Smoke.run(generator: makeGenerator(args), args: args)
    case "bench":
        guard let fixtures = args.string("fixtures").map(expand) else { throw SpikeError.missingArgument("--fixtures") }
        let out = args.string("out").map(expand)
        let generator = try makeGenerator(args)
        let options = BenchOptions(
            repeats: args.int("repeat", 1),
            speedRepeats: args.int("speed-repeat", 3),
            kinds: args.string("kinds").map { Set($0.split(separator: ",").compactMap { QuestionKind(rawValue: String($0)) }) },
            skipSpeed: args.flags.contains("no-speed"),
            skipQuality: args.flags.contains("no-quality"),
            deviceNote: args.string("device") ?? "",
            verbose: args.flags.contains("verbose"),
            constrained: args.flags.contains("schema"))
        let report = try await BenchRunner(generator: generator, fixturesDirectory: URL(fileURLWithPath: fixtures), options: options).run()
        let markdown = report.markdown()
        if let out {
            try markdown.write(toFile: out, atomically: true, encoding: .utf8)
            print("보고서: \(out)")
        } else { print(markdown) }
    default:
        print("""
        사용법: litert-spike <smoke|bench> --model <path.litertlm> [--backend gpu|cpu] [--context 4096] [--temperature 1.0]
               bench 는 --fixtures <dir> [--out <md>] [--repeat N] [--speed-repeat N] [--kinds answer,command] [--no-speed] [--no-quality] [--schema] [--device "M4 Pro 24GB"]
        """)
    }
} catch {
    FileHandle.standardError.write("실패: \(error)\n".data(using: .utf8)!)
    exit(1)
}
