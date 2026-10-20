import Foundation
import Testing

@testable import PourAPI

/// 对话里的系统消息（Fixtures/messages.json 是从演示数据的 /api/messages 拿的）
@Suite("对话里的系统消息")
struct MessagesTests {
    @Test func decodes() throws {
        let url = try #require(
            Bundle.module.url(forResource: "messages", withExtension: "json", subdirectory: "Fixtures"))
        let page = try JSONDecoder().decode(API.MessagesPage.self, from: try Data(contentsOf: url))
        #expect(page.messages.map(\.kind) == ["daily", "weekly", "warning", "todo", "monthly"])
        let daily = try #require(page.messages.first?.daily)
        #expect(daily.day == "2026-10-18")
        #expect(daily.overview.hasPrefix("睡了 8 小时 20 分"))
        let weekly = try #require(page.messages[1].report)
        #expect(Show.reportPath(weekly.kind, from: weekly.period.from) == "/review/week/2026-10-12")
        let monthly = try #require(page.messages[4].report)
        #expect(Show.reportPath(monthly.kind, from: monthly.period.from) == "/review/month/2026-09")
    }

    @Test func emoji() {
        #expect(Show.messageEmoji("daily") == "📖")
        #expect(Show.messageEmoji("todo") == "⏰")
        #expect(Show.messageEmoji("monthly") == "📋")
    }

    /// shared 的 learnedPhrase：「「小王」= 同事」里的「小王」
    @Test func learnedPhrase() {
        #expect(Show.learnedPhrase("「小王」= 同事") == "小王")
        #expect(Show.learnedPhrase(" 『老地方』 = 公司楼下的面馆") == "老地方")
        #expect(Show.learnedPhrase("小王是同事") == nil)
        #expect(Show.learnedPhrase("「」= 空的") == nil)
    }

    /// 对话里的时间补零（shared formatClock），按日界线分天（shared logicalDate）
    @Test func clockAndDay() throws {
        let beijing = try #require(TimeZone(identifier: "Asia/Shanghai"))
        #expect(Show.formatClock("2026-10-19T01:05:00.000Z", in: beijing) == "09:05")
        #expect(Show.formatClock("2026-10-19T01:05:00Z", in: beijing) == "09:05")
        #expect(Show.formatClock("不是时间", in: beijing) == "")
        // 北京时间 10 月 19 日凌晨 3 点：日界线 4 点之前，还算 18 日
        #expect(Show.logicalDay("2026-10-18T19:00:00.000Z", boundary: 240, in: beijing) == "2026-10-18")
        #expect(Show.logicalDay("2026-10-18T21:00:00.000Z", boundary: 240, in: beijing) == "2026-10-19")
    }
}
