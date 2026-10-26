import Foundation
import PourAPI
import PourCore
import Testing

/// 待办和日程合在一张卡里（docs/模块/产品优化.md R6）：同一件只显示一次（你说的待办为准），全天的放最上面，别的按时间排
@Suite("待办和日程")
struct AgendaPlanTests {
    @Test func sameThingShowsOnce() throws {
        let call = try todo(1, "给客户回个电话", remind: "2026-10-26T10:00")
        let events = [
            item("a", "给客户回电话", "10:10"),  // 差 10 分钟、名字像：同一件
            item("b", "给客户回电话", "11:00"),  // 差一个小时：不是
            item("c", "项目周会", "10:05"),  // 时间近、名字不像：不是
        ]
        #expect(AgendaPlan.visible(events, todos: [call]).map(\.id) == ["b", "c"])
        let dentist = try todo(2, "看牙医", remind: "2026-10-26T15:00")
        #expect(AgendaPlan.visible([item("d", "牙医", "15:00")], todos: [dentist]).isEmpty)
        // 没说几点的待办：比不了时间，两样都显示
        let plain = try todo(3, "看牙医")
        #expect(AgendaPlan.visible([item("d", "牙医", "15:00")], todos: [plain]).count == 1)
    }

    @Test func allDayOnTopOthersByTime() throws {
        let morning = try todo(1, "交电费", remind: "2026-10-26T09:00")
        let later = try todo(2, "买牛奶")
        let events = [
            item("e", "看牙医", "15:00"),
            item("f", "站会", "08:30"),
            CalendarItem(
                id: "g", title: "小李生日", start: "2026-10-26T00:00", end: "2026-10-27T00:00", allDay: true,
                calendar: "生日"),
        ]
        let plan = AgendaPlan.rows(todos: [later, morning], events: events)
        #expect(plan.allDay.map(\.title) == ["小李生日"])
        #expect(plan.rows.map(\.id) == ["event-f", "todo-1", "event-e", "todo-2"])
    }

    // MARK: -

    private func item(_ id: String, _ title: String, _ clock: String) -> CalendarItem {
        CalendarItem(
            id: id, title: title, start: "2026-10-26T\(clock)", end: PourDate.addMinutes("2026-10-26T\(clock)", 60),
            allDay: false, calendar: "工作")
    }

    private func todo(_ id: Int, _ content: String, remind: String? = nil) throws -> API.Entry {
        var data: [String: Any] = ["content": content, "done": false]
        if let remind { data["remindAt"] = remind }
        let object: [String: Any] = ["id": id, "day": "2026-10-26", "kind": "todo", "category": "todo", "data": data]
        return try JSONDecoder().decode(API.Entry.self, from: JSONSerialization.data(withJSONObject: object))
    }
}
