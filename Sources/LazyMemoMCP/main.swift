import Foundation
import LazyMemoCore

/// lazymemo MCP 서버 (설계문서 §9).
///
/// Claude Desktop 이 이 실행 파일을 stdio 로 띄운다. 앱 프로세스에 붙는 것이
/// 아니라 **같은 Vault 를 직접 만지는 별도 프로세스**다 — stdio MCP 는
/// 클라이언트가 프로세스를 소유하는 구조라 그 방향만 성립한다.
///
/// 두 프로세스의 계약은 파일 그 자체이고(D4), 앱은 FSEvents 로 변경을 알아챈다.

let transport = StdioTransport()

/// 클라이언트가 요청한 프로토콜 버전을 그대로 돌려준다.
/// 우리가 쓰는 표면(tools 뿐)은 버전 간 차이가 없어, 고정 문자열로 못 박는 것보다
/// 클라이언트를 따라가는 편이 오래 산다.
let fallbackProtocolVersion = "2025-06-18"

let paths = AppPaths.standard()

let service: MemoService
do {
    try paths.createDirectories()
    service = try MemoService(paths: paths)
} catch {
    StdioTransport.log("저장소를 열지 못했습니다: \(error)")
    exit(1)
}

let tools = MemoTools(service: service)
StdioTransport.log("Vault: \(paths.vault.path(percentEncoded: false))")

func handle(_ request: JSONRPC.Request) async -> [String: Any]? {
    switch request.method {
    case "initialize":
        let version = request.params["protocolVersion"] as? String ?? fallbackProtocolVersion
        return JSONRPC.result(id: request.id, [
            "protocolVersion": version,
            "capabilities": ["tools": ["listChanged": false]],
            "serverInfo": ["name": "lazymemo", "version": LazyMemo.version],
            "instructions": """
                lazymemo 는 사용자의 바탕화면 메모다. 메모와 일정이 같은 것이라,
                due(날짜) 또는 at(시각)을 채우면 캘린더에도 나타난다.
                삭제는 휴지통 이동까지만 가능하며 영구 삭제 도구는 제공되지 않는다.
                """,
        ])

    case "ping":
        return JSONRPC.result(id: request.id, [:])

    case "tools/list":
        return JSONRPC.result(id: request.id, ["tools": MemoTools.definitions])

    case "tools/call":
        guard let name = request.params["name"] as? String else {
            return JSONRPC.failure(id: request.id, .invalidParams, "name 이 필요합니다")
        }
        let arguments = request.params["arguments"] as? [String: Any] ?? [:]

        do {
            let text = try await tools.call(name, arguments: arguments)
            return JSONRPC.result(id: request.id, [
                "content": [["type": "text", "text": text]],
                "isError": false,
            ])
        } catch {
            // 도구 오류는 프로토콜 오류가 아니다. 모델이 읽고 고칠 수 있도록
            // 결과로 돌려준다 (MCP 규약).
            return JSONRPC.result(id: request.id, [
                "content": [["type": "text", "text": "\(error)"]],
                "isError": true,
            ])
        }

    default:
        // 알림은 응답하지 않는다 — notifications/initialized 등.
        if request.isNotification { return nil }
        return JSONRPC.failure(id: request.id, .methodNotFound, "지원하지 않는 메서드: \(request.method)")
    }
}

// 한 줄에 메시지 하나. 순서대로 처리한다 — Vault 쓰기가 뒤섞이면 안 된다.
for try await line in FileHandle.standardInput.bytes.lines {
    guard !line.isEmpty else { continue }

    guard let data = line.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
        transport.send(JSONRPC.failure(id: nil, .parseError, "JSON 을 읽을 수 없습니다"))
        continue
    }

    guard let request = JSONRPC.Request(object) else {
        transport.send(JSONRPC.failure(id: object["id"], .invalidRequest, "method 가 없습니다"))
        continue
    }

    if let response = await handle(request) {
        transport.send(response)
    }
}
