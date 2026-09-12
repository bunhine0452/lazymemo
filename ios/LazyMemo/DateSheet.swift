import LazyMemoCore
import SwiftUI

/// 날짜 시트 — 묻는 상자가 아니라 달력 위에서 가리킨다 (MOBILE_DESIGN §5).
///
/// 비모달이다: 누르는 즉시 반영되므로 「취소」는 없고 「완료」만. medium 에
/// 격자가, large 에 시각 휠까지. 「날짜 떼기」는 Cancel 자리가 아니라 내용 안의
/// destructive 단추 — Cancel 자리는 「바꾼 것을 버린다」는 뜻이다. 유리 시트 그대로.
struct DateSheet: View {
    let schedule: Schedule
    var onChange: (Schedule) -> Void
    var onClear: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var grid: MonthGrid
    @State private var custom = false
    @State private var customTime = Date()

    init(schedule: Schedule, onChange: @escaping (Schedule) -> Void, onClear: @escaping () -> Void) {
        self.schedule = schedule
        self.onChange = onChange
        self.onClear = onClear
        let anchor = schedule.day().flatMap { $0.startOfDay() } ?? Date()
        _grid = State(initialValue: MonthGrid.current(anchor))
        _customTime = State(initialValue: schedule.at ?? Date())
    }

    private var day: CalendarDate? { schedule.day() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    MonthGridView(
                        grid: grid,
                        selected: day,
                        onPick: { picked in onChange(schedule.moved(to: picked)) },
                        onStep: { grid = grid.advanced(by: $0) },
                        onToday: {
                            grid = MonthGrid.current()
                            onChange(schedule.moved(to: CalendarDate(Date())))
                        }
                    )
                    timeRow
                    if custom {
                        DatePicker("시각", selection: $customTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .onChange(of: customTime) { _, time in set(time: time) }
                    }
                    if !schedule.isEmpty {
                        Button("날짜 떼기", role: .destructive) { onClear(); dismiss() }
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("clear-date")
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle(day.map { DayWords.long($0) } ?? "날짜")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var timeRow: some View {
        HStack(spacing: 8) {
            Text("시각").font(.subheadline).foregroundStyle(.secondary)
            timeChip("없음", on: schedule.at == nil) { clearTime() }
            timeChip("09:00", on: hour == 9) { set(hour: 9) }
            timeChip("14:00", on: hour == 14) { set(hour: 14) }
            timeChip("직접…", on: custom) { custom.toggle() }
            Spacer()
        }
        .padding(.horizontal, 20)
        .disabled(day == nil)
        .opacity(day == nil ? 0.4 : 1)
    }

    private var hour: Int? {
        schedule.at.map { Calendar.current.component(.hour, from: $0) }
    }

    @ViewBuilder
    private func timeChip(_ label: String, on: Bool, action: @escaping () -> Void) -> some View {
        if on {
            Button(label, action: action).buttonStyle(.borderedProminent).buttonBorderShape(.capsule).tint(Theme.accent)
                .font(.subheadline.monospacedDigit())
        } else {
            Button(label, action: action).buttonStyle(.bordered).buttonBorderShape(.capsule)
                .font(.subheadline.monospacedDigit())
        }
    }

    private func set(hour: Int) {
        guard let day, let base = day.startOfDay(),
              let at = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: base)
        else { return }
        custom = false
        onChange(Schedule(due: nil, at: at))
    }

    private func set(time: Date) {
        guard let day, let base = day.startOfDay() else { return }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        guard let at = Calendar.current.date(
            bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: base
        ) else { return }
        onChange(Schedule(due: nil, at: at))
    }

    private func clearTime() {
        guard let day else { return }
        custom = false
        onChange(Schedule(due: day, at: nil))
    }
}
