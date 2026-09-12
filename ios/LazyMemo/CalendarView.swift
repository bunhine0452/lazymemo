import LazyMemoCore
import SwiftUI

/// 달력 — 위에 달, 아래에 그 날 (MOBILE_DESIGN §6). 미루기는 한 손짓(오른쪽으로
/// 밀기), 다른 날로 옮기는 것은 **시스템 끌기** — 줄을 길게 눌러 칸에 놓는다.
/// 끌기를 못 쓰는 사람은 컨텍스트 메뉴의 「다른 날로」(날짜 시트)로.
struct CalendarView: View {
    let store: MemoStore
    let pen: PenModel
    let reveal: Reveal

    @Environment(\.undoManager) private var undoManager
    @State private var grid = MonthGrid.current()
    @State private var picked = CalendarDate(Date())
    @State private var inRange: [Memo] = []
    @State private var dating: Memo?
    @State private var opened: ULID?

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
                grid: grid, selected: picked, marks: marks, today: today,
                onPick: pick,
                onStep: { grid = grid.advanced(by: $0) },
                onToday: { grid = MonthGrid.current(); pick(today) },
                onDrop: { day, ids in
                    let moved = ids.compactMap(ULID.init).compactMap { id in inRange.first { $0.id == id } }
                    for memo in moved { move(memo, to: day) }
                    return !moved.isEmpty
                }
            )
            .padding(.top, 8)
            Divider().padding(.top, 8)
            dayList
        }
        .background(Paper.surface)
        .navigationTitle("달력")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $opened) { id in MemoEditorView(store: store, id: id, reveal: reveal) }
        .sheet(item: $dating) { memo in
            DateSheet(schedule: Schedule(memo), onChange: { schedule in
                guard let day = schedule.day() else { return }
                move(memo, to: day)
            }, onClear: { unschedule(memo) })
        }
        .task(id: grid) { await load() }
        .onChange(of: store.memos) { _, _ in Task { await load() } }
        .onAppear { pen.presetDay = picked }
    }

    private var dayList: some View {
        List {
            Section {
                ForEach(rows) { row in
                    if case .memo(let memo) = row {
                        Button { opened = memo.id } label: {
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
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .draggable(memo.id.stringValue) {
                            Text(memo.title).font(.body).padding(10).background(Paper.surface, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .leading) {
                            Button { postpone(memo) } label: { Label("미루기", systemImage: "arrow.right") }
                                .tint(Theme.accent)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { delete(memo) } label: { Label("지우기", systemImage: "trash") }
                            Button { unschedule(memo) } label: { Label("날짜 떼기", systemImage: "calendar.badge.minus") }
                                .tint(Theme.highlightInk)
                        }
                        .contextMenu {
                            Button { postpone(memo) } label: { Label("하루 미루기", systemImage: "arrow.right") }
                            Button { dating = memo } label: { Label("다른 날로", systemImage: "calendar") }
                            Button { unschedule(memo) } label: { Label("날짜 떼기", systemImage: "calendar.badge.minus") }
                            Divider()
                            Button(role: .destructive) { delete(memo) } label: { Label("지우기", systemImage: "trash") }
                        }
                        .accessibilityActions {
                            Button("하루 미루기") { postpone(memo) }
                            Button("다른 날로") { dating = memo }
                            Button("날짜 떼기") { unschedule(memo) }
                            Button("지우기") { delete(memo) }
                        }
                    }
                }
                if rows.isEmpty {
                    Text("이 날은 비어 있습니다")
                        .font(.subheadline).foregroundStyle(.secondary)
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
                        Label("이 날에 적기", systemImage: "pencil").font(.subheadline)
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
        guard after != before else { return }
        Task {
            _ = try? await store.update(memo.id, due: .some(after.due), at: .some(after.at))
            Undo.register("\(day.month)월 \(day.day)일로 옮기기", on: undoManager) {
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
            Undo.register("날짜 떼기", on: undoManager, reveal: reveal, id: memo.id) {
                _ = try? await store.update(memo.id, due: .some(before.due), at: .some(before.at))
            }
        }
    }

    private func delete(_ memo: Memo) {
        Task {
            try? await store.delete(memo.id)
            Undo.register("지우기", on: undoManager, reveal: reveal, id: memo.id) { try? await store.restore(memo.id) }
        }
    }
}
