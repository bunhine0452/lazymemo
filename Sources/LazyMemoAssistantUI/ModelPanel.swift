import LazyMemoAssistant
import SwiftUI

/// 모델의 상태 한 줄 — 없으면 받기(크기·오프라인 설명), 받는 중이면 진행·취소, 있으면 지우기.
struct ModelPanel: View {
    let model: AssistantModel
    @State private var confirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let download = model.download {
                HStack {
                    ProgressView(value: download.fraction)
                    Text(download.verifying ? L("확인 중") : Self.bytes(download.received) + " / " + Self.bytes(download.total))
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    Button(L("취소")) { model.cancelDownload() }.buttonStyle(.borderless)
                }
            } else {
                switch model.availability {
                case .ready:
                    HStack {
                        Label(L("\(model.manifest.displayName) 이 이 기기에 있습니다"), systemImage: "checkmark.circle")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(L("지우기"), role: .destructive) { confirmingDelete = true }.buttonStyle(.borderless).font(.caption)
                    }
                    .confirmationDialog(L("모델 \(Self.bytes(model.manifest.file.bytes)) 을(를) 지울까요? 다시 받을 수 있습니다."),
                                        isPresented: $confirmingDelete, titleVisibility: .visible) {
                        Button(L("지우기"), role: .destructive) { Task { await model.deleteModel() } }
                    }
                case .notDownloaded, .corrupted, .downloading:
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.manifest.displayName + " — " + Self.bytes(model.manifest.file.bytes))
                            .font(.subheadline.weight(.medium))
                        Text(L("메모를 읽고 답하는 일은 전부 이 기기 안에서 합니다. 인터넷은 지금 한 번, 받을 때만 씁니다. Wi-Fi 에서 받는 것을 권합니다."))
                            .font(.caption).foregroundStyle(.secondary)
                        if let error = model.downloadError {
                            Text(error).font(.caption).foregroundStyle(.red)
                        }
                        Button(L("받기")) { model.startDownload() }.buttonStyle(.borderedProminent).controlSize(.small)
                    }
                case .unsupportedDevice:
                    Text(L("이 기기에서는 쓸 수 없습니다")).font(.caption).foregroundStyle(.secondary)
                case .insufficientMemory:
                    Text(L("메모리가 부족해 모델을 올리지 못합니다")).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    static func bytes(_ n: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: n, countStyle: .file)
    }
}
