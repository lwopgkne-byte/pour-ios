import Foundation
import Testing

@testable import PourAPI

/// 网页版服务器真的回来的样子（演示数据，Fixtures/ 是从网页版 /api 拿的）：手机都看得懂
@Suite("网页版的接口")
struct DecodingTests {
    func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    @Test func aDay() throws {
        let day = try JSONDecoder().decode(API.DayView.self, from: try fixture("day"))
        #expect(day.day == "2026-10-15")
        #expect(day.entries.count == 15)
        #expect(Set(day.entries.map(\.kind)) == ["event", "insight", "todo", "mood"])
        guard case .event(let lift) = day.entries.first(where: { $0.category == "strength" })?.data else {
            Issue.record("应该有力量训练")
            return
        }
        #expect(lift.label == "力量训练")
        #expect(lift.metrics?.first?.unit == "公斤")
        #expect(!day.goals.isEmpty)
    }

    @Test func notesAndTrend() throws {
        let page = try JSONDecoder().decode(API.NotesPage.self, from: try fixture("notes"))
        #expect(page.notes.count == 5)
        #expect(page.notes.allSatisfy { $0.status == "done" })
        #expect(page.notes.contains { !($0.result?.receipt.isEmpty ?? true) })
        let trend = try JSONDecoder().decode(API.Trend.self, from: try fixture("trend"))
        #expect(trend.points.count == 7)
    }

    @Test func serverEvents() {
        let event = APIClient.event("notes-changed", #"{"day":"2026-10-19","statusOnly":true}"#)
        #expect(event == ServerEvent(type: "notes-changed", statusOnly: true, day: "2026-10-19"))
        #expect(APIClient.event("summary-changed", "{}").statusOnly == false)
        // 回答一边生成一边推过来：一截一截的字；null 是结束
        let delta = APIClient.event("answer-delta", #"{"noteId":12,"text":"上次去爬山"}"#)
        #expect(delta.noteId == 12 && delta.text == "上次去爬山")
        #expect(APIClient.event("answer-delta", #"{"noteId":12,"text":null}"#).text == nil)
    }
}

@Suite("网页版的写法（用在网页版服务器的数据上）")
struct ShowTests {
    @Test func linesOfADay() throws {
        let url = try #require(Bundle.module.url(forResource: "day", withExtension: "json", subdirectory: "Fixtures"))
        let day = try JSONDecoder().decode(API.DayView.self, from: try Data(contentsOf: url))
        guard case .event(let lift) = day.entries.first(where: { $0.category == "strength" })?.data else {
            Issue.record("应该有力量训练")
            return
        }
        #expect(Show.eventMeta(lift, day: day.day) == "20:00–20:45 · 45 分钟 · 卧推重量 70 公斤 · 卧推组数 5 组 · 在健身房")
        let receipt = Show.receipt([
            API.ReceiptItem(action: "created", kind: "event", entryId: 1, text: "🏃 跑步 5 公里", pending: false),
            API.ReceiptItem(action: "deleted", kind: "event", entryId: 2, text: "删除 💼 被老板骂", pending: false),
        ])
        #expect(receipt == "已记录：🏃 跑步 5 公里；已删除：💼 被老板骂")
        #expect(Show.moneyNotes([API.Metric(name: "花费", value: 58, unit: "元")], label: "打车") == [])
    }
}
