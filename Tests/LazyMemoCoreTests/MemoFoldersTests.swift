import Foundation
import Testing
@testable import LazyMemoCore

/// 서랍의 폴더 규칙 (`MemoFolders`) — **종이가 어느 칸에도 없는 상태가 생기지 않는가.**
@Suite("서랍의 폴더")
struct MemoFoldersTests {

    private func paper(_ title: String, folder: String? = nil, deleted: Date? = nil) -> Memo {
        Memo(body: title, folder: folder, deleted: deleted)
    }

    @Test("이름은 앞뒤 공백만 걷어 내고, 빈 이름은 없는 것이다")
    func normalizesNames() {
        #expect(MemoFolders.normalized("  장보기 ") == "장보기")
        #expect(MemoFolders.normalized("") == nil)
        #expect(MemoFolders.normalized("   ") == nil)
        #expect(MemoFolders.normalized(nil) == nil)
        // 대소문자는 합치지 않는다 — 사람이 적은 것이 앱의 것으로 바뀌면 안 된다.
        #expect(MemoFolders.normalized("iOS") == "iOS")
    }

    @Test("메모가 이름표를 달고 있으면 그것도 폴더다 — 설정에 없어도")
    func namesIncludeUnlistedFolders() {
        let memos = [paper("하나", folder: "집"), paper("둘", folder: "장보기"), paper("셋")]
        #expect(MemoFolders.names(listed: ["장보기"], memos: memos) == ["장보기", "집"])
        // 설정의 차례가 먼저고, 설정에 없는 것은 뒤에 이름순으로 붙는다.
        #expect(MemoFolders.names(listed: ["읽을 것", "장보기"], memos: memos) == ["읽을 것", "장보기", "집"])
    }

    @Test("지운 메모의 이름표는 폴더를 살리지 않는다")
    func deletedMemosDoNotResurrectFolders() {
        let memos = [paper("하나", folder: "옛날", deleted: Date())]
        #expect(MemoFolders.names(listed: nil, memos: memos).isEmpty)
    }

    @Test("설정의 겹친 이름과 빈 이름은 걸러진다")
    func listedNamesAreCleaned() {
        #expect(MemoFolders.names(listed: ["집", " 집", "", "장보기"], memos: []) == ["집", "장보기"])
    }

    @Test("같은 이름을 두 번 만들지 않는다")
    func addingIsIdempotent() {
        #expect(MemoFolders.adding("집", to: ["장보기"]) == ["장보기", "집"])
        #expect(MemoFolders.adding("집", to: ["장보기", "집"]) == ["장보기", "집"])
        #expect(MemoFolders.adding("  ", to: ["장보기"]) == ["장보기"])
    }

    @Test("이름 바꾸기는 자리를 지키고, 빈 이름이나 겹치는 이름이면 아무것도 안 한다")
    func renamingKeepsOrder() {
        #expect(MemoFolders.renaming("집", to: "우리 집", in: ["장보기", "집", "읽을 것"]) == ["장보기", "우리 집", "읽을 것"])
        #expect(MemoFolders.renaming("집", to: "", in: ["집"]) == nil)
        #expect(MemoFolders.renaming("집", to: "장보기", in: ["장보기", "집"]) == nil)
        #expect(MemoFolders.renaming("집", to: "집", in: ["집"]) == nil)
        // 설정에 없던 이름을 바꾸면 새 이름이 설정에 들어간다.
        #expect(MemoFolders.renaming("낯선", to: "익숙한", in: ["집"]) == ["집", "익숙한"])
    }

    @Test("폴더마다 몇 장인지 센다 — 이름표 없는 종이는 세지 않는다")
    func countsPerFolder() {
        let memos = [paper("하나", folder: "집"), paper("둘", folder: "집"), paper("셋", folder: "장보기"), paper("넷")]
        #expect(MemoFolders.counts(in: memos) == ["집": 2, "장보기": 1])
    }

    @Test("칸을 고르면 그 칸의 것만, 「전체」면 전부")
    func filtersByFolder() {
        let memos = [paper("하나", folder: "집"), paper("둘"), paper("셋", folder: "집")]
        #expect(MemoFolders.filter(memos, folder: "집").map(\.title) == ["하나", "셋"])
        #expect(MemoFolders.filter(memos, folder: nil).count == 3)
        #expect(MemoFolders.filter(memos, folder: "없는 폴더").isEmpty)
    }
}
