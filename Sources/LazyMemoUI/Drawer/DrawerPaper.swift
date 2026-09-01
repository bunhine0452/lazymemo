import LazyMemoCore
import SwiftUI

/// 서랍 안의 종이 한 장 — **작아진 것과 원래 크기가 같은 뷰다.**
///
/// 둘을 다른 뷰로 만들면 커지는 동작이 «작은 것이 사라지고 큰 것이 나타나는»
/// 것으로 보인다. 같은 뷰가 크기만 바뀌어야 **그 종이가 자란 것**으로 읽히고,
/// `matchedGeometryEffect` 도 그때만 두 자리를 하나로 잇는다.
///
/// 작을 때와 클 때 달라지는 것은 **무엇을 적는가**뿐이다. 작은 종이에 본문을
/// 넣으면 5pt 짜리 글씨가 되는데, 그것은 글이 아니라 회색 줄무늬다 — 읽을 수
/// 없는 것을 그려 두면 종이가 아니라 «종이 모양의 얼룩» 이 된다. 작을 때는
/// 제목 한 줄과 색, 클 때는 글 전부.
struct DrawerPaper: View {
    let memo: Memo
    let size: CGSize
    /// 원래 크기로 돌아왔는가.
    var detail: Bool = false
    /// 손이 얹혔는가 — 잠깐 커지고 그림자가 깊어진다.
    var lifted: Bool = false

    private var radius: CGFloat { detail ? Theme.cardRadius : 4 }

    /// 제목을 뺀 나머지 — 원래 크기일 때만 적는다.
    ///
    /// 여기서는 **읽기만 한다.** 그래서 체크상자를 글자 그대로(`- [x]`) 두지
    /// 않고 기호로 바꾼다 — 편집기는 그것을 그려 주는데(`MarkdownStyler`),
    /// 서랍에서만 날 것으로 보이면 같은 메모가 두 곳에서 다른 물건이 된다
    /// (§14.10). 고치는 것은 「꺼내기」로 종이를 되돌린 다음이다 (`DrawerText`).
    private var rest: String {
        let lines = memo.body.split(separator: "\n", omittingEmptySubsequences: false)
        guard let first = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        else { return "" }
        return lines[(first + 1)...]
            .map(DrawerText.plain)
            .joined(separator: "\n")
            .trimmingCharacters(in: .newlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: detail ? 7 : 3) {
            Text(memo.title)
                .font(.system(size: detail ? 13 : 10.5, weight: .semibold))
                .foregroundStyle(Paper.ink.opacity(detail ? 0.92 : 0.86))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if detail {
                if !rest.isEmpty {
                    Text(rest)
                        .font(.system(size: 11.5))
                        .lineSpacing(Theme.bodyLineSpacing - 1)
                        .foregroundStyle(Paper.ink.opacity(0.78))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 0)
                mark
            } else {
                // **띠 밑에 두 줄이 잠들어 있다.** 겹쳐 놓인 동안에는 다음 장이
                // 덮고 있어 보이지 않다가, 손이 얹혀 아래 것들이 내려가면
                // (`DrawerGeometry.lift`) 그 자리에서 그대로 드러난다.
                //
                // 손이 왔을 때 «무엇을 적을지» 를 바꾸지 않는 것이 요점이다.
                // 얹힐 때마다 글이 새로 짜이면 그건 종이가 드러난 것이 아니라
                // **다른 종이로 갈아 끼운 것**으로 보인다 (§14.10).
                VStack(alignment: .leading, spacing: 3) {
                    if !rest.isEmpty {
                        Text(rest)
                            .font(.system(size: 10))
                            .lineSpacing(1)
                            .foregroundStyle(Paper.ink.opacity(0.60))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    mark
                }
                // **띠에 걸리는 글자는 아예 안 적는다.** 자리는 잡아 두되
                // 손이 오기 전에는 비워 둔다 — 30pt 짜리 띠에 두 줄을 그려
                // 놓으면 다음 장이 그 둘째 줄을 **글자 한가운데서 자르고**,
                // 잘린 글자는 글이 아니라 때처럼 보인다.
                //
                // 자리를 없애지 않고 투명하게만 두는 것이 요점이다. 없앴다가
                // 다시 넣으면 글이 새로 짜이면서 종이가 «드러난» 것이 아니라
                // «갈아 끼운» 것으로 보인다.
                .opacity(lifted ? 1 : 0)

                Spacer(minLength: 0)
            }
        }
        .padding(detail ? Theme.normal : 8)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        // **작은 장에도 점을 깐다.** 도트 그리드를 빼 두었더니, 손이 얹혀
        // 벌어진 자리에서 글이 없는 종이가 «빈 종이» 가 아니라 **색 덩어리**로
        // 보였다 — 이 앱의 재질은 종이 하나인데(§14.5) 작은 장만 칩이 된 것이다.
        .background { PaperSurface(tint: memo.color.ink, radius: radius) }
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Paper.ink.opacity(0.10), lineWidth: 0.75)
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        // 종이는 서랍 바닥에 놓여 있다 — 손이 오면 한 장만 들린다.
        //
        // **닿는 그림자와 퍼지는 그림자를 나눈다** (`RaisedSurface` 와 같은 셈).
        // 한 겹이면 들릴 때 그림자가 «진해지면서 퍼지는데», 실제로는 반대다 —
        // 바닥을 떠나는 순간 닿는 자리의 진한 그림자가 **옅어지고** 주변으로
        // 퍼지는 쪽이 자란다. 그 두 방향이 어긋나야 종이가 들린 것으로 보인다.
        .shadow(color: .black.opacity(lifted ? 0.14 : 0.22), radius: 1, y: 0.5)
        .shadow(
            color: .black.opacity(lifted ? 0.22 : 0.08),
            radius: lifted ? 11 : 4, y: lifted ? 5 : 1.5
        )
    }

    /// 아래 한 줄 — 언제 손댔는가. 폴더도 태그도 유지하지 않는 사람이
    /// 받아들이는 단서는 「언제」뿐이다 (철학 2, `MemoTimeLabel`).
    private var mark: some View {
        HStack(spacing: 4) {
            Text(MemoTimeLabel.text(for: memo))
                .font(.system(size: detail ? 10 : 8.5))
                .foregroundStyle(Paper.ink.opacity(0.42))
                .lineLimit(1)

            if detail, !memo.tags.isEmpty {
                Text(memo.tags.prefix(2).map { "#\($0)" }.joined(separator: " "))
                    .font(Theme.micro)
                    .foregroundStyle(Paper.ink.opacity(0.36))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }
}
