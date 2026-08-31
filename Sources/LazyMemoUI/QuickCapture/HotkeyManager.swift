import AppKit
import Carbon.HIToolbox

/// 전역 단축키 등록 (설계문서 §8).
///
/// Carbon `RegisterEventHotKey` 를 쓰는 이유는 **권한이 필요 없기 때문**이다.
/// `CGEventTap` 은 손쉬운 사용 권한을 요구하는데, 메모 앱이 첫 실행에서
/// 시스템 설정으로 사용자를 보내면 "게으름 타파"라는 전제가 무너진다.
@MainActor
final class HotkeyManager {
    /// 지금 걸려 있는 조합. 메뉴 표기와 안내 문구가 이것을 읽는다.
    private(set) var current: Hotkey = .standard

    private static let signature = OSType(0x4C5A4D4F)   // 'LZMO'
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var eventHandler: EventHandlerRef?

    private var registeredRefs: [UInt32: EventHotKeyRef] = [:]

    /// - Returns: 등록에 성공했으면 `true`. 다른 앱이 같은 조합을 이미 쓰고 있으면 실패한다.
    @discardableResult
    func register(id: UInt32 = 1, _ hotkey: Hotkey = .standard, action: @escaping () -> Void) -> Bool {
        guard hotkey.isUsable else { return false }
        unregister(id: id)
        Self.installEventHandlerIfNeeded()

        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            EventHotKeyID(signature: Self.signature, id: id),
            GetEventDispatcherTarget(),
            0,
            &reference
        )

        guard status == noErr, let reference else { return false }

        Self.handlers[id] = action
        self.registeredRefs[id] = reference
        if id == 1 {
            self.current = hotkey
        }
        return true
    }

    func unregister(id: UInt32 = 1) {
        if let ref = registeredRefs.removeValue(forKey: id) {
            UnregisterEventHotKey(ref)
        }
        Self.handlers.removeValue(forKey: id)
    }

    func unregisterAll() {
        for (_, ref) in registeredRefs {
            UnregisterEventHotKey(ref)
        }
        registeredRefs.removeAll()
        Self.handlers.removeAll()
    }

    /// Carbon 핸들러는 프로세스에 하나면 된다. 눌린 hotkey id 로 갈라 준다.
    private static func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, _ -> OSStatus in
                var pressed = EventHotKeyID()
                let status = GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &pressed
                )
                guard status == noErr else { return status }

                // Carbon 이벤트는 메인 런루프에서 도착한다.
                MainActor.assumeIsolated {
                    CaptureTrace.log("단축키 이벤트 도착 id=\(pressed.id) 핸들러=\(HotkeyManager.handlers[pressed.id] != nil)")
                    HotkeyManager.handlers[pressed.id]?()
                }
                return noErr
            },
            1, &spec, nil, &eventHandler
        )
    }

}
