import Foundation

/// 시간순으로 정렬되는 128비트 식별자 (설계문서 §5.2).
///
/// UUID 대신 쓰는 이유는 두 가지다. 파일명이 곧 생성 순서가 되어 `ls` 만으로
/// 시간순이 보이고, 인덱스 없이도 최근 메모를 찾을 수 있다.
public struct ULID: Sendable, Hashable, Comparable, CustomStringConvertible {
    /// Crockford Base32 — 사람이 옮겨 적을 때 헷갈리는 I, L, O, U 가 빠져 있다.
    private static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
    private static let timestampLength = 10
    private static let randomnessLength = 16
    public static let length = timestampLength + randomnessLength

    public let stringValue: String

    public var description: String { stringValue }

    /// 문자열이 ULID 규격일 때만 통과시킨다. 파일명에서 읽어들일 때 쓴다.
    public init?(_ string: String) {
        let uppercased = string.uppercased()
        guard uppercased.count == Self.length,
              uppercased.allSatisfy({ Self.alphabet.contains($0) })
        else { return nil }
        self.stringValue = uppercased
    }

    public init(timestamp: Date = Date(), randomness: [UInt8]? = nil) {
        let milliseconds = UInt64(max(0, timestamp.timeIntervalSince1970 * 1000))
        let bytes = randomness ?? Self.randomBytes(count: 10)
        precondition(bytes.count == 10, "ULID 무작위부는 정확히 10바이트다")

        self.stringValue = Self.encodeTimestamp(milliseconds) + Self.encode(bytes: bytes)
    }

    /// 48비트 밀리초를 10글자로. 첫 글자는 상위 3비트만 쓴다 (ULID 규격).
    private static func encodeTimestamp(_ milliseconds: UInt64) -> String {
        let value = milliseconds & 0x0000_FFFF_FFFF_FFFF
        var result = ""
        result.reserveCapacity(timestampLength)
        for index in 0..<timestampLength {
            let shift = UInt64(45 - 5 * index)
            result.append(alphabet[Int((value >> shift) & 0x1F)])
        }
        return result
    }

    /// 10바이트(80비트)를 정확히 16글자로. 나머지 비트가 남지 않는다.
    private static func encode(bytes: [UInt8]) -> String {
        var result = ""
        result.reserveCapacity(randomnessLength)
        var buffer: UInt32 = 0
        var bitCount = 0
        for byte in bytes {
            buffer = (buffer << 8) | UInt32(byte)
            bitCount += 8
            while bitCount >= 5 {
                bitCount -= 5
                result.append(alphabet[Int((buffer >> UInt32(bitCount)) & 0x1F)])
            }
        }
        return result
    }

    private static func randomBytes(count: Int) -> [UInt8] {
        (0..<count).map { _ in UInt8.random(in: 0...255) }
    }

    /// 앞 10글자에 담긴 생성 시각. 메모 파일의 연/월 디렉터리를 **id 만으로**
    /// 결정하기 위해 필요하다 — frontmatter 의 `created` 를 쓰면 사용자가 그 값을
    /// 고치는 순간 파일을 찾지 못하게 된다.
    public var timestamp: Date {
        var milliseconds: UInt64 = 0
        for character in stringValue.prefix(Self.timestampLength) {
            let digit = Self.alphabet.firstIndex(of: character) ?? 0
            milliseconds = (milliseconds << 5) | UInt64(digit)
        }
        return Date(timeIntervalSince1970: Double(milliseconds) / 1000)
    }

    /// 사전순 비교가 곧 시간순 비교다 — 이것이 ULID 를 쓰는 이유의 절반이다.
    public static func < (lhs: ULID, rhs: ULID) -> Bool {
        lhs.stringValue < rhs.stringValue
    }
}
