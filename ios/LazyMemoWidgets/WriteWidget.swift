import LazyMemoWidgetsCore
import SwiftUI
import WidgetKit

/// 「적기」— 누르면 펜이 올라온다 (`WidgetLink.write`).
///
/// 폰은 글 칸에 포커스가 가고 키보드가 오른다, 맥은 빠른 입력 상자가 뜬다 — 단축키 ⌥⌘N 과 같다.
/// 얼굴은 앱 아이콘의 두 글줄. 위젯이 말을 많이 하면 그건 위젯이지 문이 아니다.
struct WriteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.write.identifier, provider: WriteProvider()) { entry in
            WriteRoot(entry: entry)
        }
        .configurationDisplayName(Text("적기"))
        .description(Text("누르면 펜이 올라와요."))
        .supportedFamilies(Self.families)
    }

    private static var families: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .accessoryCircular, .accessoryInline]
        #else
        [.systemSmall]
        #endif
    }
}

struct WriteEntry: TimelineEntry, Sendable {
    let date: Date
}

/// 바뀌는 것이 없다 — 장면 하나, 다시 그릴 일도 없다.
struct WriteProvider: TimelineProvider {
    func placeholder(in context: Context) -> WriteEntry { WriteEntry(date: Date()) }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (WriteEntry) -> Void) {
        completion(WriteEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<WriteEntry>) -> Void) {
        completion(Timeline(entries: [WriteEntry(date: Date())], policy: .never))
    }
}

private struct WriteRoot: View {
    let entry: WriteEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        WriteView(entry: entry, family: family)
            .containerBackground(for: .widget) { Paper.surface }
    }
}

struct WriteView: View {
    let entry: WriteEntry
    let family: WidgetFamily

    var body: some View {
        Group {
            switch family {
            #if os(iOS)
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "pencil.line")
                        .font(.title3.weight(.medium))
                        .widgetAccentable()
                }
            case .accessoryInline:
                Label("lazymemo 에 적기", systemImage: "pencil.line")
            #endif
            default:
                VStack(alignment: .leading, spacing: 10) {
                    BrandMark(size: 40)
                    Spacer(minLength: 0)
                    Text("적기")
                        .font(.headline)
                        .foregroundStyle(Paper.ink)
                    Text("누르면 펜이 올라와요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .accessibilityLabel(Text("lazymemo 에 적기"))
        .widgetURL(WidgetLink.write)
    }
}
