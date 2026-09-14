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
    /// 처음부터 크게 연다 — 중간 높이에서는 격자 밑의 시각 칩이 접혀 반만 보였다.
    /// 시각은 날을 고른 다음 손이 바로 가는 자리라 첫 화면에 온전히 있어야 한다.
    @State private var detent: PresentationDetent = .large

    init(schedule: Schedule, onChange: @escaping (Schedule) -> Void, onClear: @escaping () -> Void) {
        self.schedule = schedule
        self.onChange = onChange
        self.onClear = onClear
        let anchor = schedule.day().flatMap { $0.startOfDay() } ?? Date()
        _grid = State(initialValue: MonthGrid.current(anchor))
        _customTime = State(initialValue: schedule.at ?? Date())
        // 10:30 처럼 준비된 칩에 없는 시각이면 휠을 편 채 연다 — 안 그러면 시각이
        // 있는데 어느 칩도 켜져 있지 않아 「시각 없음」으로 읽힌다.
        _custom = State(initialValue: Self.ownTime(schedule))
    }

    private var day: CalendarDate? { schedule.day() }

    /// 한 번에 누르는 시각. 정각만 — 9:30 은 「09:00」 칩이 켜지지 않는다.
    private static let presets = [9, 14]

    private static func clock(_ schedule: Schedule) -> Int? {
        guard let time = schedule.timeOfDay(), time.minute == 0 else { return nil }
        return time.hour
    }

    private var title: String {
        guard let day else { return "날짜" }
        guard let at = schedule.at else { return DayWords.long(day) }
        return "\(DayWords.long(day)) \(DayWords.clock(at))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    MonthGridView(
                        grid: grid,
                        selected: day,
                        onPick: { picked in
                            // 이웃 달의 칸을 누르면 격자도 그 달로 — 달력 탭과 같다.
                            if picked.year != grid.year || picked.month != grid.month {
                                grid = MonthGrid.make(year: picked.year, month: picked.month)
                            }
                            onChange(schedule.moved(to: picked))
                        },
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
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
    }

    private var timeRow: some View {
        HStack(spacing: 8) {
            Text("시각").font(.subheadline).foregroundStyle(.secondary)
            timeChip("없음", on: schedule.at == nil) { clearTime() }
            ForEach(Self.presets, id: \.self) { hour in
                timeChip(String(format: "%02d:00", hour), on: Self.clock(schedule) == hour) { set(hour: hour) }
            }
            timeChip("직접…", on: custom || Self.ownTime(schedule)) { toggleCustom() }
            Spacer()
        }
        .padding(.horizontal, 20)
        .disabled(day == nil)
        .opacity(day == nil ? 0.4 : 1)
    }

    /// 준비된 칩에 없는 시각이 붙어 있다 — 휠을 접어도 「직접…」이 켜져 있어야 한다.
    private static func ownTime(_ schedule: Schedule) -> Bool {
        schedule.at != nil && !presets.contains { clock(schedule) == $0 }
    }

    /// 휠을 펴는 순간 시각이 없으면 휠이 가리키는 시각이 붙는다 — 펴 놓고 돌리지
    /// 않으면 아무 시각도 안 붙던 것. 접는 것은 휠만 접는다.
    private func toggleCustom() {
        custom.toggle()
        if custom, schedule.at == nil { set(time: customTime) }
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
