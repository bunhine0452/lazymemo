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

    /// 맥에서 붙여 넣은 지도 주소는 `[map.naver.com/…](https://map.naver.com/p/entry/place/…?lng=…)` 로 40자가 넘는다 —
    /// 그것이 제목이 되면 목록·달력·창 제목이 전부 주소로 찬다 (2026-09-17 사용자의 폰 화면).
    @Test("링크는 이름만 남고, 자리 짐작에는 링크가 아예 빠진다")
    func linksKeepOnlyTheirLabel() {
        let memo = Memo(body: "[map.naver.com/2040338336](https://map.naver.com/p/entry/place/2040338336?lng=127.1&lat=37.5) 점심")
        #expect(memo.title == "map.naver.com/2040338336 점심")
        #expect(memo.titleWithoutLinks == "점심")
        #expect(Memo(body: "https://naver.me/GFB1MHiW 밥약속").title == "https://naver.me/GFB1MHiW 밥약속")
        #expect(Memo(body: "https://naver.me/GFB1MHiW 밥약속").titleWithoutLinks == "밥약속")
        // 링크뿐인 줄은 자리 짐작에서 건너뛴다 — 다음 글줄이 있으면 그것, 없으면 빈 것.
        #expect(Memo(body: "[지도](https://naver.me/x)\n점심 약속").titleWithoutLinks == "점심 약속")
        #expect(Memo(body: "https://naver.me/x").titleWithoutLinks == "")
    }

    @Test("가는 길 절은 글이 아니다 — 둘째 줄에 「가는 길」이 서지 않는다")
    func routeSectionIsNotText() {
        let memo = Memo(body: "점심 약속\n\n## 가는 길\n삼전동 66-4 → 마루가메 우동 · 22분 · 13:34 출발 · 13:56 도착\n- 걷기 3분")
        #expect(memo.title == "점심 약속")
        #expect(memo.previewLine == nil)
    }

    @Test("아무것도 없으면 여전히 「빈 메모」")
    func empty() {
        #expect(Memo(body: "  \n").title == "빈 메모")
        #expect(Memo(body: "  \n").photoCount == 0)
    }
}
