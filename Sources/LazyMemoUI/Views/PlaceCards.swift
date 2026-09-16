import AppKit
import LazyMemoCore
import LazyMemoPlaces
import MapKit
import SwiftUI

/// 종이 머리의 자리 카드 — 폰과 같은 물건이다 (MOBILE_DESIGN §5 「자리 카드」, 2026-09-14).
///
/// 맥은 오래 「지도를 그리지 않는다」였다(`MapLink`). 폰이 먼저 뒤집었고 맥이 따라간다 —
/// 한쪽에서는 지도가 보이고 한쪽에서는 잉크 한 줄이면 사람은 두 앱을 쓰는 것이 된다.
/// 다만 종이의 몫은 지킨다: 지도의 키는 종이 높이에서 받고(`NoteView.mapHeight`),
/// 만질 수 없다(굴리면 창 끌기와 싸운다). 가는 길은 바깥의 지도 앱이 찾는다 —
/// 맥에는 지도 앱이 하나뿐이라 단추도 하나다. 카카오맵은 우클릭에 둔다(웹 주소).
struct PlaceCardsView: View {
    let resolver: PlaceResolver
    /// 지도 한 장의 키. 종이가 작으면 지도도 작다.
    let mapHeight: CGFloat

    @State private var page: String?
    @Environment(\.rendersStatically) private var rendersStatically

    var body: some View {
        // 화면 밖 렌더는 스크롤 뷰를 그리지 못한다 — 첫 장만 그대로 세운다 (`DrawerView` 와 같은 길).
        if rendersStatically, let first = resolver.spots.first {
            PlaceCard(spot: first, mapHeight: mapHeight)
                .padding(.horizontal, Theme.snug)
                .padding(.top, PaperGrip.height)
        } else {
            paged
        }
    }

    private var paged: some View {
        VStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.snug) {
                    ForEach(resolver.spots, id: \.place.id) { spot in
                        PlaceCard(spot: spot, mapHeight: mapHeight)
                            .containerRelativeFrame(.horizontal)
                            .id(spot.place.id)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, Theme.snug, for: .scrollContent)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)
            if resolver.spots.count > 1 {
                HStack(spacing: 5) {
                    ForEach(resolver.spots, id: \.place.id) { spot in
                        let current = (page ?? resolver.spots.first?.place.id) == spot.place.id
                        Capsule()
                            .fill(current ? Theme.accentInk : Theme.accentInk.opacity(0.25))
                            .frame(width: current ? 14 : 5, height: 5)
                            .animation(.snappy, value: page)
                    }
                }
                .accessibilityHidden(true)
            }
        }
        // 머리의 손잡이(`PaperGrip`) 아래에 앉는다 — 그 줄은 창을 끄는 자리라 카드가 덮지 않는다.
        .padding(.top, PaperGrip.height)
        .accessibilityIdentifier("place-cards")
    }
}

private struct PlaceCard: View {
    let spot: PlaceResolver.Spot
    let mapHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            map
            HStack(spacing: Theme.tight) {
                Image(systemName: "mappin")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.accentInk)
                Text(spot.place.name)
                    .font(Theme.label.weight(.medium))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(1)
                Spacer(minLength: Theme.tight)
                Button { MapRoute.apple.open(spot) } label: {
                    Text(L("가는 길"))
                        .font(Theme.micro.weight(.medium))
                        .padding(.horizontal, Theme.tight)
                        .padding(.vertical, 3)
                        .background(Theme.softAccent, in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accentInk)
                .spoken(L("가는 길 — 지도 앱이 지금 자리에서 \(spot.place.name)까지 길을 찾습니다"))
            }
            .padding(.horizontal, Theme.snug)
            .padding(.vertical, Theme.tight)
        }
        .background {
            RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                .fill(Paper.ink.opacity(0.04))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                .strokeBorder(Paper.ink.opacity(0.08), lineWidth: 0.75)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
        .contextMenu {
            Button(L("애플 지도에서 가는 길")) { MapRoute.apple.open(spot) }
            Button(L("카카오맵에서 가는 길")) { MapRoute.kakao.open(spot) }
                .disabled(spot.coordinate == nil)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(L("자리 \(spot.place.name)")))
        .accessibilityIdentifier("place-card")
    }

    @Environment(\.rendersStatically) private var rendersStatically

    @ViewBuilder
    private var map: some View {
        if rendersStatically {
            // 지도는 Metal 이 그려 화면 밖 렌더에 잡히지 않는다. 자리만 잡아 둔다.
            ZStack {
                Rectangle().fill(Theme.accentInk.opacity(0.10))
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.accentInk)
            }
            .frame(height: mapHeight)
        } else if let coordinate = spot.coordinate {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: coordinate, latitudinalMeters: 900, longitudinalMeters: 900
            )), interactionModes: []) {
                Marker(spot.place.name, coordinate: coordinate).tint(Theme.accent)
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControlVisibility(.hidden)
            .frame(height: mapHeight)
            .allowsHitTesting(false)
        } else {
            ZStack {
                Rectangle().fill(Theme.accentInk.opacity(0.06))
                VStack(spacing: 3) {
                    Image(systemName: spot.unresolved ? "mappin.slash" : "map")
                        .font(.system(size: 13))
                        .foregroundStyle(Paper.fadedInk)
                    Text(spot.unresolved ? L("지도에서 못 찾은 자리") : L("지도를 찾는 중"))
                        .font(Theme.micro)
                        .foregroundStyle(Paper.fadedInk)
                }
            }
            .frame(height: mapHeight)
        }
    }
}

/// 가는 길을 여는 곳. 출발지는 넘기지 않는다 — 지도 앱이 지금 위치에서 찾는다.
///
/// 애플 지도는 늘 있다. 카카오맵은 맥에 앱이 없으므로 웹의 공개 주소
/// (`map.kakao.com/link/to/이름,위도,경도`)로 연다 — 좌표가 있어야 한다.
enum MapRoute {
    case apple, kakao

    func open(_ spot: PlaceResolver.Spot) {
        let name = spot.place.name
        switch self {
        case .apple:
            guard let to = spot.coordinate else {
                if let url = MapLink.url(place: name, geo: nil) { NSWorkspace.shared.open(url) }
                return
            }
            let item = MKMapItem(location: CLLocation(latitude: to.latitude, longitude: to.longitude), address: nil)
            item.name = name
            item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit])
        case .kakao:
            guard let to = spot.coordinate,
                  let escaped = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "https://map.kakao.com/link/to/\(escaped),\(to.latitude),\(to.longitude)")
            else { return }
            NSWorkspace.shared.open(url)
        }
    }
}
