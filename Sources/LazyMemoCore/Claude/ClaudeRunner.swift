import Foundation

// `Process` 는 macOS 에만 있다. 폰에는 `claude` CLI 도 없으니 이 파일 전체가 맥의 것이다.
#if os(macOS)
/// `claude` 를 한 번 부르고 답을 받는다.
///
/// **이 앱이 처음 갖는 「기다리는 상태」가 여기서 온다** (`{#claude-wait-state}`).
/// 지금까지 이 앱의 모든 조작은 즉시 끝났다 — 저장도, 지우기도, 날짜 인식도.
/// 그래서 «기다림» 을 말하는 낱말이 화면에 하나도 없었다.
///
/// 여기서 정하는 것은 세 가지다.
///
/// 1. **끝나지 않는 것은 없다.** 상한을 넘기면 끊는다. 답이 영영 안 오는 종이는
///    사용자에게 «고장» 이고, 고장은 되돌릴 수 없다.
/// 2. **stdin 으로 글을 준다.** 인자에 실으면 긴 메모가 길이 상한에 걸리고,
///    따옴표가 든 글은 새는 자리가 된다.
/// 3. **stderr 는 파일로 받는다.** 파이프로 받으면 그쪽이 64KB 를 넘기는 순간
///    양쪽이 서로를 기다리며 멈춘다 — 그 교착은 재현이 어렵고 사용자에게만 난다.
public struct ClaudeRunner: Sendable {
    public enum Failure: Error, Equatable, CustomStringConvertible {
        case notFound
        case timedOut
        case failed(Int32)
        case empty

        public var description: String {
            switch self {
            case .notFound: L("claude 를 실행하지 못했습니다")
            case .timedOut: L("답이 오지 않아 그만두었습니다")
            case .failed: L("claude 가 답하지 못했습니다")
            case .empty: L("빈 답이 왔습니다")
            }
        }
    }

    public let cli: ClaudeCLI
    public let timeout: Duration

    public init(cli: ClaudeCLI, timeout: Duration = .seconds(90)) {
        self.cli = cli
        self.timeout = timeout
    }

    public func ask(_ prompt: String, about text: String) async throws -> String {
        let answer = try await withCheckedThrowingContinuation { continuation in
            // 파이프 읽기는 막힌다. 협력 스레드에서 막으면 다른 일까지 세우므로
            // 바깥 큐로 내보낸다.
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result { try run(prompt, text) })
            }
        }

        let cleaned = ClaudePrompts.clean(answer)
        guard !cleaned.isEmpty else { throw Failure.empty }
        return cleaned
    }

    private func run(_ prompt: String, _ text: String) throws -> String {
        let process = Process()
        process.executableURL = URL(filePath: cli.path)
        process.arguments = cli.arguments(for: prompt)

        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output

        let log = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-claude-\(ProcessInfo.processInfo.processIdentifier).log")
        FileManager.default.createFile(atPath: log.path, contents: nil)
        process.standardError = (try? FileHandle(forWritingTo: log)) ?? FileHandle.nullDevice

        do { try process.run() } catch { throw Failure.notFound }

        // 다 쓰고 닫아야 상대가 읽기를 끝낸다.
        input.fileHandleForWriting.write(Data(text.utf8))
        try? input.fileHandleForWriting.close()

        let deadline = Date().addingTimeInterval(TimeInterval(timeout.components.seconds))
        let watchdog = Thread {
            while process.isRunning {
                if Date() >= deadline { process.terminate(); return }
                Thread.sleep(forTimeInterval: 0.2)
            }
        }
        watchdog.start()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationReason != .uncaughtSignal else { throw Failure.timedOut }
        guard process.terminationStatus == 0 else { throw Failure.failed(process.terminationStatus) }
        return String(decoding: data, as: UTF8.self)
    }
}
#endif

/// Claude 에게 시키는 말. **문장이 곧 제품이다** (`MemoPrompts` 와 같은 자리).
public enum ClaudePrompts {
    /// 종이 한 장을 다듬는다.
    ///
    /// 규칙 넷을 문장에 박았다 — ① **뜻을 바꾸지 않는다**(없는 내용을 더하면
    /// 그건 다듬은 것이 아니라 다른 메모다), ② 짧아진다(길어지면 치울 것이
    /// 하나 더 생긴다), ③ 날짜·장소·이름은 손대지 않는다(이 앱이 읽는 값이다),
    /// ④ 본문만 답한다(인사와 코드펜스는 그대로 메모에 남는다).
    public static var tidy: String { tidy() }

    /// 사용자의 말로 시킨다 — 한국어로 시키면 영어 메모도 한국어 투로 돌아온다.
    public static func tidy(locale: Locale = Words.locale) -> String {
        L("""
        아래는 사용자의 메모다. 읽기 좋게 다듬어라.

        - 뜻을 바꾸지 마라. 없는 내용을 더하지 마라.
        - 흐트러진 줄을 정리하고, 나열은 «- » 목록으로, 할 일은 «- [ ] » 로.
        - 짧게. 원문보다 길어지면 다듬은 것이 아니다.
        - 날짜·시각·장소·사람 이름은 글자 그대로 두어라.

        답에는 다듬은 메모 본문만 담아라. 인사도, 설명도, 코드펜스도 붙이지 마라.
        """, locale: locale)
    }

    /// 아침에 놓는 종이 한 장 (`MorningBrief`).
    ///
    /// **셋을 넘기지 말라고 문장에 박았다.** 스무 개를 늘어놓는 답은 게으른
    /// 사람에게 «치워야 할 것» 을 하나 더 만든다 — `MemoPrompts` 의 「오늘
    /// 뭐부터」와 같은 규칙이다.
    public static var morningBrief: String { morningBrief() }

    public static func morningBrief(locale: Locale = Words.locale) -> String {
        L("""
        아래는 오늘 사용자의 메모다. 오늘 손대야 할 것을 **세 개만** 골라라.

        - 셋을 넘기지 마라. 고르라고 부른 것이지 늘어놓으라고 부른 것이 아니다.
        - 각각 «- » 한 줄. 왜 오늘인지는 짧게 덧붙여라.
        - 시각이 정해진 것이 있으면 그것부터.
        - 아무것도 급하지 않으면 그렇게 한 줄로만 적어라.

        답에는 그 목록만 담아라. 인사도, 설명도, 코드펜스도 붙이지 마라.
        """, locale: locale)
    }

    /// 답을 메모에 그대로 넣을 수 있게 다듬는다.
    ///
    /// 「코드펜스를 붙이지 마라」고 적어도 모델은 종종 붙인다. 그것을 그대로
    /// 넣으면 메모 전체가 코드 덩어리로 꾸며진다 — **말로 막고 코드로 한 번 더 막는다.**
    public static func clean(_ answer: String) -> String {
        var lines = answer
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        if lines.first?.hasPrefix("```") == true {
            lines.removeFirst()
            if lines.last?.trimmingCharacters(in: .whitespaces) == "```" { lines.removeLast() }
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
