import CoreGraphics
import Foundation

/// 창 하나의 화면 상태 (설계문서 §5.1, §7).
public struct WindowLayout: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    /// 어느 디스플레이에 있었는지. 복원 시 그 화면이 없으면 주 화면으로 끌어온다.
    public var displayUUID: String?
    /// 사용자가 창을 닫은 상태. **삭제가 아니다** — 저장 버튼이 없는 앱에서
    /// 창을 닫는 것은 "이 메모를 바탕화면에서 치운다"는 뜻이다.
    public var hidden: Bool

    public init(
        frame: CGRect,
        displayUUID: String? = nil,
        hidden: Bool = false
    ) {
        self.x = frame.origin.x
        self.y = frame.origin.y
        self.width = frame.size.width
        self.height = frame.size.height
        self.displayUUID = displayUUID
        self.hidden = hidden
    }

    public var frame: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

/// 창 좌표를 화면 안으로 끌어오는 계산 (설계문서 §7).
///
/// AppKit 에 기대지 않는 순수 함수로 둔 이유는 다중 디스플레이 연결·해제
/// 왕복(`{#multi-display}`)을 실제 모니터 없이 검증하기 위해서다.
public enum FrameClamping {
    /// 창이 최소한 이만큼은 화면 안에 남아야 한다 — 잡아서 끌 수 있어야 하므로.
    public static let minimumVisible: CGFloat = 80

    /// 창을 화면 **안쪽으로 완전히** 끌어온다. 화면보다 크면 화면에 맞춰 줄인다.
    ///
    /// 손잡이만 남기는 느슨한 규칙을 쓰지 않는 이유: 이 함수는 창이 이미
    /// 어느 화면에도 닿지 않을 때만 불린다. 그 상황에서 사용자가 원하는 것은
    /// "간신히 잡히는 창"이 아니라 "보이는 창"이다.
    public static func clamp(_ frame: CGRect, into visible: CGRect) -> CGRect {
        let size = CGSize(
            width: min(frame.width, visible.width),
            height: min(frame.height, visible.height)
        )
        return CGRect(
            x: min(max(frame.origin.x, visible.minX), visible.maxX - size.width),
            y: min(max(frame.origin.y, visible.minY), visible.maxY - size.height),
            width: size.width,
            height: size.height
        )
    }

    /// 복원 시 실제로 쓰는 경로. 어느 화면엔가 닿아 있으면 **건드리지 않는다** —
    /// 사용자가 일부러 화면 밖으로 걸쳐 놓은 창을 앱이 되돌려 놓으면 안 된다.
    public static func restore(
        _ frame: CGRect,
        onto screens: [CGRect],
        fallback: CGRect
    ) -> CGRect {
        isReachable(frame, on: screens) ? frame : clamp(frame, into: fallback)
    }

    /// 창이 화면 어딘가에 걸쳐 있는가. 아니면 복원 시 주 화면으로 데려와야 한다.
    public static func isReachable(_ frame: CGRect, on screens: [CGRect]) -> Bool {
        screens.contains { screen in
            let overlap = screen.intersection(frame)
            return !overlap.isNull
                && overlap.width >= min(minimumVisible, frame.width)
                && overlap.height >= min(minimumVisible, frame.height)
        }
    }
}

/// `layout.json` — 창 위치·크기의 정본.
///
/// 메모 파일에 넣지 않는 이유는 설계문서 §5.1 에 있다. 창을 드래그할 때마다
/// 정본 마크다운이 갱신되면 동기화 충돌과 무의미한 diff 가 생기고, LLM 이
/// 파일을 다시 쓰면서 좌표를 날릴 수 있다. UI 상태는 기계 영역에 격리한다.
@MainActor
public final class LayoutStore {
    private var layouts: [String: WindowLayout]
    private let location: URL
    private var pendingSave: Task<Void, Never>?

    /// 드래그 중에는 초당 수십 번 좌표가 바뀐다. 그때마다 디스크에 쓰지 않는다.
    private let debounce: Duration = .milliseconds(500)

    public init(location: URL) {
        self.location = location
        self.layouts = Self.read(from: location)
    }

    public func layout(for id: ULID) -> WindowLayout? {
        layout(forKey: id.stringValue)
    }

    public func set(_ layout: WindowLayout, for id: ULID) {
        set(layout, forKey: id.stringValue)
    }

    /// 메모가 아닌 창(캘린더 등)도 같은 파일에 좌표를 둔다.
    /// 키가 ULID 형식이 아니면 `prune` 이 건드리지 않는다.
    public func layout(forKey key: String) -> WindowLayout? {
        layouts[key]
    }

    public func set(_ layout: WindowLayout, forKey key: String) {
        layouts[key] = layout
        scheduleSave()
    }

    public func setHidden(_ hidden: Bool, for id: ULID) {
        guard var layout = layouts[id.stringValue] else { return }
        layout.hidden = hidden
        layouts[id.stringValue] = layout
        scheduleSave()
    }

    public func remove(_ id: ULID) {
        layouts.removeValue(forKey: id.stringValue)
        scheduleSave()
    }

    /// 인덱스와 마찬가지로 파생물이다 — 사라진 메모의 좌표는 남겨둘 이유가 없다.
    public func prune(keeping ids: Set<ULID>) {
        let alive = Set(ids.map(\.stringValue))
        let before = layouts.count
        // ULID 가 아닌 키(캘린더 창 등)는 메모 목록과 무관하므로 남긴다.
        layouts = layouts.filter { ULID($0.key) == nil || alive.contains($0.key) }
        if layouts.count != before { scheduleSave() }
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [debounce] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            self.flush()
        }
    }

    /// 종료 직전처럼 기다릴 수 없을 때 즉시 쓴다.
    public func flush() {
        pendingSave?.cancel()
        pendingSave = nil

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try FileManager.default.createDirectory(
                at: location.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try encoder.encode(layouts).write(to: location, options: .atomic)
        } catch {
            // 좌표를 잃는 것은 메모를 잃는 것이 아니다. 기동을 막지 않는다.
        }
    }

    private static func read(from location: URL) -> [String: WindowLayout] {
        guard let data = try? Data(contentsOf: location),
              let decoded = try? JSONDecoder().decode([String: WindowLayout].self, from: data)
        else { return [:] }
        return decoded
    }
}
