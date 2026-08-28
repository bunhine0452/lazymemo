import LazyMemoCore
import SwiftUI

/// 바탕화면 달력 (설계문서 §10).
struct CalendarView: View {
    @Bindable var model: CalendarModel
    var onClose: () -> Void
    var onSelectMemo: (ULID) -> Void

    @State private var isHovering = false

    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        VStack(spacing: 0) {
            header
            weekdayRow
            monthGrid
            if !model.selectedEvents.isEmpty {
                Divider().opacity(0.4)
                dayDetail
            }
        }
        .padding(.bottom, 8)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.black.opacity(0.06))
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .onHover { isHovering = $0 }
        .task { await model.refresh() }
    }

    // MARK: 머리

    private var header: some View {
        HStack(spacing: 4) {
            Text(model.grid.title)
                .font(.system(size: 13, weight: .semibold))

            Spacer(minLength: 8)

            if !model.isShowingCurrentMonth {
                Button("오늘") { model.goToToday() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.tint.opacity(0.20)))
            }

            stepButton("chevron.left", months: -1)
            stepButton("chevron.right", months: 1)

            if isHovering {
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.leading, 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 11)
        .padding(.bottom, 8)
    }

    private func stepButton(_ symbol: String, months: Int) -> some View {
        Button { model.step(months) } label: {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                Text(symbol)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(index == 0 ? Color.red.opacity(0.7) : .secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 4)
    }

    // MARK: 격자

    private var monthGrid: some View {
        VStack(spacing: 2) {
            ForEach(Array(model.grid.weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 2) {
                    ForEach(week) { day in
                        dayCell(day)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
    }

    private func dayCell(_ day: MonthGrid.Day) -> some View {
        let events = model.events(on: day.date)
        let isSelected = model.selectedDay == day.date

        return VStack(spacing: 2) {
            Text("\(day.date.day)")
                .font(.system(size: 11, weight: model.isToday(day.date) ? .bold : .regular))
                .foregroundStyle(day.isOverflow ? .tertiary : .primary)

            // 점 세 개까지만. 그 이상은 날짜를 눌러 목록에서 본다.
            HStack(spacing: 2) {
                ForEach(events.prefix(3), id: \.id) { memo in
                    Circle().fill(memo.color.tint).frame(width: 4, height: 4)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 3)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 6).fill(.tint.opacity(0.22))
            } else if model.isToday(day.date) {
                RoundedRectangle(cornerRadius: 6).strokeBorder(.tint.opacity(0.55), lineWidth: 1)
            }
        }
        .contentShape(.rect)
        .onTapGesture {
            model.selectedDay = (model.selectedDay == day.date) ? nil : day.date
        }
    }

    // MARK: 선택한 날

    private var dayDetail: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(model.selectedEvents) { memo in
                HStack(spacing: 6) {
                    Circle().fill(memo.color.tint).frame(width: 6, height: 6)
                    if let at = memo.at {
                        Text(at.formatted(.dateTime.hour().minute()))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Text(memo.title)
                        .font(.system(size: 11))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
                .onTapGesture { onSelectMemo(memo.id) }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }
}
