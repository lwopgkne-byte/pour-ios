import Foundation
import Testing

@testable import PourAPI

/// Pour 认识的（Fixtures/about-known.json：网页版演示数据的 /api/about）
@Suite("Pour 认识的")
struct KnownTests {
    @Test func decodes() throws {
        let url = try #require(
            Bundle.module.url(forResource: "about-known", withExtension: "json", subdirectory: "Fixtures"))
        let known = try JSONDecoder().decode(API.Known.self, from: try Data(contentsOf: url))
        let sleep = try #require(known.sleep)
        #expect(Show.sleepSentence(sleep) == "你通常 0:00 左右睡，7:30 左右起，睡 7 小时 20 分")
        #expect(sleep.outliers.first?.note == "比平时早起 2 小时")
        let habit = try #require(known.habits.first)
        #expect(habit.perWeek == .daily && Show.habitMeta(habit) == "几乎每天")
        #expect(known.people.first?.titled == true)
        #expect(Show.placeMeta(known.places[0]).hasPrefix("去过 18 天"))
        #expect(known.sayings.first?.note?.text.hasPrefix("老地方") == true)
        #expect(Show.saidClause("小王是我同事 人挺好", name: "小王", meaning: "同事") == "小王是我同事")
        #expect(Show.hourMinute("07:10") == "7:10" && Show.hourMinute("23:40") == "23:40")
    }
}
