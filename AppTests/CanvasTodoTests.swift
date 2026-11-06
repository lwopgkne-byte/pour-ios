import Foundation
import PourAPI
import PourCore
import Testing

@testable import Pour

/// 待办 2.0 第 9 步（docs/todo-2.0）：首页的待办卡——最多 4 行，过点的 → 马上做 → 其余按时间；
/// 同一个钟点开始、去掉人名后一样的几场面试合成一行
@Suite("待办 2.0：首页待办卡")
@MainActor
struct CanvasTodoTests {
    static let today = "2026-11-05"

    private func row(_ id: Int, _ content: String, _ lane: TodoQuadrant, at time: String? = nil) -> API.TodoRow {
        var row = API.TodoRow(id: id, content: content, day: Self.today, remindAt: time)
        row.quadrant = lane.rawValue
        return row
    }

    private func interview(_ id: String, _ name: String, end: String) -> CalendarItem {
        CalendarItem(
            id: id, title: "\(name) 直播带货主播-男女不限 线下面试", start: "\(Self.today)T15:00",
            end: "\(Self.today)T\(end)", allDay: false, calendar: "工作")
    }

    /// 设计稿那一天（11:35）：喝水过了、回复客户电话（马上做 · 下午）、接小孩（马上做 · 17:00）、两场面试；
    /// 喝三瓶水、吃午饭摆不下，「还有 2 件」
    @Test func theDesignDay() {
        var call = row(2, "回复客户电话", .doNow)
        call.window = TimeWindow.afternoon.rawValue
        let rows = [
            row(1, "喝水", .schedule, at: "11:12"), call, row(3, "接小孩", .doNow, at: "17:00"),
            row(4, "喝三瓶水", .schedule, at: "12:30"), row(5, "吃午饭", .unsorted),
        ]
        let events = [interview("a", "潘志文", end: "18:00"), interview("b", "陈宏远", end: "18:30")]
        let plan = CanvasTodoPlan.make(rows: rows, events: events, now: "\(Self.today)T11:35")
        #expect(plan.shown.map(\.id) == ["todo.1", "todo.2", "todo.3", "event.a+b"])
        #expect(plan.more == 2)
        guard case .event(let line) = plan.shown[3] else {
            Issue.record("第 4 行不是日程")
            return
        }
        #expect(line.title == "2 场面试：潘志文、陈宏远" && line.time == "15:00 起")
    }

    /// 名字不一样、开头不是人名的不合；全天的不进待办卡，写在顶上的日子后面
    @Test func onlySameTitlesMerge() {
        let events = [
            CalendarItem(
                id: "a", title: "产品评审会", start: "\(Self.today)T15:00", end: "\(Self.today)T16:00", allDay: false,
                calendar: "工作"),
            interview("b", "陈宏远", end: "18:30"),
            CalendarItem(
                id: "c", title: "结婚纪念日", start: "\(Self.today)T00:00", end: "2026-11-06T00:00", allDay: true,
                calendar: "生日"),
        ]
        let lines = CanvasTodoPlan.lines(events)
        #expect(lines.map(\.title) == ["产品评审会", "陈宏远 直播带货主播-男女不限 线下面试"])
        #expect(CanvasTopBar.withAllDay("今天 · 11月5日", events: events) == "今天 · 11月5日 · 结婚纪念日")
        #expect(CanvasTopBar.withAllDay("今天 · 11月5日", events: events + events) == "今天 · 11月5日 · 结婚纪念日 等")
        #expect(CanvasTopBar.withAllDay("今天 · 11月5日", events: []) == "今天 · 11月5日")
        #expect(CanvasTodoPlan.split(events[1]).name == "陈宏远")
        #expect(CanvasTodoPlan.split(events[0]).name == nil)
    }
}
