import Foundation
import LazyMemoCore
@testable import LazyMemoAssistant

/// `Tests/Fixtures/Assistant/*.json` — 가상 한국어 메모 143장과 80문항. 사용자 실제 메모가 아니다.
enum AssistantFixtures {
    struct Vault: Decodable { var now: String; var timeZone: String; var memos: [FixtureMemo] }
    struct FixtureMemo: Decodable {
        var id: String; var created: String; var due: String?; var at: String?; var surface: String?
        var place: String?; var tags: [String]; var folder: String?; var body: String; var deleted: String?; var done: Bool
    }
    struct Questions: Decodable { var items: [Question] }
    struct Question: Decodable {
        var id: String; var kind: String; var text: String; var selectedMemo: String?; var candidates: [String]; var expect: Expect; var note: String?
    }
    struct Expect: Decodable {
        var evidence: [String]?; var mustContainAny: [[String]]?; var abstain: Bool?; var action: ExpectedAction?
        var mustPreserve: [String]?; var mustNotContain: [String]?; var allowed: [String]?; var excluded: [String]?
        var mustInclude: [String]?; var max: Int?; var noAction: Bool?
    }
    struct ExpectedAction: Decodable { var kind: String; var memoID: String?; var patch: [String: String]?; var preserve: [String]? }

    static var directory: URL {
        URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Fixtures/Assistant", directoryHint: .isDirectory)
    }

    static func load() throws -> (vault: Vault, questions: Questions) {
        let decoder = JSONDecoder()
        let vault = try decoder.decode(Vault.self, from: Data(contentsOf: directory.appending(path: "memos.json")))
        let questions = try decoder.decode(Questions.self, from: Data(contentsOf: directory.appending(path: "questions.json")))
        return (vault, questions)
    }

    static func iso(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    /// fixture → 앱의 Memo. `done` 은 「치워 둔」(tidied) 으로 옮긴다 — Evidence.State.done 이 그것을 본다.
    static func memos(_ vault: Vault) -> [Memo] {
        vault.memos.map { m in
            let created = iso(m.created) ?? Date()
            return Memo(id: ULID(m.id) ?? ULID(), created: created, updated: created,
                        due: m.due.flatMap(CalendarDate.init(iso:)), at: iso(m.at), surface: iso(m.surface),
                        place: m.place, tags: m.tags, body: m.body, folder: m.folder,
                        deleted: iso(m.deleted), tidied: m.done ? created : nil)
        }
    }
}
