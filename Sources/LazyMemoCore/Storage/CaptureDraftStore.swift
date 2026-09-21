import Foundation
import Observation

/// 빠른 입력이 **들고 있던 글** — 앱을 껐다 켜도 남는다.
///
/// 상자는 esc 로 닫아도 적던 글을 기억한다 (설계문서 §8). 그런데 그 기억이
/// 프로세스 메모리에만 있으면 **앱이 죽는 순간 같이 죽는다** — 판을 갈면
/// 앱이 스스로 닫혔다 뜨고, 재부팅도 로그아웃도 같다. 세 줄 적어 두고
/// 다른 일을 하다 돌아온 사람에게 그것은 「저장 안 된 메모가 사라졌다」다.
///
/// 저장하지 않는 이유는 그대로다 — 이 상자는 검색을 겸하므로 닫을 때
/// 메모로 만들면 찾으려고 친 낱말이 메모가 되어 쌓인다. 그래서 **메모가
/// 아니라 초안**으로, 정본(Vault)이 아니라 파생물 자리(Application Support)에
/// 둔다. 지워도 메모는 안 다치고, 확정하는 순간 없어진다.
///
/// 타자마다 디스크를 두들기지 않는다. 잠깐 미뤘다 쓰고, 상자가 닫히거나
/// 앱이 끝날 때는 기다리지 않고 바로 쓴다 (`flush`).
///
/// **못 적으면 말한다** (`trouble`). 초안은 메모가 아니지만 「껐다 켜도 남는다」는
/// 약속은 이 파일이 지키는 것이라, 파일이 안 써지는 동안 그 약속은 거짓이다.
/// 조용히 삼키면 사람은 앱을 껐다 켠 뒤에야 안다 — 그때는 글이 없다.
/// 그래서 실패를 들고 있다가 화면이 「이번 실행 동안만 들고 있어요」라 적게 하고,
/// 다음 타자나 `retry` 에 다시 적어 본다.
@MainActor @Observable
public final class CaptureDraftStore {
    private let location: URL
    @ObservationIgnored private var pending: Task<Void, Never>?
    /// 마지막으로 파일에 적은 것. 같은 글을 두 번 쓰지 않는다.
    @ObservationIgnored private var written: String
    @ObservationIgnored private var latest: String

    /// 초안을 파일에 못 적었다 — 기계의 말. 화면은 사람의 말로 바꿔 적고 이것은 도움말로만 보인다.
    /// 다음 쓰기가 성공하면 `nil` 로 돌아간다.
    public private(set) var trouble: String?

    /// 한 글자 더 치는 시간보다 길게, 잊을 만큼 길지는 않게.
    private let debounce: Duration = .milliseconds(400)

    public init(location: URL) {
        self.location = location
        let stored = Self.read(from: location)
        self.written = stored
        self.latest = stored
    }

    /// 지난번에 들고 있던 글. 없으면 빈 글이다.
    public var restored: String { latest }

    /// 글이 바뀌었다. 잠깐 뒤에 적는다.
    public func remember(_ text: String) {
        latest = text
        pending?.cancel()
        pending = Task { [debounce] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            self.flush()
        }
    }

    /// 확정했거나 비웠다 — 남길 것이 없다.
    public func forget() {
        remember("")
        flush()
    }

    /// 기다릴 수 없을 때(상자를 닫을 때, 앱이 끝날 때) 즉시 적는다.
    public func flush() {
        pending?.cancel()
        pending = nil
        guard latest != written else { return }

        do {
            if latest.isEmpty {
                try? FileManager.default.removeItem(at: location)
            } else {
                try FileManager.default.createDirectory(
                    at: location.deletingLastPathComponent(), withIntermediateDirectories: true
                )
                try Data(latest.utf8).write(to: location, options: .atomic)
            }
            written = latest
            trouble = nil
        } catch {
            // 초안을 못 적는 것은 메모를 잃는 것이 아니다. 상자는 여전히
            // 이번 실행 동안은 들고 있다 — 다만 그 사실을 사람에게 말한다.
            trouble = "\(error)"
        }
    }

    /// 못 적었던 것을 다시 적어 본다 — 화면의 「다시 시도」.
    public func retry() {
        guard trouble != nil else { return }
        flush()
    }

    private static func read(from location: URL) -> String {
        guard let data = try? Data(contentsOf: location) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}
