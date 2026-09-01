import Foundation

/// `0.2.0` 같은 판 번호.
///
/// **문자열로 견주면 틀린다.** `"0.10.0" < "0.9.0"` 이 참이 되어, 판을 열 번
/// 올린 순간부터 앱이 «최신입니다» 라고 말하기 시작한다. 그 고장은 만든 사람
/// 기계에서는 한 번도 안 보이고 시간이 지난 뒤 사용자에게만 나타난다 —
/// 릴리스 워크플로가 sha256 을 손으로 옮기지 않는 것과 같은 이유로 여기에 둔다.
public struct SemanticVersion: Sendable, Equatable, Comparable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// `0.2.0` 또는 `v0.2.0`. 태그와 `Info.plist` 가 같은 글자를 쓰므로 둘 다 받는다.
    public init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = trimmed.hasPrefix("v") ? String(trimmed.dropFirst()) : trimmed
        let parts = body.split(separator: ".", omittingEmptySubsequences: false)
        guard (2...3).contains(parts.count) else { return nil }

        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy(\.isNumber), let value = Int(part) else { return nil }
            numbers.append(value)
        }
        self.init(major: numbers[0], minor: numbers[1], patch: numbers.count > 2 ? numbers[2] : 0)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    public var description: String { "\(major).\(minor).\(patch)" }
}

extension LazyMemo {
    /// 지금 돌고 있는 판.
    public static var semanticVersion: SemanticVersion {
        SemanticVersion(version) ?? SemanticVersion(major: 0, minor: 0, patch: 0)
    }
}
