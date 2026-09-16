import LazyMemoCore
import SwiftUI

/// 카드의 색과 모양 — 종이의 것을 화면이 끼운다. 폰과 맥의 종이 색이 달라 카드는 색을 스스로 정하지 않는다.
public struct RouteCardStyle: Sendable {
    public var ink: Color
    public var faded: Color
    public var accent: Color
    public var softAccent: Color
    public var surface: Color
    public var edge: Color
    public var radius: CGFloat

    public init(ink: Color, faded: Color, accent: Color, softAccent: Color, surface: Color, edge: Color, radius: CGFloat) {
        self.ink = ink; self.faded = faded; self.accent = accent; self.softAccent = softAccent
        self.surface = surface; self.edge = edge; self.radius = radius
    }
}

/// 가는 길 카드 — 네이버 지도의 길찾기 결과 한 장을 종이 위에 (2026-09-16, 사용자가 그 화면을 보기로 가져왔다).
///
/// 위에서부터: 종류와 출발 시각 · 큰 소요 시간과 도착·요금 · 구간 띠 · 타는 곳의 줄들 · 하차 · 지도로 가는 길.
/// 그리는 것은 `RouteNote` 가 본문에서 읽은 것뿐이다 — 카드에 적힌 것과 글에 적힌 것이 다를 수 없다.
public struct RouteCard: View {
    public let route: TransitRoute
    public let style: RouteCardStyle
    /// 「지도에서 보기」— 어느 지도를 어떻게 열지는 화면이 정한다 (`RouteLinks`). 맥은 웹, 폰은 깔린 앱.
    public var open: (TransitRoute) -> Void
    /// 길을 떼어 낸다. 없으면 단추도 없다.
    public var remove: (() -> Void)?

    public init(route: TransitRoute, style: RouteCardStyle, open: @escaping (TransitRoute) -> Void, remove: (() -> Void)? = nil) {
        self.route = route
        self.style = style
        self.open = open
        self.remove = remove
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            head
            headline
            SegmentBar(route: route, faded: style.faded)
            Rectangle().fill(style.edge).frame(height: 0.75)
            timeline
            if let words = route.transferWords { transferLine(words) }
            tail
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: style.radius, style: .continuous).fill(style.surface))
        .overlay(RoundedRectangle(cornerRadius: style.radius, style: .continuous).strokeBorder(style.edge, lineWidth: 0.75))
        .clipShape(RoundedRectangle(cornerRadius: style.radius, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(spoken))
        .accessibilityIdentifier("route-card")
    }

    // MARK: 머리

    private var head: some View {
        HStack(spacing: 6) {
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                .font(.system(size: 10, weight: .semibold))
            Text("가는 길")
                .font(.system(size: 11, weight: .semibold))
            Text(route.kind.label)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(style.softAccent, in: Capsule())
            Spacer(minLength: 4)
            Text("\(RouteNote.clock(route.depart)) 출발")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(style.accent)
    }

    private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(route.minutes)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("분").font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(style.ink)
            bar
            Text("\(clock(route.arrive)) 도착").font(.system(size: 12)).foregroundStyle(style.ink)
            if let fare = route.fare ?? route.legs.first(where: { $0.mode == .taxi })?.fare {
                bar
                Text((route.kind == .taxi ? "약 " : "") + TransitRoute.won(fare)).font(.system(size: 12)).foregroundStyle(style.ink)
            }
            Spacer(minLength: 0)
        }
    }

    private var bar: some View {
        Rectangle().fill(style.edge).frame(width: 1, height: 12)
    }

    // MARK: 줄들

    @ViewBuilder
    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(route.rides.enumerated()), id: \.offset) { index, leg in
                rideRow(leg, isLast: false)
            }
            if let last = route.rides.last { alightRow(last) }
        }
    }

    private func rideRow(_ leg: TransitRoute.Leg, isLast: Bool) -> some View {
        let color = Color(hex: TransitPalette.hex(for: leg))
        return HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 0) {
                Image(systemName: symbol(for: leg.mode))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(color, in: Circle())
                Rectangle().fill(style.edge).frame(width: 1.5).frame(maxHeight: .infinity)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(kindLabel(leg)).font(.system(size: 12, weight: .semibold)).foregroundStyle(color)
                    Text(boarding(leg)).font(.system(size: 13, weight: .medium)).foregroundStyle(style.ink).lineLimit(1)
                }
                HStack(spacing: 6) {
                    if let line = leg.line { lineBadge(line, color: color) }
                    Text(detail(leg)).font(.system(size: 11)).foregroundStyle(style.faded).lineLimit(1)
                }
                let extra = [leg.heading, leg.exit.map { "\($0)번 출구로" }].compactMap { $0 }.joined(separator: " · ")
                if !extra.isEmpty {
                    Text(extra).font(.system(size: 11)).foregroundStyle(style.faded)
                }
            }
            .padding(.bottom, 10)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func alightRow(_ leg: TransitRoute.Leg) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Circle().strokeBorder(style.faded, lineWidth: 1.5).frame(width: 12, height: 12).padding(.horizontal, 3)
            Text("하차").font(.system(size: 12, weight: .semibold)).foregroundStyle(style.faded)
            Text(leg.to ?? route.destination).font(.system(size: 13, weight: .medium)).foregroundStyle(style.ink).lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private func lineBadge(_ line: String, color: Color) -> some View {
        Text(line)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(color, lineWidth: 1))
    }

    private func transferLine(_ words: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.triangle.swap").font(.system(size: 10, weight: .semibold))
            Text("환승 \(route.transfers)회 — \(words)").font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(style.accent)
    }

    private var tail: some View {
        HStack(spacing: 8) {
            Button { open(route) } label: {
                HStack(spacing: 3) {
                    Text("지도에서 보기").font(.system(size: 11, weight: .medium))
                    Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
                }
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(style.softAccent, in: Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(style.accent)
            .accessibilityLabel(Text("지도에서 보기 — \(route.origin)에서 \(route.destination)까지"))
            Spacer(minLength: 0)
            if let remove {
                Button(action: remove) {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .semibold)).padding(4)
                }
                .buttonStyle(.plain)
                .foregroundStyle(style.faded)
                .accessibilityLabel(Text("가는 길 지우기"))
                .accessibilityIdentifier("route-remove")
            }
        }
    }

    // MARK: 말

    private func clock(_ date: Date) -> String { RouteNote.clock(date) }

    private func symbol(for mode: TransitRoute.Mode) -> String {
        switch mode {
        case .bus: return "bus.fill"
        case .subway: return "tram.fill"
        case .taxi: return "car.fill"
        case .transit: return "bus.fill"
        case .walk: return "figure.walk"
        }
    }

    private func kindLabel(_ leg: TransitRoute.Leg) -> String {
        switch leg.mode {
        case .bus: return leg.kind ?? "버스"
        case .subway: return "지하철"
        case .taxi: return "택시"
        case .transit: return "대중교통"
        case .walk: return "걷기"
        }
    }

    private func boarding(_ leg: TransitRoute.Leg) -> String {
        switch leg.mode {
        case .bus, .subway: return leg.from ?? route.origin
        case .taxi: return route.origin
        case .transit: return "자세한 길은 지도 앱에서"
        case .walk: return ""
        }
    }

    private func detail(_ leg: TransitRoute.Leg) -> String {
        var parts = ["\(leg.minutes)분"]
        if let stops = leg.stops { parts.append("\(stops)" + (leg.mode == .bus ? "정류장" : "정거장")) }
        if leg.mode == .taxi {
            if let fare = leg.fare { parts.append("약 " + TransitRoute.won(fare)) }
            if let distance = leg.distance { parts.append(String(format: "%.1fkm", Double(distance) / 1000)) }
        }
        return parts.joined(separator: " · ")
    }

    private var spoken: String {
        var parts = ["가는 길 \(route.kind.label) \(route.minutes)분", "\(clock(route.depart)) 출발", "\(clock(route.arrive)) 도착"]
        for leg in route.rides {
            parts.append([kindLabel(leg), leg.line, leg.from.map { "\($0)에서" }, leg.to.map { "\($0)까지" }].compactMap { $0 }.joined(separator: " "))
        }
        if let words = route.transferWords { parts.append("환승 \(route.transfers)회 \(words)") }
        return parts.joined(separator: ", ")
    }
}

/// 구간 띠 — 걷기는 얇고 흐리게, 타는 구간은 그 탈것의 색으로, 길이는 시간에 비례.
struct SegmentBar: View {
    let route: TransitRoute
    let faded: Color

    private var total: Double { Double(max(1, route.legs.reduce(0) { $0 + $1.minutes })) }

    var body: some View {
        GeometryReader { proxy in
            let widths = widths(in: proxy.size.width)
            HStack(spacing: 2) {
                ForEach(Array(route.legs.enumerated()), id: \.offset) { index, leg in
                    segment(leg, width: widths[index])
                }
            }
        }
        .frame(height: 20)
        .accessibilityHidden(true)
    }

    /// 구간마다 글자 하나는 들어갈 바닥을 먼저 주고, 남는 폭을 시간에 비례해 나눈다 — 합이 늘 너비다.
    /// 2분 걷기가 점이 되면 읽을 수 없고, 바닥의 합이 너비를 넘으면 마지막 구간이 잘린다.
    private func widths(in available: CGFloat) -> [CGFloat] {
        let gaps = CGFloat(max(0, route.legs.count - 1)) * 2
        let usable = max(0, available - gaps)
        let floors = route.legs.map { $0.rides ? CGFloat(40) : CGFloat(38) }
        let floorSum = floors.reduce(0, +)
        guard floorSum <= usable else { return floors.map { $0 / floorSum * usable } }
        let remaining = usable - floorSum
        return zip(route.legs, floors).map { leg, floor in floor + remaining * CGFloat(Double(leg.minutes) / total) }
    }

    private func segment(_ leg: TransitRoute.Leg, width: CGFloat) -> some View {
        let color = leg.rides ? Color(hex: TransitPalette.hex(for: leg)) : faded.opacity(0.18)
        return HStack(spacing: 3) {
            if leg.rides {
                Image(systemName: leg.mode == .taxi ? "car.fill" : (leg.mode == .subway ? "tram.fill" : "bus.fill"))
                    .font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
            } else {
                Image(systemName: "figure.walk").font(.system(size: 8, weight: .bold)).foregroundStyle(faded)
            }
            Text("\(leg.minutes)분")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(leg.rides ? .white : faded)
                .lineLimit(1)
        }
        .frame(width: width, height: 20)
        .background(Capsule().fill(color))
    }
}

/// 길을 바깥 지도에 넘기는 주소들. 애플 지도는 한국의 대중교통을 모른다 (2026-09-16 실측: `FAILED_NO_RESULT`).
///
/// 웹의 카카오맵은 출발·도착을 **이름으로** 받는다 — 메모에 좌표는 도착지 것뿐이라 이름이 맞다.
/// 폰의 네이버·카카오 앱은 좌표를 받으므로 도착지 좌표를 넘기고, 출발은 지금 자리로 둔다.
public enum RouteLinks {
    /// `map.kakao.com/?sName=…&eName=…` — 브라우저에서 길찾기가 선다. 맥의 「지도에서 보기」.
    public static func kakaoWeb(_ route: TransitRoute) -> URL? {
        var parts = URLComponents(string: "https://map.kakao.com/")
        parts?.queryItems = [.init(name: "sName", value: route.origin), .init(name: "eName", value: route.destination)]
        return parts?.url
    }

    /// 네이버 지도 앱 — 도착 좌표로. 택시면 자동차 길.
    public static func naverApp(_ route: TransitRoute, destination: Coordinate, appName: String) -> URL? {
        var parts = URLComponents(string: route.kind == .taxi ? "nmap://route/car" : "nmap://route/public")
        parts?.queryItems = [
            .init(name: "dlat", value: String(destination.latitude)), .init(name: "dlng", value: String(destination.longitude)),
            .init(name: "dname", value: route.destination), .init(name: "appname", value: appName),
        ]
        return parts?.url
    }

    /// 카카오맵 앱 — 도착 좌표로.
    public static func kakaoApp(_ route: TransitRoute, destination: Coordinate) -> URL? {
        URL(string: "kakaomap://route?ep=\(destination.latitude),\(destination.longitude)&by=\(route.kind == .taxi ? "CAR" : "PUBLICTRANSIT")")
    }
}

extension Color {
    /// `#RRGGBB`. `TransitPalette` 의 것을 화면의 색으로.
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&value)
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}
