import LazyMemoCore
import LazyMemoWidgetsCore
import SwiftUI
import WidgetKit

/// 네 위젯이 함께 쓰는 조각들 — 머리 한 줄, 줄머리의 색 획, 「오늘부터」 줄, 빈 자리.
///
/// 같은 뜻이면 같은 모양이어야 한다. 「지금」의 카드와 「달력」의 줄이 서로 다른 여백·
/// 다른 글자를 쓰면 홈 화면에 우리 위젯이 둘 얹혔을 때 그것이 한 앱의 것으로 보이지 않는다.

/// 위젯 한 장의 바탕과 색 — 루트마다 이 한 줄.
///
/// 바깥 여백은 얹지 않는다. 시스템이 표준 여백을 주고 ("use the standard margin width for
/// widgets — 16 points for most widgets"), 맥 데스크톱과 잠금 화면에서는 그보다 좁게 준다.
extension View {
    func widgetPaper(_ theme: WidgetTheme) -> some View {
        environment(\.widgetTheme, theme)
            .containerBackground(for: .widget) { PaperGround(theme: theme) }
    }
}

/// 머리 한 줄 — 왼쪽은 무엇인지, 오른쪽은 언제인지.
///
/// 작은 대문자처럼 보이게 자간을 준다 (한글에는 대문자가 없으니 굵기와 자간이 그 자리를
/// 대신한다). 11pt 아래로는 내려가지 않는다 — "display text using fonts at 11 points or larger".
struct WidgetHead: View {
    let kind: Text
    var trailing: Text?

    @Environment(\.widgetTheme) private var theme

    var body: some View {
        // 좁으면 날짜가 먼저 물러난다 — 무엇인지가 언제인지보다 먼저다.
        ViewThatFits(in: .horizontal) {
            line(withTrailing: true)
            line(withTrailing: false)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func line(withTrailing: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            kind
                .font(.caption2.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(theme.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if withTrailing, let trailing {
                trailing
                    .font(.caption2.weight(.medium).monospacedDigit())
                    .foregroundStyle(theme.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

/// 줄머리의 색 획 — 메모 색을 말하는 3pt 한 줄.
///
/// 앞선 판은 카드마다 종이 한 장(면 + 테두리)을 깔았다. 작은 위젯에서 그 도형들이 글보다
/// 먼저 보였고, 세 장이 서면 홈 화면에 네모가 아홉 개 생겼다. 색은 **테두리와 왼쪽에서
/// 번지는 잉크로만** 드러난다는 것이 이 앱의 규칙이다 (설계문서 §14.4) — 획 하나면 된다.
/// 덤으로 위젯이 이제 메모 색을 말한다: 앞선 판에는 없던 정보다.
/// **겹쳐 두지 나란히 두지 않는다.** `Capsule` 은 두 방향 모두 유연해서 `HStack` 안에 세우면
/// 줄 전체가 세로로 늘어난다 — 큰 위젯에서 카드 셋이 화면을 나눠 가지며 글 사이가 벌어졌다.
/// 겹쳐 두면 획의 키를 글 덩이가 정한다.
extension View {
    func inkBar(_ color: Color) -> some View {
        padding(.leading, WidgetMetrics.inkBar + 8)
            .overlay(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(color)
                    .frame(width: WidgetMetrics.inkBar)
                    .accessibilityHidden(true)
            }
    }
}

/// 「오늘  오후 3:00  치과」 — 날과 시각이 줄마다 **같은 자리**에 선다.
///
/// 앞선 판은 「오늘 · 오후 3:00」을 한 덩이로 붙여 제목 앞에 두었다. 줄마다 그 덩이의 길이가
/// 달라 제목이 지그재그로 시작했고, 훑는 눈이 매번 제목의 첫 글자를 찾아야 했다. 칸을 고정해
/// 두면 세로로 한 번만 훑으면 된다 ("Order content by relative importance").
struct AgendaRow: View {
    let row: WidgetAgenda.Upcoming
    let now: Date

    @Environment(\.widgetTheme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(WidgetWords.columnDay(row.day, now: now))
                .foregroundStyle(theme.accentInk)
                .frame(width: WidgetMetrics.dayColumn, alignment: .leading)
            Text(row.at.map(WidgetWords.time) ?? "")
                .foregroundStyle(theme.highlightInk)
                .frame(width: WidgetMetrics.timeColumn, alignment: .leading)
            Text(row.memo.title)
                .foregroundStyle(theme.ink)
                .privacySensitive()
            Spacer(minLength: 0)
        }
        .font(.caption.monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// 빈 위젯 — 한 줄과 문 하나.
///
/// 「없음」만 적힌 화면은 사용자가 할 일을 남기지 않는다. 위젯의 값은 "그래서 지금 뭘 하지"에
/// 답하는 것이므로 빈 자리에는 **적을 문**을 둔다 ("Useful widgets offer an easy way to
/// complete a task or action that's directly related to its content").
struct EmptyFace: View {
    let line: Text

    @Environment(\.widgetTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            line
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            WriteLink()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 「적기」 — 누르면 펜이 올라온다. 보이는 것은 30pt 캡슐이지만 과녁은 44 이상이다
/// ("make sure people can tap or click them with confidence").
struct WriteLink: View {
    @Environment(\.widgetTheme) private var theme

    var body: some View {
        Link(destination: WidgetLink.write) {
            Label("적기", systemImage: "pencil.line")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.onAccent)
                .padding(.horizontal, 12)
                .frame(minHeight: 30)
                .background(theme.accent, in: Capsule())
                .frame(height: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .widgetAccentable()
        .accessibilityLabel(Text("lazymemo 에 적기"))
    }
}
