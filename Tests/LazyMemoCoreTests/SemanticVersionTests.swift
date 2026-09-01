import Foundation
import Testing
@testable import LazyMemoCore

@Suite("SemanticVersion")
struct SemanticVersionTests {
    @Test("판 번호를 읽는다 — 태그의 v 도 함께")
    func parses() {
        #expect(SemanticVersion("0.2.0") == SemanticVersion(major: 0, minor: 2, patch: 0))
        #expect(SemanticVersion("v1.4.2") == SemanticVersion(major: 1, minor: 4, patch: 2))
        #expect(SemanticVersion("2.1") == SemanticVersion(major: 2, minor: 1, patch: 0))
    }

    @Test("판이 아닌 것은 읽지 않는다")
    func rejectsJunk() {
        #expect(SemanticVersion("") == nil)
        #expect(SemanticVersion("0") == nil)
        #expect(SemanticVersion("0.2.0-beta") == nil)
        #expect(SemanticVersion("최신") == nil)
        #expect(SemanticVersion("0..1") == nil)
        #expect(SemanticVersion("1.2.3.4") == nil)
    }

    @Test("0.10.0 은 0.9.0 보다 뒤다 — 문자열로 견주면 틀리는 자리")
    func comparesNumerically() {
        #expect(SemanticVersion("0.9.0")! < SemanticVersion("0.10.0")!)
        #expect(SemanticVersion("0.9.9")! < SemanticVersion("0.10.0")!)
        #expect(SemanticVersion("1.0.0")! > SemanticVersion("0.99.99")!)
        #expect(SemanticVersion("0.2.0")! > SemanticVersion("0.1.9")!)
        #expect(!(SemanticVersion("0.1.0")! < SemanticVersion("0.1.0")!))
    }

    @Test("적은 그대로 되쓴다")
    func roundTrips() {
        #expect(SemanticVersion("v0.2.0")?.description == "0.2.0")
        #expect(SemanticVersion("2.1")?.description == "2.1.0")
    }

    @Test("지금 도는 판을 읽을 수 있다 — Version.swift 가 판이 아닌 글자면 여기서 걸린다")
    func currentVersionIsParseable() {
        #expect(SemanticVersion(LazyMemo.version) != nil)
        #expect(LazyMemo.semanticVersion == SemanticVersion(LazyMemo.version))
    }
}
