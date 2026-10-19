import Foundation
import Testing

@testable import PourAPI

/// 斜杠命令（shared commands.ts）
@Suite("斜杠命令")
struct CommandsTests {
    @Test func menu() {
        #expect(Show.slashMenu("/").map(\.cmd) == ["/问", "/记", "/目标", "/改", "/搜索", "/今天", "/周报", "/撤销"])
        #expect(Show.slashMenu("/找").map(\.cmd) == ["/找"])
        #expect(Show.slashMenu("/问 这周").isEmpty)
        #expect(Show.slashMenu("跑步").isEmpty)
    }

    @Test func parse() throws {
        let ask = try #require(Show.parseSlash("/问 这周运动了几次"))
        #expect(ask.command.intent == "question" && ask.rest == "这周运动了几次")
        #expect(Show.parseSlash("/目标\u{3000}每周运动 3 次")?.command.cmd == "/目标")
        #expect(Show.parseSlash("/撤销")?.command.action == "undo")
        #expect(Show.parseSlash("/问这周") == nil)
        #expect(Show.parseSlash("跑步") == nil)
    }

    @Test func evening() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let at = { (hour: Int) in
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: hour)) ?? .now
        }
        #expect(Show.isEvening(at(18), boundary: 240, calendar: calendar))
        #expect(Show.isEvening(at(3), boundary: 240, calendar: calendar))
        #expect(!Show.isEvening(at(9), boundary: 240, calendar: calendar))
    }
}
