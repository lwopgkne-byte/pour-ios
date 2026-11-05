import Foundation
import PourAPI
import PourCore
import Testing

@testable import Pour

/// 待办 2.0 第 7 步（docs/todo-2.0）：四象限怎么摆——范围（今天、过点了、以后再说；明天的不进来）、
/// 每格的顺序、马上做多了留哪 3 件、排时间里今天到期的、拖的时候带的字
@Suite("待办 2.0：四象限")
@MainActor
struct TodoMatrixTests {
    static let today = "2026-10-27"

    private func row(_ id: Int, _ lane: TodoQuadrant, day: String = today, at time: String? = nil) -> API.TodoRow {
        var row = API.TodoRow(id: id, content: "事\(id)", day: day, remindAt: time)
        row.quadrant = lane.rawValue
        row.overdue = day < Self.today
        return row
    }

    private func page(_ rows: [API.TodoRow]) -> API.TodoPage {
        let key = { (row: API.TodoRow) in
            row.isSomeday ? "later" : row.day < Self.today ? "overdue" : row.day == Self.today ? "today" : "tomorrow"
        }
        let groups = ["overdue", "today", "tomorrow", "later"].map { name in
            API.TodoGroup(key: name, title: name, rows: rows.filter { key($0) == name })
        }
        return API.TodoPage(today: Self.today, groups: groups, open: rows.count)
    }

    /// 过点的在前，再按时间（时间段按开头的钟点），不定时的、以后再说的最后；明天的不进四象限
    @Test func cellsKeepTheOrder() {
        var later = row(5, .doNow)
        later.someday = true
        let rows = [
            row(1, .doNow, at: "17:00"), row(2, .doNow), later, row(4, .doNow, day: "2026-10-26"),
            row(6, .doNow, at: "09:30"), row(7, .doNow, day: "2026-10-28"),
        ]
        let plan = TodoMatrixPlan.make(page: page(rows), held: [:], now: "2026-10-27T11:35")
        #expect(plan.cells[.doNow]?.map(\.id) == [4, 6, 1, 2, 5])
        #expect(plan.unsorted.isEmpty)
        // 多了：留最前的 3 件，别的挪到排时间
        #expect(plan.overflow().map(\.id) == [2, 5])
    }

    /// 排时间里今天的、没定钟点也没定时间段的：今天到期（问要不要升，不自动挪）
    @Test func dueTodayOnlyForUntimedScheduleRows() {
        var window = row(3, .schedule)
        window.window = TimeWindow.afternoon.rawValue
        let rows = [row(1, .schedule), row(2, .schedule, at: "12:30"), window, row(4, .quick)]
        let plan = TodoMatrixPlan.make(page: page(rows), held: [:], now: "2026-10-27T11:35")
        #expect(plan.dueToday.map(\.id) == [1])
    }

    @Test func dragTextIsOurs() {
        #expect(TodoMatrixPlan.dragText(row(42, .quick)) == "pour-todo:42")
        #expect(TodoMatrixPlan.dragId("pour-todo:42") == 42)
        #expect(TodoMatrixPlan.dragId("随便一段字") == nil)
    }
}
