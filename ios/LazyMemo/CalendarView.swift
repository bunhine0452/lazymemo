import LazyMemoCore
import SwiftUI

/// 달력 — 위에 달, 아래에 그 날 (MOBILE_DESIGN §6). 미루기가 이 화면에서
/// 가장 자주 하는 일이라 한 손짓(오른쪽으로 밀기)이다.
struct CalendarView: View {
    let store: MemoStore
    let pen: PenModel
    let undo: UndoModel

    @State private var grid = MonthGrid.current()
    @State private var picked = CalendarDate(Date())
    @State private var inRange: [Memo] = []
    /// 「다른 날로」 — 들고 기다리는 메모. 칸을 누르면 그 날로 간다.
    @State private var holding: Memo?

    private var today: CalendarDate { CalendarDate(Date()) }

    private var marks: [CalendarDate: Int] {
        var counts: [CalendarDate: Int] = [:]
        for memo in inRange {
            guard let day = memo.scheduledDate() else { continue }
            counts[day, default: 0] += 1
        }
        return counts
    }

    private var rows: [AgendaRow] {
        DayAgenda.rows(memos: inRange.filter { $0.scheduledDate() == picked }, events: [])
    }

    var body: some View {
        VStack(spacing: 0) {
            MonthGridView(
                grid: grid, selected: picked, marks: marks, today: today, holding: holding != nil,
                onPick: pick,
                onStep: { grid = grid.advanced(by: $0) },
                onToday: { grid = MonthGrid.current(); pick(today) }
            )
            .padding(.top, 8)
            Divider().padding(.top, 8)
            dayList
        }
        .background(Paper.surface)
        .navigationTitle("달력")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ULID.self) { id in
            MemoEditorView(store: store, id: id, undo: undo)
        }
        .task(id: grid) { await load() }
        .onChange(of: store.memos) { _, _ in Task { await load() } }
        .onAppear { pen.presetDay = picked }
        .onTapGesture { holding = nil }
    }

    private var dayList: some View {
        List {
            Section {
                ForEach(rows) { row in
                    if case .memo(let memo) = row {
                        NavigationLink(value: memo.id) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(row.moment.map { DayWords.clock($0) } ?? "")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(Theme.highlightInk)
                                    .frame(width: 44, alignment: .trailing)
                                Circle().fill(memo.color.ink).frame(width: 8, height: 8)
                                Text(memo.title).font(.body).foregroundStyle(Paper.ink).lineLimit(2)
                                Spacer()
                            }
                            .frame(minHeight: 44)
                            .opacity(holding == nil || holding?.id == memo.id ? 1 : 0.4)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .leading) {
                            Button { postpone(memo) } label: { Label("미루기", systemImage: "arrow.right") }
                                .tint(Theme.accent)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { delete(memo) } label: { Label("지우기", systemImage: "trash") }
                                .tint(Theme.danger)
                            Button { unschedule(memo) } label: { Label("날짜 떼기", systemImage: "calendar.badge.minus") }
                                .tint(Theme.highlightInk)
                        }
                        .contextMenu {
                            Button { holding = memo } label: { Label("다른 날로", systemImage: "hand.point.up.left") }
                            Button { postpone(memo) } label: { Label("하루 미루기", systemImage: "arrow.right") }
                            Button { unschedule(memo) } label: { Label("날짜 떼기", systemImage: "calendar.badge.minus") }
                            Button(role: .destructive) { delete(memo) } label: { Label("지우기", systemImage: "trash") }
                        }
                    }
                }
                if rows.isEmpty {
                    Text("이 날은 비어 있습니다")
                        .font(.subheadline).foregroundStyle(Paper.fadedInk)
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
            } header: {
                HStack {
                    Text(DayWords.long(picked)).font(.headline).foregroundStyle(Paper.ink)
                    Spacer()
                    Button {
                        pen.presetDay = picked
                        pen.requestFocus()
                    } label: {
                        Label("이 날에 적기", systemImage: "pencil").font(.subheadline).foregroundStyle(Theme.accentInk)
                    }
                    .accessibilityIdentifier("write-on-day")
                }
                .textCase(nil)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: 손짓

    private func pick(_ day: CalendarDate) {
        if let held = holding {
            holding = nil
            move(held, to: day)
            return
        }
        picked = day
        pen.presetDay = day
        if day.year != grid.year || day.month != grid.month {
            grid = MonthGrid.make(year: day.year, month: day.month)
        }
    }

    private func load() async {
        guard let range = grid.range else { return }
        inRange = await store.scheduled(from: range.lowerBound, to: range.upperBound)
    }

    private func move(_ memo: Memo, to day: CalendarDate) {
        let before = Schedule(memo)
        let after = before.moved(to: day)
        Task {
            _ = try? await store.update(memo.id, due: .some(after.due), at: .some(after.at))
            undo.offer("\(day.month)월 \(day.day)일로 옮겼습니다") {
                _ = try? await store.update(memo.id, due: .some(before.due), at: .some(before.at))
            }
        }
    }

    private func postpone(_ memo: Memo) {
        let after = Schedule(memo).postponed(notBefore: today)
        guard let day = after.day() else { return }
        move(memo, to: day)
    }

    private func unschedule(_ memo: Memo) {
        let before = Schedule(memo)
        Task {
            _ = try? await store.update(memo.id, due: .some(nil), at: .some(nil))
            undo.offer("날짜를 뗐습니다") {
                _ = try? await store.update(memo.id, due: .some(before.due), at: .some(before.at))
            }
        }
    }

    private func delete(_ memo: Memo) {
        Task {
            try? await store.delete(memo.id)
            undo.offer("지웠습니다") { try? await store.restore(memo.id) }
        }
    }
}
