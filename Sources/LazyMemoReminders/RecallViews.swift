import LazyMemoCore
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 「이 기기에서 알림 받기」 — 폰의 More 메뉴와 맥의 설정 메뉴, 그리고 다시 보기
/// 화면의 아래쪽이 같은 것을 보여 준다.
///
/// **켜기 전에 잠금 화면에 제목이 보인다고 적는다.** 알림은 메모의 첫 줄을
/// 그대로 들고 나가므로, 그것을 켠 뒤에 알게 되면 늦다. 다른 기기의 변경이
/// 언제 반영되는지도 켜기 전에 읽는다 — 완벽한 동기화를 약속하지 않는다.
///
/// **켜고 나면 설명은 접힌다.** 이미 켠 사람에게 같은 문단이 매번 서 있으면
/// 시각을 고르는 손이 그것을 밀어내야 한다. 켜짐·걸어 둔 수만 남기고, 기기별
/// 안내는 펼쳐야 보인다 (`folded`).
public struct ReminderSettingsView: View {
    @State private var center = ReminderCenter.shared
    @State private var requesting = false
    @State private var showsGuide = false
    public init() {}

    /// 켜져 있고 탈이 없으면 설명이 접힌다.
    private var folded: Bool { center.enabled && !center.denied && center.trouble == nil }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L("필요할 때 알림"), systemImage: "bell").font(.headline)
            if !folded {
                Text(L("이 기기에서 일정 시각과 다시 볼 시각에 알려드려요. 잠금 화면에 메모 제목이 표시됩니다."))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Toggle(L("이 기기에서 알림 받기"), isOn: Binding(
                get: { center.enabled },
                set: { value in
                    requesting = true
                    Task { await center.setEnabled(value); requesting = false }
                }))
                .disabled(requesting || !center.available)
                .accessibilityIdentifier("recall-enable")
            if !center.available {
                Text(L("설치된 앱에서만 알림을 켤 수 있어요.")).font(.footnote).foregroundStyle(.secondary)
            }
            if center.enabled, center.denied {
                Text(L("시스템에서 알림이 꺼져 있어요. 설정에서 허용하면 이 기기에서 다시 걸어요."))
                    .font(.footnote)
                    .accessibilityIdentifier("recall-denied")
                Button(L("알림 설정 열기")) { openSystemSettings() }
            }
            if center.enabled, !center.denied {
                Text(L("걸어 둔 알림 \(center.scheduledCount)개"))
                    .font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("recall-count")
            }
            if center.overflow > 0 {
                Text(L("가까운 \(Recall.reservationLimit)개를 걸었어요. 나머지 \(center.overflow)개는 앱을 다시 열 때 채워져요."))
                    .font(.footnote)
            }
            if let trouble = center.trouble {
                Text(trouble).font(.footnote).foregroundStyle(.red)
                    .accessibilityIdentifier("recall-trouble")
                Button(L("다시 시도")) { center.refresh() }
            }
            if folded {
                DisclosureGroup(isExpanded: $showsGuide) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("이 기기에서 일정 시각과 다시 볼 시각에 알려드려요. 잠금 화면에 메모 제목이 표시됩니다."))
                        guide
                    }
                    .padding(.top, 6)
                } label: {
                    Text(L("기기별 알림 안내")).font(.footnote).foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("recall-guide")
            } else {
                guide
            }
        }
        .task { center.refresh() }
    }

    private var guide: some View {
        Text(L("다른 기기에서 바꾼 것은 이 앱이 그 파일을 읽은 뒤에 반영돼요. 양쪽 기기에서 켜면 양쪽에서 울릴 수 있어요. 집중 모드와 시스템 설정에 따라 전달이 달라져요."))
            .font(.caption).foregroundStyle(.secondary)
    }

    private func openSystemSettings() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
        #else
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

/// 메모 한 장의 「다시 볼 시각」 — 일정은 그대로 두고, 이 메모를 다시 펼칠 순간만 정한다.
///
/// 해제는 **따로 정한 시각만** 지운다. 일정 시각이 있으면 그때는 여전히 알리므로
/// 그 사실을 해제 단추 옆에 적는다 — 「해제했는데 울렸다」가 되면 안 된다.
public struct RecallEditor: View {
    private let store: MemoStore
    private let id: ULID
    @State private var date: Date
    @State private var saving = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    public init(store: MemoStore, id: ULID, now: Date = Date()) {
        self.store = store
        self.id = id
        let current = store.memo(id)?.surface
        let earliest = now.addingTimeInterval(60)
        _date = State(initialValue: max(current ?? now.addingTimeInterval(3600), earliest))
    }

    public var body: some View {
        #if os(macOS)
        content.frame(width: 440)
        #else
        NavigationStack {
            ScrollView { content }
                .navigationTitle(L("다시 보기"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(L("닫기")) { close() }.disabled(saving) }
                }
        }
        #endif
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            #if os(macOS)
            HStack {
                Text(L("다시 보기")).font(.title2.bold())
                Spacer()
                Button(L("닫기")) { close() }.disabled(saving)
            }
            #endif
            if let memo = store.memo(id) {
                Text(memo.title).font(.headline).lineLimit(2)
                Text(L("일정은 그대로 두고, 이 메모를 다시 펼칠 시각만 정해요."))
                    .font(.subheadline).foregroundStyle(.secondary)
                if let surface = memo.surface {
                    Label(L("지금은 \(Self.when(surface))에 다시 봐요"), systemImage: "bell.fill")
                        .font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("recall-current")
                }
                if let at = memo.at {
                    Label(L("일정은 \(Self.when(at))"), systemImage: "calendar")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                DatePicker(L("다시 볼 시각"), selection: $date, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .accessibilityIdentifier("recall-date")
                HStack {
                    Button(L("한 시간 뒤")) { date = Date().addingTimeInterval(3600) }
                    Button(L("내일 아침 9시")) { date = Self.tomorrowMorning() }
                }
                .buttonStyle(.bordered)
                Button(L("이때 다시 보기")) { save(date) }
                    .buttonStyle(.borderedProminent)
                    .disabled(saving || date <= Date())
                    .accessibilityIdentifier("recall-save")
                if memo.surface != nil {
                    Button(L("다시 보기 해제"), role: .destructive) { save(nil) }
                        .disabled(saving)
                        .accessibilityIdentifier("recall-clear")
                    if memo.at != nil {
                        Text(L("해제해도 일정 시각에는 알려드려요."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !Recall.eligible(memo) {
                    Text(L("치워 두었거나 모두 체크한 메모는 알림을 걸지 않아요."))
                        .font(.footnote)
                }
                if let error {
                    Text(error).font(.footnote).foregroundStyle(.red)
                        .accessibilityIdentifier("recall-error")
                }
                Divider().padding(.vertical, 4)
                ReminderSettingsView()
            } else {
                Text(L("이 메모는 이제 없습니다."))
            }
        }
        .padding(24)
    }

    static func when(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    static func tomorrowMorning(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    private func save(_ value: Date?) {
        if let value, value <= Date() { return }
        saving = true
        Task {
            do {
                _ = try await store.update(id, surface: .some(value))
                ReminderCenter.shared.refresh()
                close()
            } catch {
                self.error = L("저장하지 못했어요. 다시 시도해 주세요.")
            }
            saving = false
        }
    }

    private func close() {
        #if os(macOS)
        RecallWindow.close()
        #else
        dismiss()
        #endif
    }
}
