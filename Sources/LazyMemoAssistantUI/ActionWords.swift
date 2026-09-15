import Foundation
import LazyMemoAssistant
import LazyMemoCore

/// 제안된 변경을 사람의 말로. 정확한 시각을 보여 주고서야 실행한다 (명세 §5).
public enum ActionWords {
    /// 모델·해석기가 낸 문장 — 표에 있으면 번역하고, 없으면 그대로.
    public static func soft(_ text: String) -> String { Lsoft(text) }

    public static func describe(_ action: ProposedAction, memoTitle: String?) -> String {
        let name = memoTitle.map { "「\($0)」" } ?? L("이 메모")
        switch action.kind {
        case .ask: return action.question.map(Lsoft) ?? L("한 가지만 더 알려 주세요")
        case .none: return L("바꿀 것이 없습니다")
        case .trash: return L("\(name) 을(를) 휴지통으로 옮깁니다")
        case .createMemo:
            var parts = [L("새 메모: \(action.patch.body ?? "")")]
            if case .set(let at) = action.patch.at { parts.append(L("약속 \(time(at))")) }
            else if case .set(let due) = action.patch.due { parts.append(L("날짜 \(due.description)")) }
            if let place = action.patch.place { parts.append(L("자리 \(place)")) }
            return parts.joined(separator: " · ")
        case .setRecall:
            switch action.patch.surface {
            case .set(let date): return L("\(name) 을(를) \(time(date)) 에 다시 보여 줍니다")
            case .clear: return L("\(name) 의 다시 보기를 지웁니다")
            case .keep: return L("바꿀 것이 없습니다")
            }
        case .reschedule:
            if case .set(let at) = action.patch.at { return L("\(name) 의 약속을 \(time(at)) 으로 옮깁니다") }
            if case .clear = action.patch.at { return L("\(name) 의 약속 시각을 지웁니다") }
            if case .set(let due) = action.patch.due { return L("\(name) 의 날짜를 \(due.description) 으로 옮깁니다") }
            if case .clear = action.patch.due { return L("\(name) 의 날짜를 지웁니다") }
            return L("바꿀 것이 없습니다")
        case .moveToFolder:
            if case .set(let folder) = action.patch.folder { return L("\(name) 을(를) 「\(folder)」 폴더로 옮깁니다") }
            if case .clear = action.patch.folder { return L("\(name) 을(를) 폴더에서 뺍니다") }
            return L("바꿀 것이 없습니다")
        }
    }

    /// 「9월 18일 (금) 10:00」— 빠른 입력의 날짜 칩과 같은 꼴. 해는 다를 때만 붙는다.
    public static func time(_ date: Date) -> String {
        let sameYear = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
        return sameYear
            ? date.formatted(.dateTime.month().day().weekday(.abbreviated).hour().minute())
            : date.formatted(.dateTime.year().month().day().weekday(.abbreviated).hour().minute())
    }

    public static func title(of evidence: Evidence) -> String {
        evidence.excerpt.split(separator: "\n").first.map(String.init) ?? L("빈 메모")
    }
}
