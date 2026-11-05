import Foundation
import PourAPI
import PourCore
import Testing

@testable import Pour

/// 待办 2.0 第 8 步（docs/todo-2.0）：时间线怎么摆——撞在一起的日程并排、现在以前没安排的收起来、空档和建议、
/// 撞上日程写简称、还没排时间的托盘
@Suite("待办 2.0：时间线")
@MainActor
struct TodoTimelineTests {
    static let today = "2026-10-27"

    private func event(_ id: String, _ title: String, _ start: String, _ end: String) -> CalendarItem {
        CalendarItem(
            id: id, title: title, start: "\(Self.today)T\(start)", end: "\(Self.today)T\(end)", allDay: false,
            calendar: "工作")
    }

    private func page(_ rows: [API.TodoRow]) -> API.TodoPage {
        API.TodoPage(
            today: Self.today, groups: [API.TodoGroup(key: "today", title: "今天", rows: rows)], open: rows.count)
    }

    /// 设计稿那一天：11:35；喝水 11:12、喝三瓶水 12:30、接小孩 17:00；两场面试 15:00 起并排；回复客户电话只说了下午
    @Test func theDesignDay() {
        let water = API.TodoRow(id: 1, content: "喝水", day: Self.today, remindAt: "11:12")
        var bottles = API.TodoRow(id: 2, content: "喝三瓶水", day: Self.today, remindAt: "12:30")
        bottles.quadrant = TodoQuadrant.schedule.rawValue
        let kid = API.TodoRow(id: 3, content: "接小孩", day: Self.today, remindAt: "17:00")
        var call = API.TodoRow(id: 4, content: "回复客户电话", day: Self.today, window: .afternoon)
        call.quadrant = TodoQuadrant.doNow.rawValue
        let lunch = API.TodoRow(id: 5, content: "吃午饭", day: Self.today)
        let events = [
            event("a", "潘志文 直播带货主播-男女不限 线下面试", "15:00", "18:00"),
            event("b", "陈宏远 直播带货主播-男女不限 线下面试", "15:00", "18:30"),
        ]
        let plan = TodoTimelinePlan.make(
            page: page([water, bottles, kid, call, lunch]), held: [:], events: events, now: "2026-10-27T11:35",
            expanded: false)
        // 08:00–11:00 没安排，收起来
        #expect(plan.first == 8 && plan.collapsedUntil == 11)
        // 两场面试并排两列
        #expect(plan.events.map(\.column).sorted() == [0, 1] && plan.events.allSatisfy { $0.columns == 2 })
        // 接小孩 17:00 落在面试里
        #expect(plan.tags.first { $0.row.id == 3 }?.clash == "面试")
        #expect(plan.tags.first { $0.row.id == 1 }?.clash == nil)
        // 13:00–15:00 空着，建议排「回复客户电话」（带下午的时间段）
        #expect(plan.gaps.first?.text == "13:00–15:00")
        #expect(plan.suggestion?.row.id == 4)
        // 托盘：只说了时间段的、没说时间的
        #expect(Set(plan.tray.map(\.id)) == [4, 5])
        // 展开以后不收
        let open = TodoTimelinePlan.make(
            page: page([water]), held: [:], events: [], now: "2026-10-27T11:35", expanded: true)
        #expect(open.collapsedUntil == nil)
    }

    /// 四场撞在一起：画 3 列，多的一场写「+1」
    @Test func atMostThreeColumns() {
        let events = (0..<4).map { event("e\($0)", "会议 \($0)", "10:00", "11:00") }
        let placed = TodoTimelinePlan.columns(events, day: Self.today)
        #expect(placed.events.count == 3 && placed.events.allSatisfy { $0.columns == 3 })
        #expect(placed.more.first?.count == 1)
    }

    /// 空档：现在以后、1 小时以上，开头取到下一个半点；建议先排「排时间」那格的
    @Test func gapsAndSuggestion() {
        let gaps = TodoTimelinePlan.gaps(busy: [(15 * 60, 16 * 60)], from: 11 * 60 + 35, until: 22 * 60)
        #expect(gaps.map(\.text) == ["12:00–15:00", "16:00–22:00"])
        var schedule = API.TodoRow(id: 1, content: "写周报", day: Self.today)
        schedule.quadrant = TodoQuadrant.schedule.rawValue
        let evening = API.TodoRow(id: 2, content: "收衣服", day: Self.today, window: .evening)
        #expect(TodoTimelinePlan.suggest(gaps: gaps, tray: [evening, schedule])?.row.id == 1)
        // 晚上的只建议进晚上的空档
        #expect(TodoTimelinePlan.suggest(gaps: [gaps[0]], tray: [evening]) == nil)
    }

    @Test func shortNames() {
        #expect(TodoTimelinePlan.shortName("潘志文 直播带货主播-男女不限 线下面试") == "面试")
        #expect(TodoTimelinePlan.shortName("产品评审会") == "评审")
        #expect(TodoTimelinePlan.shortName("和小李喝咖啡").isEmpty)
    }
}
