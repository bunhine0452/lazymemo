import LazyMemoCore
import SwiftUI
import UIKit
import UniformTypeIdentifiers

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
            parts.append("\(day.month)월 \(day.day)일 \(String(format: "%d:%02d", parts2.hour ?? 0, parts2.minute ?? 0)) · 달력으로")
        } else if let due = note.due {
            parts.append("\(due.month)월 \(due.day)일 · 달력으로")
        }
        if let place = note.place { parts.append("@" + place) }
        return parts.isEmpty ? nil : parts.joined(separator: "   ")
    }

    /// 날짜가 읽혔으면 단추가 그렇게 말한다 — 앱의 펜과 같다.
    private var leaveLabel: String {
        guard let inbound = InboundNote.make(text: text) else { return "메모 남기기" }
        let note = NoteReader.read(inbound)
        return note.due == nil && note.at == nil ? "메모 남기기" : "달력에 남기기"
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
                try await InboxDrop.drop(inbound, into: paths)
                context?.completeRequest(returningItems: nil)
            } catch {
                trouble = "적지 못했습니다 — \(error)"
            }
        }
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
