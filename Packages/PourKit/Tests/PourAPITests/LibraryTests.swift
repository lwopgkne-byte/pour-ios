import Foundation
import Testing

@testable import PourAPI

/// 笔记库（Fixtures/library-*.json：演示数据的 /api/library、/api/library/people、/api/insights、/api/moments）
@Suite("笔记库")
struct LibraryTests {
    func fixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(T.self, from: try Data(contentsOf: url))
    }

    @Test func notes() throws {
        let page = try fixture("library-notes", as: API.LibraryPage.self)
        #expect(page.hasMore)
        let first = try #require(page.notes.first)
        #expect(first.status == "pending" && first.entries.isEmpty && first.error != nil)
        #expect(first.note.id == first.id)
        let meal = try #require(page.notes.first { $0.text == "食堂吃的 15" })
        #expect(meal.entries.first?.text == "🍽 食堂午饭 ¥15 · 在公司食堂")
        #expect(page.notes.contains { ($0.result?.advanced ?? []).isEmpty == false })
    }

    @Test func others() throws {
        let people = try fixture("library-people", as: API.Mentions.self).items
        #expect(people.first?.name == "儿子" && people.first?.kind == "person")
        #expect(people.contains { $0.kind == "thing" })
        let insights = try fixture("library-insights", as: API.InsightsPage.self)
        #expect(insights.insights.first?.tags == ["专注", "效率"])
        #expect(insights.tags.first?.count == 2)
        let moments = try fixture("library-moments", as: API.Moments.self).moments
        #expect(moments.first?.noteId == 365)
        guard case .mood(let mood) = moments.first?.entry.data else {
            Issue.record("好时刻应该是心情")
            return
        }
        #expect(mood.moment == "晚上楼下飘上来烤红薯的香味")
    }

    /// 3.0 感悟页（Fixtures/insights.json、insight-today.json：5288 演示数据）：语录 ★（收藏的 + 记一句记的）、今天重温
    @Test func insightsPage() throws {
        let page = try fixture("insights", as: API.InsightsPage.self)
        #expect(page.starred == 7 && page.insights.filter(\.isStarred).count == 7)
        let first = try #require(page.insights.first)
        #expect(first.isStarred && first.saying == true && first.quote == "陪儿子的时候 就只陪儿子")
        let today = try fixture("insight-today", as: API.InsightDetail.self)
        #expect(today.ago == "一个月前的今天你说" && today.related.count == 3)
        let quote = try #require(today.insight?.quote)
        #expect(today.said?.contains(quote) == true)
        #expect(APIClient.insightsPath() == "/api/insights")
        #expect(APIClient.insightsPath(query: " 陪 儿子& ") == "/api/insights?q=%E9%99%AA%20%E5%84%BF%E5%AD%90%26")
    }

    @Test func filter() {
        #expect(API.LibraryFilter().isEmpty)
        #expect(!API.LibraryFilter(tag: "小王").isEmpty)
    }

    /// 一段话下面的小标签不带表情（照原型）：服务器写的类别表情、⏰ 去掉，数字、箭头留着
    @Test func plainChips() {
        #expect(Show.plain("😴 0:10 → 7:00") == "0:10 → 7:00")
        #expect(Show.plain("🍽️ 16:8 轻断食") == "16:8 轻断食")
        #expect(Show.plain("✅ 完成：吃维生素") == "完成：吃维生素")
        #expect(Show.plain("📝 待办：交房租（⏰ 明天 17:30 提醒）") == "待办：交房租（明天 17:30 提醒）")
        #expect(Show.plain("跑步 30 分钟 #3") == "跑步 30 分钟 #3")
    }
}
