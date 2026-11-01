import Foundation
import Testing

@testable import PourAPI

/// 3.0 心情页（Fixtures/mood-*.json：演示数据的 /api/mood/page?month=2026-10、/api/mood/words）
@Suite("心情页")
struct MoodPageTests {
    func fixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(T.self, from: try Data(contentsOf: url))
    }

    @Test func page() throws {
        let page = try fixture("mood-page", as: API.MoodPage.self)
        #expect(page.month == "2026-10" && !page.current)
        #expect(page.days.count == 31)
        #expect(page.monthLine == "平均在一般和挺好之间 · 31 天说到了心情")
        let last = try #require(page.days.last)
        #expect(last.day == "2026-10-31" && last.word == "有起有落" && last.moments.count == 3)
        #expect(last.moments.map(\.time) == ["16:20", "18:10", "21:50"])
        #expect(last.moments[1].moment == "方案又改了" && last.moments[1].emotions == ["烦躁"])
        #expect(page.good.total == 15 && page.good.recent.count == 3)
        #expect(page.week?.bars.count == 7)
        #expect(page.prevMonth == "2026-09" && page.nextMonth == "2026-11")
    }

    @Test func onlyLevel() throws {
        // 在心情那一页只点了一档：「心情挺好」——没有那一刻、没有情绪词
        let page = try fixture("mood-page", as: API.MoodPage.self)
        let plain = page.days.flatMap(\.moments).first { $0.level == 4 && $0.moment == nil && $0.emotions.isEmpty }
        #expect(plain != nil)
    }

    @Test func words() throws {
        let words = try fixture("mood-words", as: API.MoodWords.self)
        #expect(words.good.count == 7 && words.bad.count == 7)
        #expect(words.good.first == "开心" && words.bad.contains("累"))
    }
}
