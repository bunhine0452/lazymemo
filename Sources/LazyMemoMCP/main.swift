import Foundation
import LazyMemoCore

/// lazymemo MCP 서버 (설계문서 §9).
///
/// Claude Desktop 이 이 실행 파일을 stdio 로 띄운다. 앱 프로세스에 붙는 것이
/// 아니라 **같은 Vault 를 직접 만지는 별도 프로세스**다 — stdio MCP 는
/// 클라이언트가 프로세스를 소유하는 구조라 그 방향만 성립한다.
///
/// 두 프로세스의 계약은 파일 그 자체이고(D4), 앱은 FSEvents 로 변경을 알아챈다.

// **인자가 있으면 서버가 아니라 도구다** (`InboundCommand`).
//
// 이 실행 파일에 문을 하나 더 낸 것은 값이 크기 때문이다 — cron·Raycast·Alfred·
// Hazel·셸 스크립트·다른 에이전트가 전부 이 문으로 바탕화면에 종이를 놓을 수
// 있고, 새로 만들 배선은 없다. Vault 를 여는 코드가 이미 여기 있다.
//
// 인자가 없을 때의 동작은 **바꾸지 않는다.** Claude Desktop 이 이 파일을 인자
// 없이 띄우므로, 그 갈래를 건드리면 이미 등록해 둔 사람의 연동이 조용히 깨진다.
let command = InboundCommand.parse(CommandLine.arguments)

// 저장소를 열 필요가 없는 것부터 답한다.
switch command {
case .help:
    print(InboundCommand.usage)
    exit(0)
case .version:
    print(LazyMemo.version)
    exit(0)
case .unknown(let verb):
    FileHandle.standardError.write(Data("모르는 명령입니다: \(verb)\n\n\(InboundCommand.usage)\n".utf8))
    exit(2)
case .empty:
    FileHandle.standardError.write(Data("적을 글이 없습니다.\n\n\(InboundCommand.usage)\n".utf8))
    exit(2)
case .serve, .add:
    break
}

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

// 터미널에서 온 한 장. 적고 나면 물러난다 — 서버로 서지 않는다.
if case .add(let inbound) = command {
    let note = NoteReader.read(inbound)
    do {
        let memo = try await service.create(
            body: note.body, due: note.due, at: note.at, every: note.every, place: note.place
        )
        print(memo.id.stringValue)
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("적지 못했습니다: \(error)\n".utf8))
        exit(1)
    }
}

let tools = MemoTools(service: service)
StdioTransport.log("Vault: \(paths.vault.path(percentEncoded: false))")

func handle(_ request: JSONRPC.Request) async -> [String: Any]? {
    switch request.method {
    case "initialize":
        let version = request.params["protocolVersion"] as? String ?? fallbackProtocolVersion
        return JSONRPC.result(id: request.id, [
            "protocolVersion": version,
            "capabilities": [
                "tools": ["listChanged": false],
                // 도구 목록은 모델이 읽고, 프롬프트 목록은 **사람이 읽는다**.
                "prompts": ["listChanged": false],
            ],
            "serverInfo": ["name": "lazymemo", "version": LazyMemo.version],
            "instructions": """
                lazymemo 는 사용자의 바탕화면 메모다. 메모와 일정이 같은 것이라,
                due(날짜) 또는 at(시각)을 채우면 캘린더에도 나타난다.
                삭제는 휴지통 이동까지만 가능하며 영구 삭제 도구는 제공되지 않는다.
                """,
        ])

    case "ping":
        return JSONRPC.result(id: request.id, [:])

    case "prompts/list":
        return JSONRPC.result(id: request.id, ["prompts": MemoPrompts.definitions])

    case "prompts/get":
        guard let name = request.params["name"] as? String else {
            return JSONRPC.failure(id: request.id, .invalidParams, "name 이 필요합니다")
        }
        guard let messages = MemoPrompts.messages(for: name),
              let definition = MemoPrompts.definition(name)
        else {
            return JSONRPC.failure(id: request.id, .invalidParams, "없는 프롬프트입니다: \(name)")
        }
        return JSONRPC.result(id: request.id, [
            "description": definition["description"] ?? "",
            "messages": messages,
        ])

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
