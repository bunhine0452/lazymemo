import Foundation
import LazyMemoCore
import Observation

/// 약속 메모를 적은 뒤의 되물음 — 「어디서 출발하시나요?」 → 길 찾기 → 「무엇으로 갈까요?」 → 메모에 적기.
///
/// 맥의 빠른 입력 상자와 폰의 펜이 **같은 대화**를 돈다. 화면은 `question`·`choices`·`summary` 를
/// 그리고 사람의 한 줄을 `reply` 로 넘기면 된다 — 어느 단계인지는 여기가 안다. 한 번에 한 가지만
/// 묻고(명세 §5), 답이 아닌 말(「됐어」)이면 조용히 물러난다.
///
/// 네트워크는 사람이 답한 뒤에만 쓴다: 출발지 이름을 지도에 묻고, 지도 링크를 풀고, 길을 잰다.
/// 다 적으면 출발 10분 전에 종이가 나오도록 `surface` 를 건다 — 알림은 `ReminderCenter` 가
/// 그 시각에 건다 (`Recall`).
@MainActor
@Observable
public final class RoutePlanner {
    public enum Step: Equatable {
        case idle
        /// 「어디서 출발하시나요?」— 답을 기다린다.
        case askingOrigin
        /// 출발지를 찾고 길을 재는 중.
        case searching
        /// 「무엇으로 갈까요?」— 답을 기다린다.
        case choosing
        /// 메모에 적는 중.
        case writing
    }

    /// 바깥에 묻는 일들 — 시험은 가짜를 끼운다.
    public struct Services: Sendable {
        public var locate: @Sendable (String, Coordinate?) async -> LocatedPlace?
        public var find: @Sendable (LocatedPlace, LocatedPlace, Date, String?) async throws -> [TransitRoute]

        public init(
            locate: @escaping @Sendable (String, Coordinate?) async -> LocatedPlace?,
            find: @escaping @Sendable (LocatedPlace, LocatedPlace, Date, String?) async throws -> [TransitRoute]
        ) {
            self.locate = locate
            self.find = find
        }

        public static let live = Services(
            locate: { text, near in await PlaceLocator.locate(text, near: near) },
            find: { origin, destination, arriveBy, key in
                try await RouteFinder(transitKey: key).find(from: origin, to: destination, arriveBy: arriveBy)
            }
        )
    }

    public private(set) var step: Step = .idle
    /// 지금 묻는 말. 기다리는 동안은 「길을 찾는 중…」.
    public private(set) var question: String?
    /// 글자를 안 쳐도 되게 — 되물음의 선택지. 마지막은 늘 「됐어」.
    public private(set) var choices: [String] = []
    /// 무슨 약속의 길인지 한 줄 — 「밥약속 · 9월 16일 (수) 18:30 · 투파인드피터 잠실점」.
    public private(set) var summary: String?
    /// 답을 못 알아들었을 때의 한 줄 — 같은 질문 아래 선다.
    public private(set) var trouble: String?
    /// 끝난 뒤의 한 줄 — 적었다, 또는 못 찾았다. 화면이 보이고 `acknowledge` 로 지운다.
    public private(set) var notice: String?
    public private(set) var memoID: ULID?
    /// 다 적었다 — 화면이 종이·달력을 내보이는 고리.
    public var onWritten: ((Memo, TransitRoute) -> Void)?
    /// 「지금 여기」— 화면이 위치를 잴 수 있으면 끼운다. 있으면 선택지에 선다.
    public var here: (@MainActor () async -> LocatedPlace?)?

    public var isWaiting: Bool { step == .askingOrigin || step == .choosing }
    public var isBusy: Bool { step == .searching || step == .writing }
    public var isActive: Bool { step != .idle }

    private let store: MemoStore
    private let services: Services
    /// 설정 — 물을지, ODsay 키. 매번 읽는다: 설정을 바꾼 뒤 다음 약속부터 바로 따르게.
    private let settings: @MainActor () -> Settings
    private var memo: Memo?
    private var destination: Task<LocatedPlace?, Never>?
    private var origin: LocatedPlace?
    private var found: [TransitRoute] = []
    private var work: Task<Void, Never>?
    /// 이번 대화의 표. 물러난 뒤 늦게 돌아온 접속이 다음 대화를 건드리지 않게 — 돌아오면 표를 대조한다.
    private var session = UUID()
    public var now: () -> Date = Date.init

    public init(store: MemoStore, settings: @escaping @MainActor () -> Settings, services: Services = .live) {
        self.store = store
        self.settings = settings
        self.services = services
    }

    // MARK: 말

    public static let originQuestion = "어디서 출발하시나요?"
    public static let modeQuestion = "무엇으로 갈까요?"
    public static let skipChoice = "됐어"
    public static let hereChoice = "지금 여기"
    /// 「됐어」「몰라」— 길은 안 찾는다. 짧은 답일 때만 (긴 글은 새 말이다).
    public static let skipWords = ["됐어", "됐다", "몰라", "모르겠", "안 해도", "안해도", "괜찮", "그만", "나중에", "아니", "필요 없", "필요없", "묻지 마", "묻지마", "패스", "건너"]
    /// 알림을 출발 몇 분 전에 걸까.
    public static let lead: TimeInterval = 10 * 60

    // MARK: 시작

    /// 이 메모에 길을 물을 만한가 — 앞으로 올 약속이고, 자리(좌표·이름·지도 링크)가 있다.
    public static func applies(_ memo: Memo, now: Date = Date()) -> Bool {
        guard let at = memo.at, at > now else { return false }
        if memo.geo != nil || memo.place?.isEmpty == false { return true }
        return MarkdownScanner.linkDestinations(in: memo.body).contains(where: MapLink.isMap)
    }

    /// 비서의 초안이 길을 물을 만한가 — 메모가 생기기 전에 화면이 갈래를 정하려고.
    public static func applies(body: String, at: Date?, place: String?, geo: Coordinate?, now: Date = Date()) -> Bool {
        applies(Memo(at: at, place: place, geo: geo, body: body), now: now)
    }

    /// 방금 적은 약속 메모를 들고 첫 질문을 세운다. 설정이 꺼져 있거나 물을 것이 없으면 아무 일도 없다.
    /// - Returns: 물었는가.
    @discardableResult
    public func begin(_ memo: Memo) -> Bool {
        guard settings().asksRoutes ?? true, Self.applies(memo, now: now()) else { return false }
        reset()
        self.memo = memo
        memoID = memo.id
        step = .askingOrigin
        question = Self.originQuestion
        choices = (here == nil ? [] : [Self.hereChoice]) + [Self.skipChoice]
        summary = Self.describe(memo, destination: nil)
        // 약속 자리는 답을 기다리는 동안 미리 찾아 둔다 — 링크를 푸는 데 두 번 접속한다.
        let services = self.services
        destination = Task { [store] in
            let found = await Self.resolveDestination(memo, services: services)
            // 좌표를 알게 됐으면 파일에 적어 둔다 — 자리 카드가 서고, 다음엔 묻지 않는다.
            if let found, memo.geo == nil {
                _ = try? await store.update(memo.id, place: memo.place == nil ? .some(found.name) : nil, geo: .some(found.geo))
            }
            return found
        }
        let currentID = memo.id
        Task { [weak self] in
            guard let self, let found = await destination?.value, memoID == currentID else { return }
            summary = Self.describe(memo, destination: found.name)
        }
        return true
    }

    /// 사람의 한 줄. 기다리는 단계가 아니면 아무것도 하지 않고 false.
    @discardableResult
    public func reply(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isWaiting, !trimmed.isEmpty else { return false }
        trouble = nil
        if Self.isSkip(trimmed) { dismiss(); return true }
        switch step {
        case .askingOrigin:
            if trimmed == Self.hereChoice, let here {
                step = .searching
                question = "지금 자리를 재는 중…"
                choices = []
                let session = self.session
                work = Task { [weak self] in
                    guard let self else { return }
                    guard let place = await here() else {
                        guard self.session == session, step == .searching else { return }
                        step = .askingOrigin; question = Self.originQuestion
                        choices = [Self.hereChoice, Self.skipChoice]
                        trouble = "지금 자리를 못 쟀어요 — 이름이나 지도 링크로 말해 주세요"
                        return
                    }
                    guard self.session == session else { return }
                    await search(from: place)
                }
            } else {
                locateOrigin(trimmed)
            }
        case .choosing:
            guard let kind = Self.kind(in: trimmed, among: found) else {
                trouble = "버스·지하철·택시 중에 골라 주세요"
                return true
            }
            guard let route = route(for: kind) else {
                trouble = "\(kind.label)로 가는 길은 못 찾았어요"
                return true
            }
            write(route)
        default:
            return false
        }
        return true
    }

    /// 선택지 하나를 눌렀다 — 답과 같은 길.
    public func choose(_ choice: String) { reply(choice) }

    /// 물러난다 — 메모는 그대로, 길은 없다.
    public func dismiss() {
        work?.cancel()
        destination?.cancel()
        reset()
    }

    /// 끝난 뒤의 한 줄을 지운다.
    public func acknowledge() { notice = nil }

    /// 렌더·시험용 — 접속 없이 되물음의 모습을 세운다 (`PreviewRenderer`). 제품 코드는 부르지 않는다.
    public func stageForPreview(step: Step, question: String?, choices: [String], summary: String?, trouble: String? = nil) {
        reset()
        self.step = step
        self.question = question
        self.choices = choices
        self.summary = summary
        self.trouble = trouble
    }

    private func reset() {
        session = UUID()
        step = .idle
        question = nil; choices = []; summary = nil; trouble = nil
        memo = nil; memoID = nil; origin = nil; found = []; destination = nil; work = nil
    }

    // MARK: 출발지 → 길

    private func locateOrigin(_ text: String) {
        step = .searching
        question = "「\(Self.shortened(text))」를 찾는 중…"
        choices = []
        let services = self.services
        let session = self.session
        work = Task { [weak self] in
            guard let self else { return }
            let near = await destination?.value?.geo
            guard let place = await services.locate(text, near) else {
                guard self.session == session, step == .searching else { return }
                step = .askingOrigin
                question = Self.originQuestion
                choices = (here == nil ? [] : [Self.hereChoice]) + [Self.skipChoice]
                trouble = "「\(Self.shortened(text))」를 지도에서 못 찾았어요 — 다른 이름이나 지도 링크로 말해 주세요"
                return
            }
            guard self.session == session else { return }
            await search(from: place)
        }
    }

    private func search(from place: LocatedPlace) async {
        guard let memo, let at = memo.at, step == .searching else { return }
        let session = self.session
        origin = place
        question = "\(place.name)에서 가는 길을 찾는 중…"
        guard let destination = await destination?.value else {
            guard self.session == session, step == .searching else { return }
            finish(notice: "약속 자리를 지도에서 못 찾았어요 — 메모에 @자리 이름이나 지도 링크를 적어 주세요")
            return
        }
        let key = settings().transitKey
        let routes: [TransitRoute]
        do {
            routes = try await services.find(place, destination, at, key)
        } catch let failure as TransitFailure {
            guard self.session == session, step == .searching else { return }
            switch failure {
            case .network(let detail): finish(notice: "길을 찾지 못했어요 — 접속이 안 됩니다 (\(detail))")
            case .rejected(let detail): finish(notice: "길찾기가 거절됐어요 — \(detail)")
            }
            return
        } catch {
            guard self.session == session, step == .searching else { return }
            finish(notice: "길을 찾지 못했어요 — \(error.localizedDescription)")
            return
        }
        guard self.session == session, step == .searching else { return }
        found = routes
        guard !found.isEmpty else {
            finish(notice: "\(place.name)에서 \(destination.name)까지 가는 길을 못 찾았어요")
            return
        }
        step = .choosing
        question = Self.offer(found, detailed: key?.isEmpty == false)
        choices = Self.kinds(among: found).map(\.label) + [Self.skipChoice]
    }

    private func write(_ route: TransitRoute) {
        guard let memo else { return }
        step = .writing
        question = "메모에 적는 중…"
        choices = []
        let destination = self.destination
        let session = self.session
        work = Task { [weak self] in
            guard let self else { return }
            let body = RouteNote.append(route, to: (store.memo(memo.id) ?? memo).body)
            let surfaceAt = route.depart.addingTimeInterval(-Self.lead)
            let surface: Date?? = surfaceAt > now() ? .some(surfaceAt) : nil
            let place = await destination?.value
            do {
                let written = try await store.update(
                    memo.id, body: body, surface: surface,
                    place: memo.place == nil ? place.map { .some($0.name) } : nil,
                    geo: memo.geo == nil ? place.map { .some($0.geo) } : nil
                )
                // 적는 동안 물러났어도(상자를 닫았어도) 적힌 것은 적힌 것이다 — 한 줄은 남긴다.
                if self.session == session { reset() }
                notice = Self.written(route, alarm: surface != nil)
                onWritten?(written, route)
            } catch {
                guard self.session == session else { return }
                finish(notice: "가는 길을 적지 못했어요 — \(error.localizedDescription)")
            }
        }
    }

    private func finish(notice: String) {
        reset()
        self.notice = notice
    }

    // MARK: 고르기

    private func route(for kind: TransitRoute.Kind) -> TransitRoute? {
        let exact = found.first { $0.kind == kind }
        switch kind {
        case .bus, .subway: return exact ?? found.first { $0.kind == .mixed }
        case .transit: return exact ?? found.filter { $0.kind != .taxi }.min { $0.minutes < $1.minutes }
        default: return exact
        }
    }

    /// 찾은 길들이 내미는 선택지 — 있는 것만, 버스 → 지하철 → 대중교통 → 택시 차례.
    static func kinds(among routes: [TransitRoute]) -> [TransitRoute.Kind] {
        let present = Set(routes.map(\.kind))
        var kinds: [TransitRoute.Kind] = []
        if present.contains(.bus) || present.contains(.mixed) { kinds.append(.bus) }
        if present.contains(.subway) || present.contains(.mixed) { kinds.append(.subway) }
        if present.contains(.transit) { kinds.append(.transit) }
        if present.contains(.taxi) { kinds.append(.taxi) }
        return kinds
    }

    /// 사람의 답에서 탈것을. 「버스랑 지하철」은 둘 다, 「빠른 걸로」는 가장 빠른 것.
    static func kind(in text: String, among routes: [TransitRoute]) -> TransitRoute.Kind? {
        let squeezed = text.replacingOccurrences(of: " ", with: "")
        let bus = squeezed.contains("버스")
        let subway = ["지하철", "전철", "메트로", "호선"].contains { squeezed.contains($0) }
        if bus && subway { return routes.contains { $0.kind == .mixed } ? .mixed : (routes.contains { $0.kind == .bus } ? .bus : .subway) }
        if bus { return .bus }
        if subway { return .subway }
        if squeezed.contains("택시") || squeezed.contains("차로") || squeezed.contains("차타") { return .taxi }
        if squeezed.contains("대중교통") { return routes.contains { $0.kind == .transit } ? .transit : kinds(among: routes).first }
        if ["빠른", "빨리", "아무", "알아서", "추천", "최적", "제일"].contains(where: { squeezed.contains($0) }) {
            return routes.min { $0.minutes < $1.minutes }?.kind
        }
        return nil
    }

    static func isSkip(_ text: String) -> Bool {
        text == skipChoice || (text.count <= 12 && skipWords.contains { text.contains($0) })
    }

    // MARK: 문구

    /// 「경로 5개를 찾았어요 — 버스 21분 · 지하철 25분 · 택시 12분 (약 9,800원). 무엇으로 갈까요?」
    static func offer(_ routes: [TransitRoute], detailed: Bool) -> String {
        var parts: [String] = []
        for kind in kinds(among: routes) {
            let best: TransitRoute?
            switch kind {
            case .bus: best = routes.first { $0.kind == .bus } ?? routes.first { $0.kind == .mixed }
            case .subway: best = routes.first { $0.kind == .subway } ?? routes.first { $0.kind == .mixed }
            default: best = routes.first { $0.kind == kind }
            }
            guard let best else { continue }
            var piece = "\(kind.label) \(best.minutes)분"
            if best.kind == .mixed, kind != .mixed { piece += " (환승)" }
            if best.kind == .taxi, let fare = best.legs.first?.fare { piece += " (약 \(TransitRoute.won(fare)))" }
            else if best.kind == .transit { piece = "대중교통 약 \(best.minutes)분" }
            parts.append(piece)
        }
        let count = routes.count
        let head = detailed ? "경로 \(count)개를 찾았어요" : "길을 찾았어요"
        var text = "\(head) — \(parts.joined(separator: " · ")). \(modeQuestion)"
        if !detailed { text += " (버스 번호까지 보려면 설정에 ODsay 키를 넣어 주세요)" }
        return text
    }

    /// 「가는 길을 적었어요 — 버스 21분, 18:09 출발 · 환승 1회 (버스 → 지하철) · 10분 전에 알려요」
    static func written(_ route: TransitRoute, alarm: Bool, calendar: Calendar = .current) -> String {
        var parts = ["\(route.kind.label) \(route.minutes)분, \(RouteNote.clock(route.depart, calendar: calendar)) 출발"]
        if let words = route.transferWords { parts.append("환승 \(route.transfers)회 (\(words))") }
        if alarm { parts.append("출발 \(Int(lead / 60))분 전에 알려요") }
        return "가는 길을 적었어요 — " + parts.joined(separator: " · ")
    }

    static func describe(_ memo: Memo, destination: String?, calendar: Calendar = .current) -> String {
        var parts = [memo.title]
        if let at = memo.at {
            parts.append("\(DateWords.monthDayWeekday(CalendarDate(at, calendar: calendar), calendar: calendar)) \(RouteNote.clock(at, calendar: calendar))")
        }
        if let place = destination ?? memo.place { parts.append(place) }
        return parts.joined(separator: " · ")
    }

    private static func shortened(_ text: String) -> String {
        text.count > 24 ? String(text.prefix(24)) + "…" : text
    }

    static func resolveDestination(_ memo: Memo, services: Services) async -> LocatedPlace? {
        if let geo = memo.geo { return LocatedPlace(name: memo.place ?? memo.title, geo: geo) }
        if let link = MarkdownScanner.linkDestinations(in: memo.body).first(where: MapLink.isMap),
           let found = await services.locate(link, nil) {
            return found
        }
        if let place = memo.place, !place.isEmpty { return await services.locate(place, nil) }
        return nil
    }
}
