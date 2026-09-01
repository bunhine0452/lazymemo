import Foundation

/// 지도에 넘길 좌표. 파일에는 `geo: 37.4979,127.0276` 한 줄로 적힌다.
///
/// **좌표는 거들 뿐 정본이 아니다.** 장소는 `place:` 의 이름만으로도 성립하고
/// (그때는 지도에 검색어로 넘긴다), 좌표는 있으면 더 정확해질 뿐이다. 사람이
/// 읽을 수 없는 값을 파일의 필수 요소로 만들지 않는다 — 메모는 텍스트 에디터로
/// 열어 고칠 수 있어야 한다 (§5.2).
public struct Coordinate: Sendable, Equatable, CustomStringConvertible {
    public let latitude: Double
    public let longitude: Double

    public init?(latitude: Double, longitude: Double) {
        guard latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude)
        else { return nil }
        self.latitude = latitude
        self.longitude = longitude
    }

    /// `위도,경도`. 사람이 손으로도 적을 수 있으므로 공백은 넘긴다.
    public init?(_ raw: String) {
        let parts = raw.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let latitude = Double(parts[0].trimmingCharacters(in: .whitespaces)),
              let longitude = Double(parts[1].trimmingCharacters(in: .whitespaces))
        else { return nil }
        self.init(latitude: latitude, longitude: longitude)
    }

    public var description: String { "\(Self.text(latitude)),\(Self.text(longitude))" }

    /// 소수점 여섯 자리면 10cm 다. 그보다 긴 꼬리는 파일을 읽기 어렵게만 한다.
    private static func text(_ value: Double) -> String {
        var digits = String(format: "%.6f", value)
        while digits.hasSuffix("0") { digits.removeLast() }
        if digits.hasSuffix(".") { digits.removeLast() }
        return digits
    }
}
