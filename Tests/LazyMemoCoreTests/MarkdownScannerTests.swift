import Foundation
import Testing
@testable import LazyMemoCore

@Suite("MarkdownScanner")
struct MarkdownScannerTests {
    private func kinds(_ text: String) -> [MarkdownScanner.Span.Kind] {
        MarkdownScanner.spans(in: text).map(\.kind)
    }

    private func span(_ text: String, where predicate: (MarkdownScanner.Span.Kind) -> Bool) -> MarkdownScanner.Span? {
        MarkdownScanner.spans(in: text).first { predicate($0.kind) }
    }

    @Test("표 — 세로선과 구분 줄은 마커, 머리 줄의 칸은 굵게")
    func stylesTables() {
        let text = "| 구분 | 금액 |\n| --- | --- |\n| 시급 | 10,320원 |"
        let spans = MarkdownScanner.spans(in: text)
        let ns = text as NSString
        // 머리 줄 세로선 셋, 본문 줄 세로선 셋, 구분 줄 하나 = 마커 일곱
        let syntax = spans.filter { $0.kind == .syntax }
        #expect(syntax.count == 7)
        #expect(syntax.contains { ns.substring(with: $0.range) == "| --- | --- |" })
        // 머리 줄의 칸 둘이 굵게 — 본문 줄은 아니다
        let strong = spans.filter { $0.kind == .strong }.map { ns.substring(with: $0.range).trimmingCharacters(in: .whitespaces) }
        #expect(strong == ["구분", "금액"])
        // 세로선으로 시작하지 않는 줄은 표가 아니다
        #expect(!MarkdownScanner.spans(in: "a | b").contains { $0.kind == .syntax })
    }

    @Test("제목의 단계를 읽는다")
    func readsHeadingLevels() {
        #expect(kinds("# 큰 제목").contains(.heading(level: 1)))
        #expect(kinds("### 작은 제목").contains(.heading(level: 3)))
        // 공백 없는 #은 제목이 아니다 — 해시태그일 수 있다.
        #expect(!kinds("#제목아님").contains { if case .heading = $0 { return true }; return false })
    }

    @Test("굵게와 기울임을 구분한다")
    func distinguishesStrongFromEmphasis() {
        #expect(kinds("**굵게** 보통").contains(.strong))
        #expect(kinds("*기울임* 보통").contains(.emphasis))
        // ** 가 * 보다 먼저 잡혀야 한다
        #expect(!kinds("**굵게**").contains(.emphasis))
    }

    @Test("코드 안의 별표는 강조가 아니다")
    func codeWinsOverEmphasis() {
        let result = kinds("`**별표**` 는 코드다")
        #expect(result.contains(.code))
        #expect(!result.contains(.strong))
    }

    @Test("목록과 체크박스를 구분한다")
    func distinguishesBulletFromCheckbox() {
        #expect(kinds("- 그냥 항목").contains(.bullet))
        #expect(kinds("- [ ] 안 한 일").contains(.checkbox(done: false)))
        #expect(kinds("- [x] 한 일").contains(.checkbox(done: true)))
    }

    @Test("링크의 목적지를 읽는다")
    func readsLinkDestination() {
        let found = span("자세히는 [여기](https://example.com/a) 참고") {
            if case .link = $0 { return true }; return false
        }
        #expect(found?.kind == .link(destination: "https://example.com/a"))
    }

    @Test("맨몸 URL 도 링크로 본다")
    func readsBareURL() {
        #expect(kinds("https://example.com 확인").contains(.link(destination: "https://example.com")))
    }

    @Test("이미지가 링크보다 먼저 잡힌다")
    func imageWinsOverLink() {
        let result = kinds("![](attachments/a.png)")
        #expect(result.contains(.image(path: "attachments/a.png")))
        #expect(!result.contains { if case .link = $0 { return true }; return false })
    }

    @Test("이미지 경로를 순서대로 모은다")
    func collectsImagePaths() {
        let text = "첫 장\n![](attachments/a.png)\n둘째 장\n![설명](attachments/b.jpg)"
        #expect(MarkdownScanner.imagePaths(in: text) == ["attachments/a.png", "attachments/b.jpg"])
    }

    @Test("구간이 원문 범위를 벗어나지 않는다")
    func spansStayInBounds() {
        let text = "# 제목\n- [x] 한 일 **굵게**\n> 인용 `코드`\nhttps://example.com"
        let length = (text as NSString).length
        for span in MarkdownScanner.spans(in: text) {
            #expect(span.range.location >= 0)
            #expect(span.range.location + span.range.length <= length)
        }
    }

    @Test("한글이 섞여도 구간이 어긋나지 않는다")
    func handlesKoreanOffsets() throws {
        let text = "치과 예약 **강남역** 3번 출구"
        let strong = try #require(span(text) { $0 == .strong })
        #expect((text as NSString).substring(with: strong.range) == "**강남역**")
    }

    @Test("빈 글에는 아무 구간도 없다")
    func emptyTextHasNoSpans() {
        #expect(MarkdownScanner.spans(in: "").isEmpty)
        #expect(MarkdownScanner.spans(in: "그냥 평범한 문장").isEmpty)
    }
}

@Suite("AttachmentStore")
struct AttachmentStoreTests {
    private func makeStore() throws -> (AttachmentStore, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-attach-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        return (AttachmentStore(paths: paths), paths)
    }

    @Test("저장하면 Vault 안의 상대 경로를 돌려준다")
    func savesInsideVault() throws {
        let (store, paths) = try makeStore()
        defer { try? FileManager.default.removeItem(at: paths.vault.deletingLastPathComponent()) }

        let path = try store.save(Data("가짜 이미지".utf8), fileExtension: "png")

        #expect(path.hasPrefix("attachments/"))
        #expect(path.hasSuffix(".png"))
        let url = try #require(store.url(for: path))
        #expect(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
    }

    @Test("Vault 밖을 가리키는 경로는 열어 주지 않는다")
    func rejectsEscapingPaths() throws {
        let (store, paths) = try makeStore()
        defer { try? FileManager.default.removeItem(at: paths.vault.deletingLastPathComponent()) }

        #expect(store.url(for: "../../etc/passwd") == nil)
        #expect(store.url(for: "/etc/passwd") == nil)
        #expect(store.url(for: "attachments/a.png") != nil)
    }

    @Test("이상한 확장자는 거절한다")
    func rejectsOddExtensions() throws {
        let (store, paths) = try makeStore()
        defer { try? FileManager.default.removeItem(at: paths.vault.deletingLastPathComponent()) }

        #expect(throws: AttachmentStore.Failure.self) {
            try store.save(Data(), fileExtension: "")
        }
        #expect(throws: AttachmentStore.Failure.self) {
            try store.save(Data(), fileExtension: "verylongext")
        }
    }

    @Test("아무도 참조하지 않는 첨부를 찾아낸다")
    func findsOrphans() throws {
        let (store, paths) = try makeStore()
        defer { try? FileManager.default.removeItem(at: paths.vault.deletingLastPathComponent()) }

        let used = try store.save(Data("a".utf8), fileExtension: "png")
        _ = try store.save(Data("b".utf8), fileExtension: "png")

        let orphans = try store.orphans(referencedBy: ["본문 ![](\(used))"])
        #expect(orphans.count == 1)
        #expect(!orphans[0].lastPathComponent.hasPrefix(used.components(separatedBy: "/")[1]))
    }
}

@Suite("LinkLabel")
struct LinkLabelTests {
    private func label(_ raw: String) -> String {
        LinkLabel.short(for: URL(string: raw)!)
    }

    @Test("호스트만 있으면 호스트를 쓴다")
    func hostOnly() {
        #expect(label("https://example.com") == "example.com")
        #expect(label("https://www.example.com/") == "example.com")
    }

    @Test("마지막 경로 조각을 읽기 좋게 편다")
    func readableLastComponent() {
        #expect(label("https://example.com/blog/hello-world") == "example.com/hello world")
        #expect(label("https://github.com/lazymemo") == "github.com/lazymemo")
    }

    @Test("너무 긴 조각은 자른다")
    func truncatesLongComponents() {
        let long = label("https://example.com/" + String(repeating: "a", count: 80))
        #expect(long.count <= "example.com/".count + 41)
        #expect(long.hasSuffix("…"))
    }

    @Test("본문에 넣을 마크다운을 만든다")
    func buildsMarkdown() {
        #expect(
            LinkLabel.markdown(for: URL(string: "https://example.com/recipes")!)
                == "[example.com/recipes](https://example.com/recipes)"
        )
    }
}
