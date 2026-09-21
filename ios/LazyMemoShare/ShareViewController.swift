import LazyMemoCore
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import UserNotifications

/// 공유 시트의 「lazymemo 에 적기」 — 맥의 서비스 메뉴와 같은 문.
///
/// 받은 글을 한 번 보여 주고(고칠 수 있다) 「메모 남기기」로 끝난다. 앱을 띄우지
/// 않고 정본 한 장만 떨군다 (`InboxDrop`) — 앱이 다음에 켜지면 목록에 있다.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: ShareSheet(context: extensionContext))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }
}

private struct ShareSheet: View {
    let context: NSExtensionContext?

    @State private var text = ""
    @State private var trouble: String?
    /// 떨구는 중. iCloud 컨테이너를 찾는 데 한 박자 걸리는데, 그 사이 한 번 더
    /// 누르면 같은 글이 두 장 된다.
    @State private var leaving = false
    /// 적은 뒤의 영수증 — 「적었어요 · 이 기기에 알림 예약됨 · …」. **이 기기에서 확인한 사실**만 (`ReservationReceipt`).
    /// 한 박자 보여 주고 닫는다: 시트가 곧장 사라지면 알림이 걸렸는지 아닌지 알 길이 없다.
    @State private var receipt: ReservationReceipt?
    @FocusState private var editing: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $text)
                    .focused($editing)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    .frame(maxHeight: 220)
                // 펜과 같은 얼굴 — 읽은 것이 있으면 칩으로 보인다 (MOBILE_DESIGN §8).
                if let chip = readChip {
                    Text(chip)
                        .font(.footnote.weight(.medium).monospacedDigit())
                        .foregroundStyle(Color(red: 0.56, green: 0.37, blue: 0.05))
                        .padding(.horizontal, 10)
                        .frame(minHeight: 32)
                        .background(Color(red: 0.97, green: 0.72, blue: 0.24).opacity(0.38), in: RoundedRectangle(cornerRadius: 8))
                }
                if let trouble {
                    Text(trouble).font(.footnote).foregroundStyle(.red)
                }
                if let receipt {
                    Label(receiptText(receipt), systemImage: { if case .scheduled = receipt { "bell" } else { "checkmark.circle" } }())
                        .font(.footnote)
                        .foregroundStyle(receipt == .failed ? .orange : .secondary)
                        .accessibilityIdentifier("share-receipt")
                }
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("lazymemo 에 적기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Cancel 은 왼쪽, 확정은 오른쪽 — 시트의 관용구.
                ToolbarItem(placement: .cancellationAction) {
                    Button("그만두기") {
                        context?.cancelRequest(withError: CocoaError(.userCancelled))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(leaveLabel, action: leave)
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.16, green: 0.32, blue: 0.27))
                        .disabled(leaving || InboundNote.make(text: text) == nil)
                }
            }
        }
        .task {
            text = await SharedInput.text(from: context)
            editing = text.isEmpty
        }
    }

    /// 읽은 것 한 조각 — 날짜(와 장소).
    private var readChip: String? {
        guard let inbound = InboundNote.make(text: text) else { return nil }
        let note = NoteReader.read(inbound)
        var parts: [String] = []
        if let at = note.at {
            let day = CalendarDate(at)
            let parts2 = Calendar.current.dateComponents([.hour, .minute], from: at)
            let clock = String(format: "%d:%02d", parts2.hour ?? 0, parts2.minute ?? 0)
            parts.append(String(localized: "\(DateWords.monthDay(day)) \(clock) · 달력으로"))
        } else if let due = note.due {
            parts.append(String(localized: "\(DateWords.monthDay(due)) · 달력으로"))
        }
        if let place = note.place { parts.append("@" + place) }
        return parts.isEmpty ? nil : parts.joined(separator: "   ")
    }

    /// 날짜가 읽혔으면 단추가 그렇게 말한다 — 앱의 펜과 같다.
    private var leaveLabel: String {
        guard let inbound = InboundNote.make(text: text) else { return String(localized: "메모 남기기") }
        let note = NoteReader.read(inbound)
        return note.due == nil && note.at == nil ? String(localized: "메모 남기기") : String(localized: "달력에 남기기")
    }

    private func leave() {
        guard !leaving, let inbound = InboundNote.make(text: text) else { return }
        leaving = true
        Task {
            defer { leaving = false }
            let container = await Task.detached(priority: .userInitiated) {
                AppPaths.ubiquityContainer()
            }.value
            let paths = AppPaths.resolveCloud(
                container: container, shared: AppPaths.sharedContainer()
            ).paths
            do {
                let memo = try await InboxDrop.drop(inbound, into: paths)
                // 자리가 있는 약속이면 앱이 「어디서 출발하시나요?」를 묻게 남긴다 — 여기엔 펜이 없다 (`RouteAsk`).
                if RouteAsk.applies(memo) { await RouteAskDrop.leave(memo) }
                // 다시 보기 알림은 앱과 같은 이름으로 여기서 건다 — 앱을 열기 전에 시각이 올 수 있다 (`RecallDrop`).
                let result = await RecallDrop.leave(memo, group: AppPaths.sharedContainer())
                receipt = result
                // 한 박자 보여 주고 닫는다. 그냥 글이면 말할 것이 없어 바로 닫는다.
                if result.line() != nil { try? await Task.sleep(for: .milliseconds(1400)) }
                context?.completeRequest(returningItems: nil)
            } catch {
                trouble = String(localized: "적지 못했습니다 — \(String(describing: error))")
            }
        }
    }

    /// 「적었어요 · 이 기기에 알림 예약됨 · 9월 25일 9:00」 — 인텐트의 대답과 같은 말.
    private func receiptText(_ receipt: ReservationReceipt) -> String {
        let head = String(localized: "적었어요")
        guard let line = receipt.line() else { return head }
        return head + " · " + line
    }
}

/// 공유 시트가 건네는 것에서 글을 꺼낸다. 글이면 글, 주소면 주소 — 둘 다면 이어 붙인다.
enum SharedInput {
    static func text(from context: NSExtensionContext?) async -> String {
        var pieces: [String] = []
        for case let item as NSExtensionItem in context?.inputItems ?? [] {
            for provider in item.attachments ?? [] {
                if let text = await load(provider, as: .plainText) as? String {
                    pieces.append(text)
                } else if let url = await load(provider, as: .url) as? URL {
                    pieces.append(url.absoluteString)
                }
            }
            if pieces.isEmpty, let attributed = item.attributedContentText?.string, !attributed.isEmpty {
                pieces.append(attributed)
            }
        }
        return pieces.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func load(_ provider: NSItemProvider, as type: UTType) async -> Any? {
        guard provider.hasItemConformingToTypeIdentifier(type.identifier) else { return nil }
        let loaded = try? await provider.loadItem(forTypeIdentifier: type.identifier)
        if let data = loaded as? Data, type == .plainText { return String(decoding: data, as: UTF8.self) }
        return loaded
    }
}

/// 다시 보기 알림을 시트에서 **그 자리에서** 건다 — `Sources/LazyMemoReminders/RecallDrop.swift` 의 한 벌.
///
/// 확장은 그 패키지를 들지 않는다(메모리 한도). 이름·내용은 Core 의 `Recall` 상수를 같이 쓰므로 앱의
/// 대조가 이것을 자기 것으로 알아보고 두 번 걸지 않는다. 한쪽을 고치면 다른 쪽도 같이.
enum RecallDrop {
    static func leave(_ memo: Memo, group: URL?, now: Date = Date()) async -> ReservationReceipt {
        guard Recall.eligible(memo) else { return .notWanted }
        guard let at = memo.surfacesAt else { return memo.due == nil ? .noTime : .dateOnly }
        guard at > now else { return .passed }
        guard let enabled = RecallSwitch.isEnabled(in: group) else { return .needsApp }
        guard enabled else { return .off }
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: break
        case .denied: return .denied
        default: return .needsApp
        }
        guard let reservation = Recall.reservations([memo], now: now).first else { return .passed }
        let content = UNMutableNotificationContent()
        content.title = reservation.title
        content.body = reservation.body ?? Recall.defaultNotificationBody
        content.sound = .default
        content.categoryIdentifier = reservation.body == nil ? Recall.recallCategory : Recall.departureCategory
        content.userInfo = [Recall.memoKey: memo.id.stringValue, Recall.dateKey: reservation.date.timeIntervalSince1970]
        let request = UNNotificationRequest(
            identifier: Recall.notificationID(for: memo.id), content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, reservation.date.timeIntervalSince(now)), repeats: false)
        )
        do {
            try await center.add(request)
            return .scheduled(reservation.date)
        } catch {
            return .failed
        }
    }
}

/// 공유 시트가 남기는 「어디서 출발하시나요?」 — 알림 하나와 앱 그룹의 표 (`RouteAsk`).
///
/// 알림은 앱이 「이 기기에서 알림 받기」로 권한을 받아 둔 기기에서만 걸린다(확장은 권한을 묻지 못한다).
/// 권한이 없으면 표만 남고, 앱을 다음에 열 때 펜이 묻는다.
enum RouteAskDrop {
    static func leave(_ memo: Memo) async {
        RouteAsk.remember(memo.id, in: AppPaths.sharedContainer())
        let center = UNUserNotificationCenter.current()
        guard case .authorized = await center.notificationSettings().authorizationStatus else { return }
        let content = UNMutableNotificationContent()
        content.title = memo.title
        content.body = RouteAsk.notificationBody
        content.sound = .default
        content.userInfo = ["memo": memo.id.stringValue, RouteAsk.askKey: RouteAsk.askValue]
        let request = UNNotificationRequest(
            identifier: RouteAsk.notificationPrefix + memo.id.stringValue, content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        )
        try? await center.add(request)
    }
}
