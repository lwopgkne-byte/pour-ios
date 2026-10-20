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

    @Test func filter() {
        #expect(API.LibraryFilter().isEmpty)
        #expect(!API.LibraryFilter(tag: "小王").isEmpty)
    }
}
