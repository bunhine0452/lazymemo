import Foundation

/// 서랍의 **폴더** — 이름 있는 칸 여러 개.
///
/// ## 왜 생겼나
///
/// 서랍은 처음에 「폴더 하나, 이름 없음」이었다 (§16.1). 밀어 둔 종이가 어디로
/// 갔는지 보여주는 자리로는 충분했지만, 사람은 거기 쌓인 서른 장을 **성격으로
/// 나눠 두고 싶어 했다** — 「읽을 것」과 「집」과 「장보기」는 같은 무더기에
/// 있을 이유가 없다. 찾기는 분류를 대신하지 못한다: 찾으려면 낱말을 알아야
/// 하고, 폴더는 낱말이 기억나지 않을 때 **훑는** 길이다.
///
/// ## 규칙
///
/// - **폴더는 서랍의 칸이다.** 날짜처럼 종이의 자리를 정하지 않는다 (§7.2).
///   폴더에 넣는 것은 곧 서랍에 넣는 것이고, 꺼낸 종이도 이름표는 그대로
///   달고 있어서 다시 넣으면 같은 칸으로 돌아간다.
/// - **이름표는 파일에 있다** (`Memo.folder`). 차례와 빈 폴더만 설정이 든다
///   (`Settings.folders`). 설정을 잃어도 메모의 이름표로 폴더가 되살아난다.
/// - **이름은 사람이 적은 그대로다.** 앞뒤 공백만 걷어 내고, 빈 이름은 없는
///   것으로 친다. 대소문자를 합치지 않는다 — 「iOS」와 「ios」를 같은 폴더로
///   만들면 사람이 적은 것이 앱의 것으로 바뀐다.
///
/// 뷰 밖의 순수 함수인 이유는 `DrawerContents` 와 같다. 폴더 이름이 한 글자
/// 어긋나면 종이가 **어느 칸에도 없는 것**으로 보이고, 그것이 서랍에서 가장
/// 비싼 고장이다.
public enum MemoFolders {

    /// 사람이 적은 이름을 폴더 이름으로. 빈 이름은 `nil`.
    public static func normalized(_ name: String?) -> String? {
        guard let name else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 지금 있는 폴더 전부 — **설정의 차례가 먼저, 메모에만 있는 이름은 뒤에.**
    ///
    /// 메모에 적힌 이름표가 설정에 없을 수 있다 (다른 컴퓨터에서 옮겨 온
    /// 폴더, Claude 가 MCP 로 새로 적은 이름). 그 폴더도 있는 폴더다 —
    /// 설정에 없다고 안 보이면 그 메모는 어느 칸에도 없는 것이 된다.
    public static func names(listed: [String]?, memos: [Memo]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for raw in listed ?? [] {
            guard let name = normalized(raw), !seen.contains(name) else { continue }
            seen.insert(name)
            result.append(name)
        }
        let unlisted = memos
            .compactMap { $0.deleted == nil ? $0.folder : nil }
            .filter { !seen.contains($0) }
        for name in Array(Set(unlisted)).sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending }) {
            result.append(name)
        }
        return result
    }

    /// 새 폴더를 만든다. 이미 있으면 그대로 돌려준다 — 같은 이름 둘은 폴더가 아니라 오타다.
    public static func adding(_ name: String, to listed: [String]) -> [String] {
        guard let name = normalized(name) else { return listed }
        return listed.contains(name) ? listed : listed + [name]
    }

    /// 이름을 바꾼다. 새 이름이 비었거나 이미 있으면 **아무것도 바꾸지 않는다.**
    public static func renaming(_ old: String, to new: String, in listed: [String]) -> [String]? {
        guard let new = normalized(new), new != old, !listed.contains(new) else { return nil }
        guard let index = listed.firstIndex(of: old) else { return listed + [new] }
        var result = listed
        result[index] = new
        return result
    }

    public static func removing(_ name: String, from listed: [String]) -> [String] {
        listed.filter { $0 != name }
    }

    /// 폴더가 몇 장씩 들고 있는지. **여기 넘기는 것은 서랍에 든 종이뿐이어야 한다** —
    /// 바탕화면에 나와 있는 종이까지 세면 「장보기 4」를 열었는데 두 장만 보인다.
    public static func counts(in papers: [Memo]) -> [String: Int] {
        var result: [String: Int] = [:]
        for paper in papers {
            guard let folder = paper.folder else { continue }
            result[folder, default: 0] += 1
        }
        return result
    }

    /// 이 칸에 든 종이. `nil` 은 「전체」다.
    public static func filter(_ papers: [Memo], folder: String?) -> [Memo] {
        guard let folder else { return papers }
        return papers.filter { $0.folder == folder }
    }
}
