import Foundation

/// 메모 파일 머리말 (설계문서 §5.2).
///
/// **YAML 파서가 아니다.** 우리가 쓰는 부분집합만 읽고, 모르는 키는 원문 줄을
/// 그대로 보관했다가 그대로 다시 쓴다. 목적이 "이해"가 아니라 "보존"이기 때문이다 —
/// 사용자가 직접 넣은 필드를 앱이 지우지 않는다는 설계문서 §5.2 의 약속이
/// 완전한 YAML 지원 없이도 지켜진다.
public struct Frontmatter: Sendable, Equatable {
    public enum Value: Sendable, Equatable {
        case scalar(String)
        case list([String])
        case empty
    }

    public struct Entry: Sendable, Equatable {
        public let key: String
        public let value: Value
        /// 원문 줄. 모르는 키를 손실 없이 되쓰기 위한 것이다.
        public let rawLines: [String]

        public init(key: String, value: Value, rawLines: [String]) {
            self.key = key
            self.value = value
            self.rawLines = rawLines
        }
    }

    public private(set) var entries: [Entry]

    public init(entries: [Entry] = []) {
        self.entries = entries
    }

    public subscript(key: String) -> Value? {
        entries.first { $0.key == key }?.value
    }

    public func string(_ key: String) -> String? {
        if case .scalar(let value) = self[key] { return value }
        return nil
    }

    public func list(_ key: String) -> [String]? {
        switch self[key] {
        case .list(let items): return items
        case .scalar(let single): return [single]
        default: return nil
        }
    }

    public func bool(_ key: String) -> Bool? {
        guard let raw = string(key)?.lowercased() else { return nil }
        return ["true", "yes", "on"].contains(raw) ? true
             : ["false", "no", "off"].contains(raw) ? false
             : nil
    }

    /// 주어진 키들을 뺀 나머지 — 앱이 모르는 필드만 남는다.
    public func excluding(_ keys: Set<String>) -> [Entry] {
        entries.filter { !keys.contains($0.key) }
    }

    // MARK: 파싱

    /// `key: value` 를 가른다. 정규식을 쓰지 않는 이유는 `Regex` 가 Sendable 이
    /// 아니라 static 상수로 둘 수 없고, 매 줄 새로 컴파일하는 편이 더 비싸기 때문이다.
    private static func splitKey(_ line: String) -> (key: String, rest: String)? {
        guard let first = line.first, first.isLetter || first == "_" else { return nil }
        guard let colon = line.firstIndex(of: ":") else { return nil }

        let key = line[line.startIndex..<colon]
        guard key.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" })
        else { return nil }

        let rest = line[line.index(after: colon)...]
        return (String(key), String(rest))
    }

    public static func parse(_ text: String) -> Frontmatter {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var entries: [Entry] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            guard let (key, rest) = splitKey(line) else {
                index += 1
                continue    // 키로 시작하지 않는 고아 줄은 버린다 (주석·빈 줄)
            }

            let inline = rest.trimmingCharacters(in: .whitespaces)
            var rawLines = [line]
            index += 1

            if inline.isEmpty {
                // 블록 리스트: 다음 줄부터 이어지는 `- 항목` 을 모은다.
                var items: [String] = []
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    guard candidate.hasPrefix("- ") || candidate == "-" else { break }
                    items.append(unquote(String(candidate.dropFirst(1)).trimmingCharacters(in: .whitespaces)))
                    rawLines.append(lines[index])
                    index += 1
                }
                entries.append(Entry(key: key, value: items.isEmpty ? .empty : .list(items), rawLines: rawLines))
            } else if inline.hasPrefix("["), inline.hasSuffix("]") {
                let inner = String(inline.dropFirst().dropLast())
                let items = inner
                    .split(separator: ",")
                    .map { unquote($0.trimmingCharacters(in: .whitespaces)) }
                    .filter { !$0.isEmpty }
                entries.append(Entry(key: key, value: .list(items), rawLines: rawLines))
            } else {
                entries.append(Entry(key: key, value: .scalar(unquote(inline)), rawLines: rawLines))
            }
        }

        return Frontmatter(entries: entries)
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2 else { return value }
        let first = value.first, last = value.last
        if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            return String(value.dropFirst().dropLast())
        }
        return value
    }

    // MARK: 직렬화

    /// 콜론·해시·대괄호는 YAML 에서 의미를 가지므로 따옴표로 감싼다.
    /// 한글이나 공백 하나는 감싸지 않는다 — 사람이 읽을 파일이라 소음을 줄인다.
    public static func quoteIfNeeded(_ value: String) -> String {
        if value.isEmpty { return "\"\"" }
        let needsQuote = value.contains(": ")
            || value.hasSuffix(":")
            || value.contains(" #")
            || value.first == "#"
            || "[]{}\",&*!|>%@`".contains(value.first!)
            || value.first == " " || value.last == " "
        guard needsQuote else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    public static func line(key: String, scalar: String) -> String {
        "\(key): \(quoteIfNeeded(scalar))"
    }

    public static func line(key: String, list: [String]) -> String {
        "\(key): [" + list.map(quoteIfNeeded).joined(separator: ", ") + "]"
    }
}
