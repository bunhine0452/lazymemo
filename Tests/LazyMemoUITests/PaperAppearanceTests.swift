import Foundation
import LazyMemoCore
import Testing
@testable import LazyMemoUI

/// 종이 투명도는 설정 파일에 남는 값이고, 그 파일은 사용자가 직접 열어
/// 고칠 수 있다 (§5.1). 0 이 적혀 있다고 메모가 통째로 사라지면 안 된다.
@MainActor
@Suite("PaperAppearance")
struct PaperAppearanceTests {
    private func store() -> SettingsStore {
        let location = FileManager.default.temporaryDirectory
            .appending(path: "lazymemo-test-\(UUID().uuidString).json", directoryHint: .notDirectory)
        return SettingsStore(location: location)
    }

    @Test("손대지 않으면 불투명한 종이다")
    func defaultsToOpaquePaper() {
        #expect(PaperAppearance(settings: store()).opacity == PaperAppearance.standard)
        #expect(PaperAppearance.standard == 1.0)
    }

    @Test("고른 값이 파일에 남고 다음에 그대로 돌아온다")
    func persistsChoice() {
        let settings = store()
        PaperAppearance(settings: settings).set(0.68)

        #expect(settings.current.paperOpacity == 0.68)
        #expect(PaperAppearance(settings: settings).opacity == 0.68)
    }

    @Test("바닥 아래로는 내려가지 않는다 — 더 내리면 종이가 아니라 얼룩이다")
    func clampsToFloor() {
        #expect(PaperAppearance.clamped(0) == PaperAppearance.floor)
        #expect(PaperAppearance.clamped(-3) == PaperAppearance.floor)
        #expect(PaperAppearance.clamped(2) == 1.0)
        #expect(PaperAppearance.clamped(.nan) == PaperAppearance.standard)
        #expect(PaperAppearance.clamped(nil) == PaperAppearance.standard)
    }

    @Test("메뉴에 체크를 달 수 있게 지금 고른 단계를 안다")
    func reportsSelectedStep() {
        let appearance = PaperAppearance(settings: store())
        #expect(appearance.selected?.label == "선명하게")

        appearance.set(0.5)
        #expect(appearance.selected?.label == "많이 비치게")
    }

    @Test("단계는 전부 바닥과 천장 사이에 있다")
    func stepsStayInRange() {
        for step in PaperAppearance.steps {
            #expect(step.opacity >= PaperAppearance.floor)
            #expect(step.opacity <= 1.0)
        }
    }
}
