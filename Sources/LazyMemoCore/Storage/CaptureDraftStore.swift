import Foundation

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
@MainActor
public final class CaptureDraftStore {
    private let location: URL
    private var pending: Task<Void, Never>?
    /// 마지막으로 파일에 적은 것. 같은 글을 두 번 쓰지 않는다.
    private var written: String
    private var latest: String

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
        } catch {
            // 초안을 못 적는 것은 메모를 잃는 것이 아니다. 상자는 여전히
            // 이번 실행 동안은 들고 있다.
        }
    }

    private static func read(from location: URL) -> String {
        guard let data = try? Data(contentsOf: location) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}
