import Foundation
import Testing
@testable import LazyMemoCore

@Suite("MemoFile")
struct MemoFileTests {
    private let sample = """
        ---
        id: 01K3ZQ8F7N2R4M6X8B0V5T9WQY
        created: 2026-08-28T16:29:50+09:00
        updated: 2026-08-28T16:31:00+09:00
        due: 2026-09-01
        at: 2026-09-01T14:00:00+09:00
        tags: [약속, 병원]
        color: yellow
        pinned: false
        ---
        치과 예약 — 강남역 3번 출구
        """

    @Test("설계문서 §5.2 예시를 그대로 읽는다")
    func decodesDesignDocumentExample() throws {
        let memo = try MemoFile.decode(sample)

        #expect(memo.id.stringValue == "01K3ZQ8F7N2R4M6X8B0V5T9WQY")
        #expect(memo.due == CalendarDate(year: 2026, month: 9, day: 1))
        #expect(memo.tags == ["약속", "병원"])
        #expect(memo.color == .yellow)
        #expect(memo.pinned == false)
        #expect(memo.body == "치과 예약 — 강남역 3번 출구")
        #expect(memo.isScheduled)
    }

    @Test("왕복해도 내용이 변하지 않는다")
    func roundTripsWithoutLoss() throws {
        let decoded = try MemoFile.decode(sample)
        let encoded = MemoFile.encode(decoded, timeZone: TimeZone(identifier: "Asia/Seoul")!)
        let again = try MemoFile.decode(encoded)

        #expect(again.id == decoded.id)
        #expect(again.due == decoded.due)
        #expect(again.at == decoded.at)
        #expect(again.tags == decoded.tags)
        #expect(again.body == decoded.body)
        #expect(again.created == decoded.created)
    }

    @Test("따옴표가 든 값도 그대로 돌아온다 — 감쌀 때 넣은 역빗금이 남지 않는다")
    func roundTripsQuotedValues() throws {
        for place in ["\"봄\" 카페", "카페: \"봄\"", "@\"집\"", "역빗금 \\ 그대로", "a\\\"b", "'봄'", "\""] {
            let encoded = MemoFile.encode(Memo(place: place, body: "약속"))
            let once = try MemoFile.decode(encoded)
            #expect(once.place == place, "한 번: \(place)")
            // 두 번째 왕복에서도 같아야 한다 — 한 번은 맞고 두 번째부터 어긋나는 것이 이 버그의 꼴이었다.
            let twice = try MemoFile.decode(MemoFile.encode(once))
            #expect(twice.place == place, "두 번: \(place)")
        }
    }

    @Test("폴더 이름표는 파일에 적히고 그대로 돌아온다")
    func roundTripsFolder() throws {
        let memo = Memo(body: "우유", folder: " 장보기 ")
        #expect(memo.folder == "장보기")

        let encoded = MemoFile.encode(memo)
        #expect(encoded.contains("folder: 장보기"))
        #expect(try MemoFile.decode(encoded).folder == "장보기")

        // 이름표가 없으면 줄도 없다 — 파일에 빈 칸을 남기지 않는다.
        let plain = MemoFile.encode(Memo(body: "우유"))
        #expect(!plain.contains("folder:"))
        #expect(try MemoFile.decode(plain).folder == nil)
    }

    @Test("모르는 frontmatter 키를 지우지 않는다")
    func preservesUnknownKeys() throws {
        let text = """
            ---
            id: 01K3ZQ8F7N2R4M6X8B0V5T9WQY
            created: 2026-08-28T16:29:50+09:00
            mood: 초조함
            project: lazymemo
            ---
            본문
            """

        let memo = try MemoFile.decode(text)
        #expect(memo.preserved.map(\.key) == ["mood", "project"])

        let encoded = MemoFile.encode(memo)
        #expect(encoded.contains("mood: 초조함"))
        #expect(encoded.contains("project: lazymemo"))
    }

    @Test("날짜 필드가 없으면 캘린더에 나타나지 않는다")
    func plainMemoIsNotScheduled() throws {
        let text = """
            ---
            id: 01K3ZQ8F7N2R4M6X8B0V5T9WQY
            created: 2026-08-28T16:29:50+09:00
            ---
            그냥 메모
            """

        let memo = try MemoFile.decode(text)
        #expect(!memo.isScheduled)
        #expect(memo.scheduledDate() == nil)
    }

    @Test("frontmatter 가 없으면 거절한다")
    func rejectsMissingFrontmatter() {
        #expect(throws: MemoFile.DecodingError.missingFrontmatter) {
            try MemoFile.decode("그냥 본문만 있는 파일")
        }
    }

    @Test("id 가 깨져도 파일명으로 복구한다")
    func recoversIdentifierFromFileName() throws {
        let fallback = ULID()
        let memo = try MemoFile.decode("---\ncreated: 2026-08-28T16:29:50+09:00\n---\n본문", fallbackID: fallback)
        #expect(memo.id == fallback)
    }

    @Test("updated 가 없으면 created 를 쓴다 — 읽기만 해도 수정된 것처럼 보이면 안 된다")
    func missingUpdatedFallsBackToCreated() throws {
        let memo = try MemoFile.decode("""
            ---
            id: 01K3ZQ8F7N2R4M6X8B0V5T9WQY
            created: 2026-08-28T16:29:50+09:00
            ---
            본문
            """)
        #expect(memo.updated == memo.created)
    }

    @Test("블록 형식 tags 도 읽는다")
    func readsBlockStyleTags() throws {
        let memo = try MemoFile.decode("""
            ---
            id: 01K3ZQ8F7N2R4M6X8B0V5T9WQY
            created: 2026-08-28T16:29:50+09:00
            tags:
              - 약속
              - 병원
            ---
            본문
            """)
        #expect(memo.tags == ["약속", "병원"])
    }

    @Test("본문에 --- 가 있어도 첫 fence 만 frontmatter 로 본다")
    func bodyMayContainHorizontalRules() throws {
        let memo = try MemoFile.decode("""
            ---
            id: 01K3ZQ8F7N2R4M6X8B0V5T9WQY
            created: 2026-08-28T16:29:50+09:00
            ---
            위

            ---

            아래
            """)
        #expect(memo.body.contains("위"))
        #expect(memo.body.contains("아래"))
        #expect(memo.body.contains("---"))
    }
}

@Suite("ULID")
struct ULIDTests {
    @Test("26글자 Crockford Base32 를 만든다")
    func hasCorrectShape() {
        let ulid = ULID()
        #expect(ulid.stringValue.count == 26)
        #expect(ulid.stringValue.allSatisfy { "0123456789ABCDEFGHJKMNPQRSTVWXYZ".contains($0) })
    }

    @Test("나중에 만든 것이 사전순으로 뒤에 온다")
    func sortsChronologically() {
        let earlier = ULID(timestamp: Date(timeIntervalSince1970: 1_700_000_000), randomness: Array(repeating: 255, count: 10))
        let later = ULID(timestamp: Date(timeIntervalSince1970: 1_700_000_001), randomness: Array(repeating: 0, count: 10))
        #expect(earlier < later)
    }

    @Test("같은 시각의 두 ULID 는 서로 다르다")
    func isUniqueWithinSameMillisecond() {
        let now = Date()
        let identifiers = Set((0..<500).map { _ in ULID(timestamp: now).stringValue })
        #expect(identifiers.count == 500)
    }

    @Test("규격을 벗어난 문자열은 받지 않는다")
    func rejectsMalformedStrings() {
        #expect(ULID("너무짧음") == nil)
        #expect(ULID("01K3ZQ8F7N2R4M6X8B0V5T9WQ!") == nil)   // 알파벳 밖의 문자
        #expect(ULID("01K3ZQ8F7N2R4M6X8B0V5T9WQI") == nil)   // I 는 Crockford 에 없다
        #expect(ULID("01K3ZQ8F7N2R4M6X8B0V5T9WQY") != nil)
    }

    @Test("파일명과 id 가 왕복한다")
    func roundTripsThroughFileName() {
        let ulid = ULID()
        #expect(MemoFile.identifier(fromFileName: MemoFile.fileName(for: ulid)) == ulid)
        #expect(MemoFile.identifier(fromFileName: "readme.txt") == nil)
    }
}

@Suite("CalendarDate")
struct CalendarDateTests {
    @Test("ISO 문자열과 왕복한다")
    func roundTripsISO() {
        let date = CalendarDate(iso: "2026-09-01")
        #expect(date == CalendarDate(year: 2026, month: 9, day: 1))
        #expect(date?.description == "2026-09-01")
    }

    @Test("느슨한 표기는 거절한다")
    func rejectsLooseFormats() {
        #expect(CalendarDate(iso: "2026-9-1") == nil)
        #expect(CalendarDate(iso: "2026/09/01") == nil)
        #expect(CalendarDate(iso: "2026-13-01") == nil)
    }

    @Test("날짜 순으로 비교한다")
    func comparesChronologically() {
        #expect(CalendarDate(year: 2026, month: 1, day: 31) < CalendarDate(year: 2026, month: 2, day: 1))
        #expect(CalendarDate(year: 2025, month: 12, day: 31) < CalendarDate(year: 2026, month: 1, day: 1))
    }
}
