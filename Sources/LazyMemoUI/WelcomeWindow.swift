import AppKit
import LazyMemoCore
import SwiftUI

/// 첫 실행과 메뉴의 사용 안내가 같은 화면을 공유한다.
@MainActor
final class WelcomeWindow {
    private var window: NSWindow?

    func show(shortcut: String, onCapture: @escaping () -> Void,
              onCalendar: @escaping () -> Void, onDrawer: @escaping () -> Void) {
        if let window, window.isVisible { window.makeKeyAndOrderFront(nil); NSApp.activate(); return }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 610),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.title = L("lazymemo 시작하기")
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: WelcomeView(
            shortcut: shortcut,
            onCapture: { [weak window] in window?.close(); onCapture() },
            onCalendar: { [weak window] in window?.close(); onCalendar() },
            onDrawer: { [weak window] in window?.close(); onDrawer() }
        ))
        window.center()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}

struct WelcomeView: View {
    var shortcut: String = "⌥⌘N"
    var onCapture: () -> Void = {}
    var onCalendar: () -> Void = {}
    var onDrawer: () -> Void = {}
    @Environment(\.rendersStatically) private var rendersStatically
    @State private var step = 0
    @State private var draft = ""
    @State private var saved = false
    @State private var scheduled = L("내일 오후 3시 치과")
    @State private var tucked = false

    init(shortcut: String = "⌥⌘N", onCapture: @escaping () -> Void = {},
         onCalendar: @escaping () -> Void = {}, onDrawer: @escaping () -> Void = {},
         initialStep: Int = 0) {
        self.shortcut = shortcut
        self.onCapture = onCapture
        self.onCalendar = onCalendar
        self.onDrawer = onDrawer
        _step = State(initialValue: min(max(initialStep, 0), 3))
    }

    private let titles = [L("떠오른 생각, 한 줄이면 돼요."), L("날짜도 말하듯 적어 보세요."), L("잠깐 치워도, 사라지지 않아요."), L("이제, 가볍게 시작하세요.")]
    private let details = [L("어느 앱에서든 단축키로 빠른 입력을 열 수 있어요."), L("메모 속 날짜를 알아보고 달력에 함께 보여 줍니다."), L("지금 필요 없는 메모는 서랍에 넣고 다시 꺼내세요."), L("메뉴바의 작은 아이콘이 언제나 메모로 돌아오는 길이에요.")]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                MemoBrandMark()
                Text("lazymemo").font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(L("처음 만나는 lazymemo")).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                ForEach(0..<4) { index in
                    Capsule().fill(index <= step ? Theme.accentInk : Theme.softAccent).frame(height: 3)
                }
            }.padding(.top, 25).accessibilityLabel(L("튜토리얼 \(step + 1) / 4 단계"))
            Text([L("01 · 바로 적기"), L("02 · 날짜에 맡기기"), L("03 · 서랍 사용하기"), L("04 · 준비 완료")][step])
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.accentInk).padding(.top, 24)
            Text(titles[step]).font(.system(size: 28, weight: .semibold)).tracking(-1).padding(.top, 10)
            Text(details[step]).font(.system(size: 13)).foregroundStyle(.secondary).padding(.top, 10)
            practice.padding(.top, 25)
            Spacer(minLength: 16)
            HStack {
                if step > 0 { Button(L("이전")) { step -= 1 }.buttonStyle(.plain).padding(.trailing, 16) }
                Button(step == 3 ? L("달력 열기") : L("건너뛰고 메모 적기"), action: step == 3 ? onCalendar : onCapture)
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Button(action: { if step == 3 { onCapture() } else { step += 1 } }) {
                    HStack(spacing: 14) {
                        Text(step == 3 ? L("첫 메모 적기") : L("다음"))
                        Image(systemName: "arrow.right")
                    }.font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 20).frame(height: 42)
                        .foregroundStyle(Theme.onAccent)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }.font(.system(size: 12))
            Text(L("다시 보려면 메뉴바 아이콘 오른쪽 클릭 → 시작하기 및 사용 안내"))
                .font(.system(size: 10)).foregroundStyle(.secondary).padding(.top, 20)
        }
        .padding(36).padding(.top, 18)
        .frame(width: 660, height: 610)
        .background(Theme.paper(MemoColor.gray.ink, radius: 0, dotted: false))
    }

    private func practiceField(_ placeholder: String, text: Binding<String>) -> some View {
        Group {
            if rendersStatically {
                Text(text.wrappedValue.isEmpty ? placeholder : text.wrappedValue)
                    .foregroundStyle(text.wrappedValue.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField(placeholder, text: text).textFieldStyle(.plain)
                    .accessibilityLabel(placeholder)
            }
        }
        .font(.system(size: 17)).padding(14)
        .background(Theme.softAccent, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder private var practice: some View {
        VStack(alignment: .leading, spacing: 16) {
            if step == 0 {
                HStack {
                    Label(L("빠른 입력 연습"), systemImage: "square.and.pencil")
                    Spacer()
                    Text(shortcut).monospaced().foregroundStyle(Theme.accentInk)
                }
                practiceField(L("지금 떠오르는 생각을 적어 보세요"), text: $draft)
                    .onChange(of: draft) { saved = false }
                HStack {
                    Text(saved ? L("잘했어요! 실제 입력창에서는 메모 한 장이 생겨요.") : L("빠른 입력은 ⌘↵ 또는 버튼으로 확정해요."))
                    Spacer()
                    Button(saved ? L("연습 완료 ✓") : L("남기기")) { saved = true }
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .keyboardShortcut(.return, modifiers: .command)
                }
                Text(L("바탕화면의 메모를 고칠 때는 자동으로 저장돼요.")).foregroundStyle(.secondary)
            } else if step == 1 {
                Label(L("날짜 인식 연습"), systemImage: "calendar")
                practiceField(L("예: 내일 오후 3시 치과"), text: $scheduled)
                if let result = NaturalDateParser.parse(scheduled) {
                    Label(L("인식한 표현: \(result.phrases.joined(separator: " · "))"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.accentInk)
                } else {
                    Text(L("날짜가 없는 글은 일반 메모로 남아요.")).foregroundStyle(.secondary)
                }
                Text(L("문장을 바꿔 보세요. 실제 메모에 날짜가 붙으면 달력에서도 만날 수 있어요."))
                    .foregroundStyle(.secondary)
            } else if step == 2 {
                HStack {
                    Label(tucked ? L("서랍 속 메모") : L("바탕화면의 메모"), systemImage: tucked ? "tray.full" : "note.text")
                    Spacer()
                    Text(tucked ? L("보관 중") : L("꺼내 놓음")).foregroundStyle(Theme.accentInk)
                }
                HStack {
                    Text(L("언젠가 가 보고 싶은 곳")).font(.system(size: 17))
                    Spacer()
                    Button(tucked ? L("다시 꺼내기") : L("서랍에 넣어 보기")) { tucked.toggle() }
                }.padding(18).background(Theme.softAccent, in: RoundedRectangle(cornerRadius: 12))
                Text(L("실제 메모의 ×를 누르면 서랍으로 들어가요.\n메뉴바를 오른쪽 클릭해 서랍을 열고 다시 꺼내세요."))
                    .foregroundStyle(.secondary).lineSpacing(5)
            } else {
                Label(L("메뉴바 아이콘 클릭 → 빠른 입력"), systemImage: "cursorarrow.click")
                Label(L("오른쪽 클릭 → 달력 · 서랍 · 설정"), systemImage: "menubar.arrow.up.rectangle")
                Label(L("\(shortcut) → 어디서든 한 줄 적기"), systemImage: "keyboard")
                Divider()
                Text(L("메모는 내 Mac에 저장돼요. 가입 없이 바로 시작하세요.")).foregroundStyle(.secondary)
            }
            if step < 3 {
                Text(L("연습 공간 · 여기에 적은 내용은 저장되지 않아요"))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(Theme.paper(MemoColor.yellow.ink))
        .overlay(Theme.edge())
    }
}
