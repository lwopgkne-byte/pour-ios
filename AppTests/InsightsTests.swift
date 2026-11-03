import PourAPI
import PourDesign
import Testing
import UIKit

@testable import Pour

/// 3.0 感悟（docs/3.0/01-需求文档.md 第 7 章）：标签和条数、按月分组、筛选；先改界面再发；分享的图片
@MainActor
@Suite("感悟")
struct InsightsTests {
    let items = [
        API.InsightItem(
            id: 3, day: "2026-10-29", title: "", quote: "陪儿子的时候 就只陪儿子", tags: ["家人", "专注"], noteId: 1,
            starred: true, saying: true),
        API.InsightItem(
            id: 2, day: "2026-10-28", title: "", quote: "专注比时间长更重要", tags: ["专注", "效率"], noteId: 2, starred: false),
        API.InsightItem(id: 1, day: "2025-09-02", title: "", quote: "慢慢来 比较快", tags: ["心态"], noteId: 3, starred: true),
    ]

    @Test func tagsMonthsFilters() {
        #expect(InsightsPage.tagCounts(items).map(\.tag) == ["专注", "家人", "效率", "心态"])
        #expect(InsightsPage.tagCounts(items).first?.count == 2)
        #expect(InsightsPage.months(items).map(\.month) == ["2026-10", "2025-09"])
        #expect(InsightsPage.monthTitle("2026-10", today: "2026-11-02") == "10月")
        #expect(InsightsPage.monthTitle("2025-09", today: "2026-11-02") == "2025年9月")
        #expect(InsightFilter.starred.apply(items).map(\.id) == [3, 1])
        #expect(InsightFilter.tag("专注").apply(items).map(\.id) == [3, 2])
        #expect(!InsightFilter.tag("专注").showsPending && InsightFilter.starred.showsPending)
    }

    /// 点过的星、改过的字先用上；服务器的单子拿回来、和它一样了就不再记着（删掉的也一样）
    @Test func optimistic() {
        let state = InsightState()
        var edited = items[1]
        edited.quote = "专注比时间长更要紧"
        state.stars[2] = true
        state.edits[2] = edited
        state.removed = [1]
        #expect(state.shown(items[1]).isStarred && state.shown(items[1]).quote == "专注比时间长更要紧")
        var server = items[1]
        server.starred = true
        state.settle(API.InsightsPage(insights: [server, items[0]]))
        #expect(state.stars.isEmpty, "服务器已经收藏了")
        #expect(state.edits[2] != nil, "服务器还没改字")
        #expect(state.removed.isEmpty, "服务器那边已经删了")
    }

    /// 分享的图片：1080 像素宽；长的句子往下长、不截断；签名写全年月日
    @Test func shareImage() throws {
        #expect(InsightShareSheet.signature("2026-10-11") == "—— 我，2026年10月11日")
        let short = try #require(InsightShareSheet.render(items[2], look: .warm))
        #expect(short.cgImage?.width == 1080)
        var long = items[2]
        long.quote = String(repeating: "慢慢来，比较快。", count: 12)
        for look in InsightShareCard.Look.allCases {
            let tall = try #require(InsightShareSheet.render(long, look: look))
            #expect(tall.cgImage?.width == 1080)
            #expect(tall.size.height > short.size.height + 100, "长的句子没往下长：\(look.name)")
        }
    }
}
