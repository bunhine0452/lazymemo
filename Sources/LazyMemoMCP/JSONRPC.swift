import Foundation

/// stdio MCP 가 쓰는 JSON-RPC 2.0 최소 구현.
///
/// 외부 패키지를 쓰지 않는 이유는 이 표면이 작기 때문이다 — 요청 하나,
/// 응답 하나, 오류 하나. 의존성을 들이면 오픈소스 빌드 문턱만 높아진다.
enum JSONRPC {
    static let version = "2.0"

    struct Request {
        let id: Any?
        let method: String
        let params: [String: Any]

        /// 알림(notification)은 id 가 없고 응답을 돌려주면 안 된다.
        var isNotification: Bool { id == nil }

        init?(_ object: [String: Any]) {
            guard let method = object["method"] as? String else { return nil }
            self.id = object["id"]
            self.method = method
            self.params = object["params"] as? [String: Any] ?? [:]
        }
    }

    enum ErrorCode: Int {
        case parseError = -32700
        case invalidRequest = -32600
        case methodNotFound = -32601
        case invalidParams = -32602
        case internalError = -32603
    }

    static func result(id: Any?, _ value: [String: Any]) -> [String: Any] {
        ["jsonrpc": version, "id": id ?? NSNull(), "result": value]
    }

    static func failure(id: Any?, _ code: ErrorCode, _ message: String) -> [String: Any] {
        [
            "jsonrpc": version,
            "id": id ?? NSNull(),
            "error": ["code": code.rawValue, "message": message],
        ]
    }
}

/// 한 줄에 메시지 하나 (stdio 전송 규약).
struct StdioTransport {
    private let output = FileHandle.standardOutput

    /// 로그는 반드시 stderr 로 — stdout 은 프로토콜 채널이라
    /// 한 줄이라도 섞이면 클라이언트가 연결을 끊는다.
    static func log(_ message: String) {
        FileHandle.standardError.write(Data("[lazymemo-mcp] \(message)\n".utf8))
    }

    func send(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(
            withJSONObject: message, options: [.withoutEscapingSlashes]
        ) else { return }
        output.write(data)
        output.write(Data("\n".utf8))
    }
}
