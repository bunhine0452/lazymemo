import LazyMemoCore
import LazyMemoWidgetsCore
import SwiftUI
import WidgetKit

/// 「지금」 — 앱의 띠 그대로 홈 화면에 (`Recall.nowCards`).
///
/// 작은 것은 한 장, 중간은 세 장, 큰 것은 세 장과 그 아래 「다음」. 잠금 화면에는 한 장.
/// 카드를 누르면 그 메모가 열리고(`WidgetLink.memo`), 카드 오른쪽의 **「봤어요」**가 그 자리에서
/// 카드를 내려놓는다 (`SeenIntent`, 폰만). 펼칠 것이 없으면 「적기」 문 하나가 남는다.
///
/// 얼굴은 `NowFaces.swift` 에 있다.
struct NowWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.now.identifier, provider: NowProvider()) { entry in
            NowRoot(entry: entry)
        }
        .configurationDisplayName(Text("지금"))
        .description(Text("오늘 다시 볼 것·오늘 일정·고정한 메모 — 앱의 「지금」 그대로."))
        .supportedFamilies(Self.families)
    }

    private static var families: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline]
        #else
        [.systemSmall, .systemMedium, .systemLarge]
        #endif
    }
}

struct NowEntry: TimelineEntry, Sendable {
    let date: Date
    let cards: [Recall.Card]
    /// 큰 위젯의 아래 절 — 오늘 뒤에 올 일정.
    let upcoming: [WidgetAgenda.Upcoming]

    static func make(_ memos: [Memo], at date: Date, seen: [ULID: Date]) -> NowEntry {
        NowEntry(
            date: date,
            cards: WidgetAgenda.nowCards(memos, now: date, seen: seen),
            // 큰 위젯의 아래 절. 넉이다 — 카드 세 장과 「다음」 머리를 빼고 남는 자리에 줄을
            // 30pt 씩 놓으면 그만큼이 들어간다. 더 부르면 잘린 줄이 생기고, 잘린 줄은
            // 안 보이는 것보다 나쁘다.
            upcoming: WidgetAgenda.upcoming(memos, now: date, limit: 4)
        )
    }

    static func sample(at date: Date = Date()) -> NowEntry {
        make(WidgetSample.memos(now: date), at: date, seen: [:])
    }

    /// 빈 위젯의 견본 — 빈 상태를 눈으로 보려면 이것이 필요하다.
    static func empty(at date: Date = Date()) -> NowEntry {
        NowEntry(date: date, cards: [], upcoming: [])
    }
}

struct NowProvider: TimelineProvider {
    func placeholder(in context: Context) -> NowEntry { .sample() }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (NowEntry) -> Void) {
        // 갤러리에는 견본을 — 빈 위젯을 보고는 무엇인지 알 수 없다.
        if context.isPreview { completion(.sample()); return }
        Task {
            let memos = await WidgetVault.memos()
            completion(.make(memos, at: Date(), seen: NowSeen.load()))
        }
    }

    /// 장면은 「지금」이 바뀌는 순간마다 하나 — 시각이 지나 「지남」이 되고, 자정에 오늘이 바뀐다
    /// (`WidgetAgenda.moments`). 앱이 파일을 바꾸면 `WidgetRefresher` 가 처음부터 다시 부른다.
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<NowEntry>) -> Void) {
        Task {
            let memos = await WidgetVault.memos()
            let seen = NowSeen.load()
            let entries = WidgetAgenda.moments(memos, now: Date()).map { NowEntry.make(memos, at: $0, seen: seen) }
            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }
}

/// 확장 안에서는 시스템이 크기와 렌더 모드를 준다. 얼굴(`NowView`)은 크기를 손으로도 받는다 —
/// `@Environment(\.widgetFamily)` 는 읽기 전용이라 렌더 검증이 그렇게 부른다.
struct NowRoot: View {
    let entry: NowEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        NowView(entry: entry, family: family)
            .widgetPaper(.resolved(mode))
    }
}

#if DEBUG
#Preview("지금 · 작게", as: .systemSmall) { NowWidget() } timeline: { NowEntry.sample() }
#Preview("지금 · 중간", as: .systemMedium) { NowWidget() } timeline: { NowEntry.sample() }
#Preview("지금 · 크게", as: .systemLarge) { NowWidget() } timeline: { NowEntry.sample() }
#Preview("지금 · 빈 자리", as: .systemMedium) { NowWidget() } timeline: { NowEntry.empty() }
#if os(iOS)
#Preview("지금 · 잠금 네모", as: .accessoryRectangular) { NowWidget() } timeline: { NowEntry.sample() }
#Preview("지금 · 잠금 한 줄", as: .accessoryInline) { NowWidget() } timeline: { NowEntry.sample() }
#endif
#endif
