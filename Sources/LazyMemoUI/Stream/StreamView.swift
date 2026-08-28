import LazyMemoCore
import SwiftUI

/// 「흐름」 — 바탕화면에 놓인 시간축 (철학 2).
///
/// 위에는 이번 달의 점 스트립(조망), 아래에는 오늘부터 흐르는 날들.
/// 아무것도 없는 날은 나타나지 않는다 — 빈 칸을 보여주는 것은 "여기를 채워라"
/// 라고 말하는 것이고, 이 앱은 그러지 않는다 (철학 1).
struct StreamView: View {
    @Bindable var model: StreamModel
    var onClose: () -> Void
    var onSelectMemo: (ULID) -> Void

    @State private var isHovering = false
    @Environment(\.rendersStatically) private var rendersStatically

    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        VStack(spacing: 0) {
            header
            strip
            Divider().opacity(0.3).padding(.horizontal, Theme.normal)
            stream
        }
        .background(Theme.paper(MemoColor.gray.ink, dotted: false))
        .overlay(Theme.edge())
        .overlay { HoverSensor { isHovering = $0 } }
        .animation(Theme.reveal, value: isHovering)
        .task { await model.refresh() }
    }

    // MARK: 머리

    private var header: some View {
        HStack(spacing: Theme.tight) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(verbatim: "\(model.strip.year)")
                    .font(Theme.micro)
                    .foregroundStyle(.tertiary)
                Text("\(model.strip.month)월")
                    .font(Theme.title)
            }

            Spacer(minLength: Theme.tight)

            if !model.isStripOnCurrentMonth {
                Button("오늘") { model.resetStrip() }
                    .buttonStyle(.plain)
                    .font(Theme.micro)
                    .padding(.horizontal, Theme.tight + 1)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.highlight.opacity(0.28)))
            }

            QuietButton(symbol: "chevron.left", help: "이전 달") { model.stepStrip(-1) }
            QuietButton(symbol: "chevron.right", help: "다음 달") { model.stepStrip(1) }

            if isHovering {
                QuietButton(symbol: "xmark", help: "치우기", action: onClose)
            }
        }
        .padding(.horizontal, Theme.normal)
        .padding(.top, Theme.snug + 1)
        .padding(.bottom, Theme.tight)
    }

    // MARK: 점 스트립 — 숫자 없는 조망

    /// 날짜 숫자를 지웠다. 여기서 알고 싶은 것은 "며칠이 무슨 요일인가" 가
    /// 아니라 **"이번 달 어디가 붐비는가"** 이고, 숫자는 그 신호를 덮는다.
    private var strip: some View {
        VStack(spacing: 3) {
            HStack(spacing: 0) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.system(size: 8))
                        .foregroundStyle(weekdayColor(index))
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(Array(model.strip.weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(week) { day in
                        stripCell(day)
                    }
                }
            }
        }
        .padding(.horizontal, Theme.normal)
        .padding(.bottom, Theme.snug)
    }

    /// 숫자는 **일이 있는 날과 오늘에만** 적는다.
    ///
    /// 모든 칸에 숫자를 채우면 "어디가 붐비는가" 라는 신호가 숫자에 묻히고,
    /// 반대로 전부 점만 찍으면 "15일이 무슨 요일이지" 에 답하지 못한다.
    /// 의미 있는 날에만 숫자를 두면 둘 다 얻는다.
    private func stripCell(_ day: MonthGrid.Day) -> some View {
        let count = model.stripCounts[day.date.description] ?? 0
        let isToday = model.isToday(day.date)
        let isMarked = count > 0 || isToday

        return ZStack {
            if isToday {
                Circle()
                    .fill(Theme.highlight)
                    .frame(width: 15, height: 15)
            }

            if isMarked {
                Text("\(day.date.day)")
                    .font(.system(size: 9, weight: isToday ? .bold : .medium))
                    .foregroundStyle(
                        isToday ? AnyShapeStyle(Color.black.opacity(0.82))
                        : day.isOverflow ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary)
                    )
            } else {
                Circle()
                    .fill(.primary)
                    .opacity(day.isOverflow ? 0.05 : 0.13)
                    .frame(width: 3, height: 3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 16)
        .overlay(alignment: .bottom) {
            // 일이 여럿인 날은 아래에 막대로 밀도를 보인다.
            if count > 0 {
                Capsule()
                    .fill(Theme.accent)
                    .opacity(min(0.4 + Double(count) * 0.2, 1))
                    .frame(width: min(CGFloat(count) * 4 + 3, 13), height: 2)
                    .offset(y: 1)
            }
        }
        .contentShape(.rect)
        .help(day.date.description)
    }

    private func weekdayColor(_ index: Int) -> Color {
        switch index {
        case 0: Theme.sunday
        case 6: Theme.saturday
        default: .secondary
        }
    }

    // MARK: 흐름

    @ViewBuilder
    private var stream: some View {
        if rendersStatically {
            // ScrollView 는 화면 밖 렌더에서 내용을 그리지 않는다.
            // 미리보기에서는 스크롤 없이 그대로 편다.
            days.padding(.horizontal, Theme.normal).padding(.vertical, Theme.snug)
        } else {
            scrollingStream
        }
    }

    private var scrollingStream: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                days
                    .padding(.horizontal, Theme.normal)
                    .padding(.vertical, Theme.snug)
            }
            .onChange(of: model.days.count) {
                // 지난 것을 펼치면 화면이 위로 튄다. 오늘을 붙잡아 둔다.
                proxy.scrollTo(model.today.description, anchor: .top)
            }
        }
    }

    /// 흐름의 알맹이. 스크롤 안이든 밖이든 같은 것을 그린다.
    ///
    /// LazyVStack 이 아니라 VStack 인 이유: 흐름에 들어오는 것은 "일정이 있는
    /// 날" 뿐이라 개수가 적고, 게으른 쪽은 화면 밖 렌더에서 실체화되지 않는다.
    private var days: some View {
        VStack(alignment: .leading, spacing: Theme.snug) {
            ForEach(model.days) { day in
                daySection(day)
                    .id(day.id)
            }

            if model.days.count <= 1 {
                Text("앞으로 잡힌 일이 없습니다")
                    .font(Theme.label)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, Theme.tight)
            }

            pastToggle
            Spacer(minLength: 0)
        }
    }

    private func daySection(_ day: StreamModel.Day) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            // 빈 날에 "비어 있습니다" 라고 적지 않는다. 그것은 채우라는
            // 말이고, 이 앱은 완성을 요구하지 않는다 (철학 1). 날짜만 조용히 선다.
            dayLabel(day)

            ForEach(day.memos) { memo in
                memoRow(memo, isPast: day.date < model.today)
            }
        }
    }

    private func dayLabel(_ day: StreamModel.Day) -> some View {
        let isToday = model.isToday(day.date)
        let isPast = day.date < model.today

        return HStack(spacing: Theme.tight) {
            Text(dayTitle(day.date))
                .font(.system(size: 11, weight: isToday ? .bold : .medium))
                .foregroundStyle(
                    isToday ? AnyShapeStyle(Theme.highlight)
                    : isPast ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary)
                )

            Rectangle()
                .fill(.primary.opacity(isToday ? 0.18 : 0.07))
                .frame(height: 1)
        }
    }

    private func dayTitle(_ date: CalendarDate) -> String {
        guard let start = date.startOfDay() else { return date.description }
        if model.isToday(date) { return "오늘" }
        return start.formatted(.dateTime.month().day().weekday(.abbreviated))
    }

    private func memoRow(_ memo: Memo, isPast: Bool) -> some View {
        HStack(spacing: Theme.tight) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(memo.color.tint)
                .frame(width: 3, height: 13)

            if let at = memo.at {
                Text(at.formatted(.dateTime.hour().minute()))
                    .font(Theme.microMono)
                    .foregroundStyle(.secondary)
            }

            Text(memo.title)
                .font(Theme.label)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .opacity(isPast ? 0.5 : 1)
        .padding(.vertical, 2)
        .padding(.leading, 2)
        .contentShape(.rect)
        .onTapGesture { onSelectMemo(memo.id) }
    }

    private var pastToggle: some View {
        Button {
            model.showsPast.toggle()
        } label: {
            Label(
                model.showsPast ? "지난 것 접기" : "지난 것 보기",
                systemImage: model.showsPast ? "chevron.up" : "chevron.down"
            )
            .font(Theme.micro)
            .foregroundStyle(.tertiary)
        }
        .buttonStyle(.plain)
        .padding(.top, Theme.tight)
    }
}
