import Foundation
import Testing
@testable import LazyMemoCore

/// 폰의 글 칸이 감추는 구간과 커서 규칙 (`MachineLines`).
@Suite("MachineLines — 사진 참조와 가는 길 절은 카드가 대신 선다")
struct MachineLinesTests {
    private let route = """
        ## 가는 길
        석촌고분역 → 투파인드피터 잠실점 · 21분 · 18:09 출발 · 18:30 도착 · 1,500원
        - 걷기 2분
        - 버스 3314 (지선) 잠실여고후문 → 잠실역.롯데월드 · 8분 · 4정류장
        """

    private func text(_ body: String, _ hidden: MachineLines.Hidden) -> String {
        (body as NSString).substring(with: hidden.range)
    }

    @Test("줄을 혼자 차지한 사진 참조는 줄바꿈까지, 글 사이의 참조는 참조만")
    func photoLines() {
        let body = "메모\n![](attachments/a.png)\n더 적음\n영수증 ![](attachments/r.png) 3월분"
        let hidden = MachineLines.hidden(in: body)
        #expect(hidden.map(\.kind) == [.photo, .photo])
        #expect(text(body, hidden[0]) == "![](attachments/a.png)\n")
        #expect(text(body, hidden[1]) == "![](attachments/r.png)")
    }

    @Test("글 끝의 사진 참조는 참조만 — 뒤에 줄바꿈이 없다")
    func photoAtTheEnd() {
        let body = "메모\n![](attachments/a.png)"
        let hidden = MachineLines.hidden(in: body)
        #expect(hidden.count == 1)
        #expect(text(body, hidden[0]) == "![](attachments/a.png)")
    }

    @Test("가는 길 절은 통째로 — 앞의 빈 줄은 두고 뒤의 빈 줄은 함께")
    func routeSection() {
        let body = "점심 약속\n\n" + route + "\n\n"
        let hidden = MachineLines.hidden(in: body)
        #expect(hidden.map(\.kind) == [.route])
        #expect(text(body, hidden[0]) == route + "\n\n")
        #expect(hidden[0].range.location == ("점심 약속\n\n" as NSString).length)
    }

    @Test("커서 — 사진 참조 안이면 뒤로, 절 안·머리·끝이면 절 위의 빈 줄로")
    func caret() {
        let body = "메모\n![](attachments/a.png)\n\n" + route
        let hidden = MachineLines.hidden(in: body)
        let photo = hidden[0], section = hidden[1]
        let photoEnd = photo.range.location + photo.range.length
        // 참조 한가운데 → 참조 뒤(다음 줄 머리). 참조 앞과 뒤는 그대로.
        #expect(MachineLines.caret(photo.range.location + 3, avoiding: hidden, in: body) == photoEnd)
        #expect(MachineLines.caret(photo.range.location, avoiding: hidden, in: body) == photo.range.location)
        #expect(MachineLines.caret(photoEnd, avoiding: hidden, in: body) == photoEnd)
        // 절의 머리(「##」 앞)·한가운데·끝(글 끝) → 절 바로 위 빈 줄 (절 앞 줄바꿈의 앞).
        let blank = section.range.location - 1
        #expect(MachineLines.caret(section.range.location, avoiding: hidden, in: body) == blank)
        #expect(MachineLines.caret(section.range.location + 10, avoiding: hidden, in: body) == blank)
        #expect(MachineLines.caret((body as NSString).length, avoiding: hidden, in: body) == blank)
        // 그 빈 줄 자체는 밖이다 — 거기서 친 글자는 절을 깨지 않는다.
        #expect(MachineLines.caret(blank, avoiding: hidden, in: body) == blank)
        // 본문 첫 줄은 상관없다.
        #expect(MachineLines.caret(1, avoiding: hidden, in: body) == 1)
    }

    @Test("절이 본문의 전부면 커서는 0 으로 — 더 앞이 없다")
    func routeOnly() {
        let hidden = MachineLines.hidden(in: route)
        #expect(MachineLines.caret(5, avoiding: hidden, in: route) == 0)
    }

    /// 맥에서 붙인 주소는 `[map.naver.com/…](https://…)` — 폰에서는 이름만 보여야 한다 (2026-09-17 사용자: 「이것도 당연히 감춰야지」).
    @Test("링크는 기호만 감추고 이름은 남는다 — 맨 주소와 다른 기호(#·**)는 건드리지 않는다")
    func linkSyntax() {
        let body = "# 약속\n[map.naver.com/2040338336](https://map.naver.com/p/entry/place/2040338336?lng=127.1) 점심 **꼭**\nhttps://naver.me/x 도"
        let hidden = MachineLines.hidden(in: body)
        #expect(hidden.map(\.kind) == [.linkSyntax, .linkSyntax])
        #expect(text(body, hidden[0]) == "[")
        #expect(text(body, hidden[1]) == "](https://map.naver.com/p/entry/place/2040338336?lng=127.1)")
        // 기호 안의 커서는 뒤로, 이름 끝(기호 앞)은 그대로 — 거기서 치면 이름에 붙는다.
        let close = hidden[1]
        #expect(MachineLines.caret(close.range.location + 5, avoiding: hidden, in: body) == close.range.location + close.range.length)
        #expect(MachineLines.caret(close.range.location, avoiding: hidden, in: body) == close.range.location)
    }

    @Test("사진 떼기 — 그 참조의 줄만 빠지고 나머지 글은 그대로")
    func removingPhoto() {
        let body = "명함\n![](attachments/a.png)\n![](attachments/b.png)\n연락처 물어보기"
        #expect(MachineLines.removingPhoto("attachments/a.png", from: body) == "명함\n![](attachments/b.png)\n연락처 물어보기")
        #expect(MachineLines.removingPhoto("attachments/b.png", from: body) == "명함\n![](attachments/a.png)\n연락처 물어보기")
        // 글 끝의 사진은 줄바꿈까지 거둔다 — 끝에 빈 줄이 남으면 종이가 늘어져 보인다.
        #expect(MachineLines.removingPhoto("attachments/a.png", from: "명함\n![](attachments/a.png)") == "명함")
        // 글 사이의 참조는 참조만.
        #expect(MachineLines.removingPhoto("attachments/r.png", from: "영수증 ![](attachments/r.png) 3월분") == "영수증  3월분")
        #expect(MachineLines.removingPhoto("attachments/x.png", from: body) == body)
    }

    @Test("아무것도 없으면 아무것도 감추지 않는다")
    func plain() {
        #expect(MachineLines.hidden(in: "우유 사기\n- [ ] 계란").isEmpty)
        #expect(MachineLines.caret(3, avoiding: [], in: "우유 사기") == 3)
    }
}
