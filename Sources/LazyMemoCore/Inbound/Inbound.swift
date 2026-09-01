import Foundation

/// 밖에서 들어온 메모 한 덩이.
///
/// URL 스킴·서비스 메뉴·CLI·아이폰 단축어가 **전부 이 모양으로 좁혀진다.**
/// 문이 넷이어도 안으로 들어오는 것은 하나여야, «무엇을 받는가» 를 한 곳에서
/// 정하고 한 곳에서 시험할 수 있다.
public struct InboundNote: Sendable, Equatable {
    public var text: String
    public var place: String?

    public init(text: String, place: String? = nil) {
        self.text = text
        self.place = place
    }

    /// 받아 주는 글의 상한. 메모는 사람이 읽는 것이고, 이보다 긴 것이 들어왔다면
    /// 그건 메모가 아니라 파일이다.
    public static let textLimit = 32_000
    public static let placeLimit = 200

    /// 다듬어서 받거나, 받을 것이 없으면 `nil`.
    public static func make(text: String?, place: String? = nil) -> InboundNote? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty, trimmed.count <= textLimit
        else { return nil }

        let spot = place?.trimmingCharacters(in: .whitespacesAndNewlines)
        return InboundNote(
            text: trimmed,
            place: (spot?.isEmpty ?? true) || (spot!.count > placeLimit) ? nil : spot
        )
    }
}

/// `lazymemo://add?text=…` — 다른 앱·단축어·스크립트가 두드리는 문.
///
/// **글자만 받는다.** 파일 경로도, 실행할 명령도, 열어야 할 주소도 받지 않는다.
/// URL 스킴은 이 컴퓨터의 아무 프로그램이나 두드릴 수 있는 문이라, 문 뒤에
/// 있는 것이 «글을 종이에 적는다» 하나뿐이어야 안전하다 — 할 수 있는 일을
/// 늘리지 않는 것이 유일하게 확실한 방어다.
public enum InboundLink {
    public static let scheme = "lazymemo"
    public static let action = "add"

    public static func note(from url: URL) -> InboundNote? {
        guard url.scheme?.lowercased() == scheme else { return nil }

        // `lazymemo://add?…` 는 host 로, `lazymemo:add?…` 는 path 로 들어온다.
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let verb = (parts.host ?? parts.path).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard verb.lowercased() == action else { return nil }

        let items = parts.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }
        return InboundNote.make(text: value("text"), place: value("place"))
    }
}

/// `lazymemo-mcp add "장보기"` — 터미널·cron·Raycast·다른 에이전트가 들어오는 문.
///
/// 인자가 없으면 **MCP 서버로 선다.** Claude Desktop 이 이 실행 파일을 인자
/// 없이 띄우기 때문이고, 그 동작을 바꾸면 이미 등록해 둔 사람의 연동이 깨진다.
public enum InboundCommand {
    public enum Command: Sendable, Equatable {
        /// 인자 없음 — stdio MCP 서버.
        case serve
        case add(InboundNote)
        case help
        case version
        case unknown(String)
        /// `add` 는 왔는데 적을 글이 없다.
        case empty
    }

    public static func parse(_ arguments: [String]) -> Command {
        var rest = arguments
        if !rest.isEmpty { rest.removeFirst() }   // 실행 파일 이름
        guard let verb = rest.first else { return .serve }

        switch verb {
        case "add":
            var words: [String] = []
            var place: String?
            var index = 1
            while index < rest.count {
                if rest[index] == "--place", index + 1 < rest.count {
                    place = rest[index + 1]
                    index += 2
                } else {
                    words.append(rest[index])
                    index += 1
                }
            }
            return InboundNote.make(text: words.joined(separator: " "), place: place)
                .map(Command.add) ?? .empty
        case "help", "--help", "-h": return .help
        case "version", "--version": return .version
        default: return .unknown(verb)
        }
    }

    public static let usage = """
        lazymemo \(LazyMemo.version)

        사용법
          lazymemo-mcp                       MCP 서버로 선다 (Claude Desktop 이 띄운다)
          lazymemo-mcp add "장보기"           바탕화면에 종이 한 장
          lazymemo-mcp add "치과" --place 강남역
          lazymemo-mcp help

        메모는 ~/Documents/lazymemo 안의 마크다운 파일이다. 앱이 켜져 있으면
        적자마자 바탕화면에 나타나고, 꺼져 있으면 다음에 켤 때 나타난다.
        """
}
