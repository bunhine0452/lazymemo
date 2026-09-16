import Foundation
import Testing
@testable import LazyMemoCore

@Suite("제목과 둘째 줄 — 사진 참조는 글이 아니다")
struct MemoTitleTests {
    @Test("사진만 붙인 메모의 제목은 경로가 아니라 「사진 1장」")
    func photoOnlyMemo() {
        let memo = Memo(body: "![](attachments/01K4.png)\n")
        #expect(memo.title == "사진 1장")
        #expect(memo.previewLine == nil)
        #expect(memo.photoCount == 1)
    }

    @Test("글 다음의 사진은 둘째 줄에서 건너뛴다")
    func photoAfterText() {
        let memo = Memo(body: "명함 — 김 디자이너\n![](attachments/a.png)\n연락처 물어보기")
        #expect(memo.title == "명함 — 김 디자이너")
        #expect(memo.previewLine == "연락처 물어보기")
    }

    @Test("같은 줄의 사진 참조도 걷어낸다")
    func inlinePhoto() {
        let memo = Memo(body: "영수증 ![](attachments/r.png) 3월분")
        #expect(memo.title == "영수증  3월분")
        #expect(memo.previewLine == nil)
    }

    @Test("영어는 한 장과 여러 장을 가른다 — 「1 photos」는 말이 아니다")
    func englishPluralPhotos() {
        let en = Locale(identifier: "en")
        #expect(L("사진 \(1)장", locale: en) == "1 photo")
        #expect(L("사진 \(3)장", locale: en) == "3 photos")
    }

    @Test("아무것도 없으면 여전히 「빈 메모」")
    func empty() {
        #expect(Memo(body: "  \n").title == "빈 메모")
        #expect(Memo(body: "  \n").photoCount == 0)
    }
}
