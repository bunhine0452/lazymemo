import LazyMemoCore
import MapKit
import SwiftUI

/// 종이 위의 자리 카드들 — 지도 한 장, 이름, 가는 길을 열 지도 앱 (MOBILE_DESIGN §5).
///
/// 자리가 하나면 카드 하나, 여럿이면 옆으로 쓸어 넘긴다 — 한 장씩 멈추는 페이지
/// 스크롤이고 아래 점이 몇째 장인지 말한다. 지도는 만질 수 없다: 종이 안에서
/// 지도를 굴리면 스크롤과 싸운다. 가는 길은 카드 바닥의 지도 앱 단추가 연다 —
/// 깔린 앱만 서고, 그 앱이 지금 위치에서 길을 찾는다.
struct PlaceCardsView: View {
    let resolver: PlaceResolver

    @State private var page: String?
    @State private var apps = MapApp.installed

    var body: some View {
        VStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                // LazyHStack 은 세로로 주어진 자리를 다 채운다 — 머리에 앉힌 카드가 화면을
                // 통째로 먹고 글이 그 뒤로 숨는다. 카드는 몇 장 안 되니 그냥 HStack.
                HStack(spacing: 12) {
                    ForEach(resolver.spots, id: \.place.id) { spot in
                        PlaceCard(spot: spot, apps: apps)
                            .containerRelativeFrame(.horizontal)
                            .id(spot.place.id)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)
            if resolver.spots.count > 1 {
                HStack(spacing: 6) {
                    ForEach(resolver.spots, id: \.place.id) { spot in
                        let current = (page ?? resolver.spots.first?.place.id) == spot.place.id
                        Capsule()
                            .fill(current ? Theme.accentInk : Theme.accentInk.opacity(0.25))
                            .frame(width: current ? 16 : 6, height: 6)
                            .animation(.snappy, value: page)
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .accessibilityIdentifier("place-cards")
    }
}

private struct PlaceCard: View {
    let spot: PlaceResolver.Spot
    let apps: [MapApp]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            map
            HStack(spacing: 8) {
                Image(systemName: "mappin").font(.caption).foregroundStyle(Theme.accentInk)
                Text(spot.place.name).font(.subheadline.weight(.semibold)).foregroundStyle(Paper.ink).lineLimit(1)
                Spacer(minLength: 8)
                ForEach(apps) { app in
                    Button(app.label) { app.open(spot) }
                        .font(.caption.weight(.medium))
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(Theme.accentInk)
                        .disabled(spot.coordinate == nil && app != .apple)
                        .accessibilityLabel("\(app.label)에서 가는 길")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Paper.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Paper.ink.opacity(0.07), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("자리 \(spot.place.name)")
        .accessibilityIdentifier("place-card")
    }

    @ViewBuilder
    private var map: some View {
        if let coordinate = spot.coordinate {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: coordinate, latitudinalMeters: 900, longitudinalMeters: 900
            )), interactionModes: []) {
                Marker(spot.place.name, coordinate: coordinate).tint(Theme.accent)
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControlVisibility(.hidden)
            .frame(height: 132)
            .allowsHitTesting(false)
        } else {
            ZStack {
                Rectangle().fill(Theme.accentInk.opacity(0.06))
                VStack(spacing: 4) {
                    Image(systemName: spot.unresolved ? "mappin.slash" : "map")
                        .font(.title3).foregroundStyle(.secondary)
                    Text(spot.unresolved ? "지도에서 못 찾은 자리" : "지도를 찾는 중")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(height: 132)
        }
    }
}
