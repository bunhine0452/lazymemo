import AppKit

/// 표준 편집 단축키를 살리는 메인 메뉴.
///
/// **메뉴 막대에 보이지 않는 메뉴다.** 상주 앱(`.accessory`)은 메뉴 막대를
/// 차지하지 않지만, macOS 는 ⌘A·⌘Z·⌘C·⌘V 같은 표준 편집 단축키를 **메인
/// 메뉴를 통해서만** 응답 체인에 흘려보낸다. 메인 메뉴가 없으면 `NSTextView`
/// 안에서 그 키들이 전부 죽는다.
///
/// 사용자가 "커맨드+A 가 안 먹는다" 고 겪은 것이 이것이다. 글을 쓰는 앱에서
/// 전체 선택과 되돌리기가 안 되는 것은 다른 어떤 편안함으로도 못 갚는다.
enum StandardMenu {
    static func install() {
        let main = NSMenu()
        main.addItem(applicationMenu())
        main.addItem(editMenu())
        NSApp.mainMenu = main
    }

    /// 첫 메뉴는 관례상 앱 메뉴 자리다. ⌘Q 가 여기 걸린다.
    private static func applicationMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu()
        menu.addItem(
            withTitle: "lazymemo 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"
        )
        item.submenu = menu
        return item
    }

    private static func editMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "편집")

        add(to: menu, "되돌리기", Selector(("undo:")), "z")
        add(to: menu, "다시 실행", Selector(("redo:")), "Z")
        menu.addItem(.separator())
        add(to: menu, "잘라내기", #selector(NSText.cut(_:)), "x")
        add(to: menu, "복사", #selector(NSText.copy(_:)), "c")
        add(to: menu, "붙여넣기", #selector(NSText.paste(_:)), "v")
        // 서식 없이 붙여넣기 — 마크다운이 정본이므로(D4) 이쪽이 오히려 기본에 가깝다.
        let plain = add(to: menu, "서식 없이 붙여넣기", #selector(NSTextView.pasteAsPlainText(_:)), "V")
        plain.keyEquivalentModifierMask = [.command, .option, .shift]
        add(to: menu, "전체 선택", #selector(NSText.selectAll(_:)), "a")
        menu.addItem(.separator())
        add(to: menu, "찾기", Selector(("performFindPanelAction:")), "f")

        item.submenu = menu
        return item
    }

    /// 대상을 지정하지 않는다 — 응답 체인이 알아서 지금 글을 쓰고 있는 곳으로 보낸다.
    @discardableResult
    private static func add(
        to menu: NSMenu, _ title: String, _ action: Selector, _ key: String
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menu.addItem(item)
        return item
    }
}
