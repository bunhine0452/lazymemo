import Foundation
import Testing
@testable import LazyMemoCore

@Suite("MemoFilter — 낱말이 기억나지 않을 때")
struct MemoFilterTests {
    private var now: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: 10))!
    }

    private func read(_ query: String) -> MemoFilter {
        MemoFilter.read(query, now: now)
    }

    @Test("생김새를 읽는다 — 「그 사진 붙여 둔 거」")
    func readsShapes() {
        #expect(read("#사진").shapes == [.photo])
        #expect(read("#링크").shapes == [.link])
        #expect(read("#체크").shapes == [.checklist])
    }

    @Test("생김새가 아닌 # 는 태그다 — 이 앱이 이미 쓰는 기호 그대로")
    func readsTags() {
        let filter = read("#병원")
        #expect(filter.tags == ["병원"])
        #expect(filter.shapes.isEmpty)
    }

    @Test("장소와 날짜도 같은 상자에서 읽힌다")
    func readsPlaceAndDay() {
        #expect(read("@강남").place == "강남")
        #expect(read("어제").day == CalendarDate(year: 2026, month: 8, day: 27))
    }

    @Test("조건을 걷어낸 나머지가 검색어다")
    func leavesWords() {
        let filter = read("#사진 영수증")
        #expect(filter.shapes == [.photo])
        #expect(filter.words == "영수증")
    }

    @Test("조건만 있으면 검색어는 없다 — 낱말 없이도 찾을 수 있어야 한다")
    func filterOnlyHasNoWords() {
        #expect(read("#사진").words.isEmpty)
        #expect(read("@강남").words.isEmpty)
        #expect(read("#사진").narrows)
    }

    @Test("아무 조건도 없으면 예전과 똑같다")
    func plainQueryUnchanged() {
        let filter = read("영수증")
        #expect(!filter.narrows)
        #expect(filter.words == "영수증")
    }

    @Test("`foo#bar` 는 조건이 아니다")
    func ignoresInlineSigils() {
        #expect(read("a#b").tags.isEmpty)
        #expect(read("메일 foo@bar.com").place == nil)
    }

    @Test("걸러 본다 — 생김새")
    func matchesShapes() {
        let photo = Memo(body: "영수증\n![](x.png)")
        let plain = Memo(body: "영수증")
        #expect(read("#사진").matches(photo))
        #expect(!read("#사진").matches(plain))

        let list = Memo(body: "- [ ] 우유")
        #expect(read("#체크").matches(list))
        #expect(!read("#체크").matches(photo))

        let link = Memo(body: "[여기](https://example.com)")
        #expect(read("#링크").matches(link))
        #expect(!read("#링크").matches(plain))
    }

    @Test("걸러 본다 — 태그·장소")
    func matchesTagsAndPlace() {
        let memo = Memo(place: "강남역 3번 출구", tags: ["병원"], body: "치과")
        #expect(read("#병원").matches(memo))
        #expect(read("@강남").matches(memo))
        #expect(!read("#은행").matches(memo))
        #expect(!read("@광화문").matches(memo))
    }

    @Test("날짜는 적힌 날이든 손댄 날이든 걸린다 — 어느 쪽인지 묻지 않는다")
    func matchesEitherScheduledOrTouched() {
        let yesterday = CalendarDate(year: 2026, month: 8, day: 27)
        let calendar = Calendar.current

        let scheduled = Memo(due: yesterday, body: "일정")
        let touched = Memo(updated: yesterday.startOfDay(calendar: calendar)!, body: "적어 둔 것")
        let neither = Memo(due: CalendarDate(year: 2026, month: 8, day: 20), body: "옛것")

        #expect(read("어제").matches(scheduled))
        #expect(read("어제").matches(touched))
        #expect(!read("어제").matches(neither))
    }

    @Test("여러 조건은 전부 만족해야 한다")
    func combinesConditions() {
        let memo = Memo(place: "강남역", tags: ["병원"], body: "영수증\n![](x.png)")
        #expect(read("#사진 #병원 @강남").matches(memo))
        #expect(!read("#사진 #은행 @강남").matches(memo))
    }

    @Test("사람에게 무엇으로 걸렀는지 보여 준다 — 가려진 것은 가려진 줄도 모른다")
    func showsChips() {
        #expect(read("#사진 @강남 #병원").chips == ["#사진", "#병원", "@강남"])
        #expect(read("영수증").chips.isEmpty)
    }
}
