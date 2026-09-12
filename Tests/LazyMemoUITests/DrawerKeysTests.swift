import AppKit
import Testing
@testable import LazyMemoUI

/// 서랍의 **키보드 문법** — 키가 어디로 가는지는 화면에 안 보인다 (§14.9).
///
/// ↑를 눌렀을 때 무더기가 한 장 올라가는지, 아니면 그 키가 찾기 상자로
/// 흘러가 아무 일도 안 일어나는지는 렌더에도 캡처에도 남지 않는다.
@Suite("서랍의 키보드 문법")
struct DrawerKeysTests {

    private func intent(
        _ characters: String,
        _ modifiers: NSEvent.ModifierFlags = [],
        editing: Bool = false
    ) -> DrawerKeys.Intent? {
        DrawerKeys.intent(characters: characters, modifiers: modifiers, isEditing: editing)
    }

    @Test("화살표로 무더기를 훑는다")
    func arrowsWalkThePile() {
        #expect(intent("\u{F700}") == .move(-1))
        #expect(intent("\u{F701}") == .move(1))
    }

    @Test("↩ 는 펼치고, ⌘↩ 는 꺼내고, ⌘⌫ 는 지운다")
    func returnAndCommandCombos() {
        #expect(intent("\r") == .zoom)
        #expect(intent("\r", .command) == .takeOut)
        #expect(intent("\u{7F}", .command) == .delete)
        #expect(intent("\u{8}", .command) == .delete)
    }

    @Test("⌘F 는 찾기로 간다")
    func commandFOpensSearch() {
        #expect(intent("f", .command) == .search)
        #expect(intent("F", .command) == .search)
    }

    @Test("esc 는 한 겹 되돌린다")
    func escapeGoesBackOneLayer() {
        #expect(intent("\u{1B}") == .back)
    }

    // MARK: 글자는 건드리지 않는다

    /// 한글은 조합 입력이라, 날 키 이벤트를 모아 글자를 만들면 「장」을 치는데
    /// 「wkd」가 쌓인다. 찾기는 진짜 글 상자가 맡고 여기서는 손대지 않는다.
    @Test("찾는 중에는 글자 키를 맡지 않는다 — 한글이 깨진다")
    func lettersBelongToTheTextFieldWhileEditing() {
        #expect(intent(" ", editing: true) == nil)
        #expect(intent("+", editing: true) == nil)
        #expect(intent("a", editing: true) == nil)
    }

    @Test("찾는 중이 아니면 스페이스로 고르고 + 로 더 펼친다")
    func lettersActWhenNotEditing() {
        #expect(intent(" ") == .pick)
        #expect(intent("+") == .revealMore)
        #expect(intent("=") == .revealMore)
    }

    /// 찾는 중에도 화살표와 esc 는 서랍 몫이다 — 한 줄짜리 상자에서 ↑↓ 는
    /// 하는 일이 없고, 그 키로 무더기를 훑을 수 있어야 «찾고 고른다» 가 한
    /// 손에서 끝난다.
    @Test("찾는 중에도 화살표·esc·↩ 는 서랍이 맡는다")
    func navigationSurvivesEditing() {
        #expect(intent("\u{F700}", editing: true) == .move(-1))
        #expect(intent("\u{1B}", editing: true) == .back)
        #expect(intent("\r", editing: true) == .zoom)
        #expect(intent("\r", .command, editing: true) == .takeOut)
    }

    @Test("⌥·⌃ 조합은 시스템과 입력기 몫이다")
    func leavesOptionAndControlAlone() {
        #expect(intent("\u{F700}", .option) == nil)
        #expect(intent("f", [.command, .control]) == nil)
    }

    @Test("모르는 키는 흘려보낸다")
    func unknownKeysPassThrough() {
        #expect(intent("q") == nil)
        #expect(intent("q", .command) == nil)
    }
}
