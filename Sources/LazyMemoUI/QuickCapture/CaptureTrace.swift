import AppKit
import LazyMemoCore

/// 조작이 어디서 끊기는지 보기 위한 임시 추적 (`LAZYMEMO_TRACE=1`).
///
/// Mission Control 로 Space 를 옮긴 뒤 "아이콘도 단축키도 안 먹는다" 는 결함은
/// 밖에서 창 목록만 봐서는 원인이 갈리지 않는다 — 창이 안 뜨는 것인지,
/// 입력이 앱에 닿지도 않는 것인지가 같은 그림으로 보이기 때문이다.
/// 그래서 입력이 들어온 순간부터 창을 올리기까지의 길목마다 한 줄씩 남긴다.
enum CaptureTrace {
    static let isOn = ProcessInfo.processInfo.environment["LAZYMEMO_TRACE"] == "1"

    private static let location: URL = {
        AppPaths.standard().support.appending(path: "trace.log", directoryHint: .notDirectory)
    }()

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    static func log(_ message: @autoclosure () -> String) {
        guard isOn else { return }
        let line = "[\(clock.string(from: Date()))] \(message())\n"
        FileHandle.standardError.write(Data(line.utf8))
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: location) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: location)
        }
    }
}
