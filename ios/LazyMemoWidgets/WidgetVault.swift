import Foundation
import LazyMemoCore
import LazyMemoWidgetsCore
import WidgetKit

/// 위젯이 메모를 읽는 길 — **파일만 읽는다.**
///
/// `MemoService` 를 띄우지 않는다. 그쪽은 인덱스(SQLite)까지 여는데 인덱스는 파생물이라 앱이
/// 짓는 것이고(§5.3), 위젯은 메모리 한도가 빡빡하고 몇 초 안에 끝나야 한다 — 공유 확장의
/// `InboxDrop` 과 같은 이유. 자리는 앱·공유 확장과 같은 차례(`AppPaths.resolveCloud`):
/// iCloud 컨테이너, 없으면 App Group(폰). 맥에서 메모 폴더를 다른 곳으로 옮겨 둔 사람의
/// 메모는 위젯이 못 본다 — 그 폴더의 열쇠(`VaultBookmark`)는 앱만 쥐고 있다.
enum WidgetVault {
    static func memos() async -> [Memo] {
        // 컨테이너 찾기는 첫 호출에 iCloud 데몬과 이야기하는 막히는 호출이다.
        let container = await Task.detached(priority: .userInitiated) { AppPaths.ubiquityContainer() }.value
        // App Group 은 폰의 것이다 — 맥 위젯에는 그 entitlement 가 없다.
        #if os(iOS)
        let shared = AppPaths.sharedContainer()
        #else
        let shared: URL? = nil
        #endif
        let paths = AppPaths.resolveCloud(container: container, shared: shared).paths
        let vault = MemoVault(paths: paths)
        return ((try? await vault.loadAll()) ?? []).map(\.memo)
    }
}

/// 위젯 갤러리와 자리 잡기(placeholder)에 보이는 견본 — 진짜 메모가 아니다.
enum WidgetSample {
    static func memos(now: Date, calendar: Calendar = .current) -> [Memo] {
        let start = calendar.startOfDay(for: now)
        func clock(_ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: start) ?? now
        }
        let dentist = Memo(id: ULID(), at: clock(15), body: String(localized: "치과 예약 — 강남역 3번 출구"))
        let design = Memo(id: ULID(), surface: clock(10, 30), body: String(localized: "설계 문서 다시 읽기"))
        let groceries = Memo(id: ULID(), pinned: true, body: String(localized: "장보기 — 우유·계란·두부"))
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let meeting = Memo(id: ULID(), at: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow,
                           body: String(localized: "주간 회의"))
        // 달력 격자에 점이 몇 개는 있어야 무엇인지 보인다 — 날짜만 있는 것 둘.
        let bill = Memo(id: ULID(), due: CalendarDate(now, calendar: calendar).adding(days: 5, calendar: calendar),
                        body: String(localized: "전기요금 납부"))
        let birthday = Memo(id: ULID(), due: CalendarDate(now, calendar: calendar).adding(days: 12, calendar: calendar),
                            body: String(localized: "엄마 생신"))
        return [dentist, design, groceries, meeting, bill, birthday]
    }
}
