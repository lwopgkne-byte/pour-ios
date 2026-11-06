import Foundation
import PourAPI
import PourCore

/// 四象限怎么摆（待办 2.0 第 7 步）：今天的、过点了的、没定日子的（以后再说）；日程不进来。
/// 每格过点的在前（越早过的越前），再按时间（钟点、时间段开头），不定时的、以后再说的最后；这一次刚勾掉的留在原地
struct TodoMatrixPlan {
    var cells: [TodoQuadrant: [API.TodoRow]]
    /// 还没分（格子下面的托盘）
    var unsorted: [API.TodoRow]
    /// 排时间里到了日子还没定时间的：卡片上写「今天到期」（不问要不要升，也不自动挪）
    var dueToday: [API.TodoRow]

    /// 每格最多摆几件（多了「还有 N 件」）
    static let shown = 4
    /// 马上做超过几件算多
    static let crowd = 3

    static func make(page: API.TodoPage, held: [Int: String], now: String) -> TodoMatrixPlan {
        let sections = TodoBoard.sections(page, held: held)
        let rows =
            sections.filter { ["overdue", "today"].contains($0.key) }.flatMap(\.rows)
            + (sections.first { $0.key == "later" }?.rows.filter(\.isSomeday) ?? [])
        let sorted = rows.enumerated().sorted { lhs, rhs in
            let left = order(lhs.element, now: now)
            let right = order(rhs.element, now: now)
            return (left.0, left.1, lhs.offset) < (right.0, right.1, rhs.offset)
        }
        .map(\.element)
        var cells: [TodoQuadrant: [API.TodoRow]] = [:]
        for lane in TodoQuadrant.sorted { cells[lane] = sorted.filter { $0.lane == lane } }
        let due = (cells[.schedule] ?? []).filter { row in
            !row.done && !row.overdue && !row.isSomeday && row.day == page.today && row.remindAt == nil
                && row.timeWindow == nil
        }
        return TodoMatrixPlan(cells: cells, unsorted: sorted.filter { $0.lane == .unsorted }, dueToday: due)
    }

    /// 排在第几：过点了的 0（按本来的时刻），定了钟点、时间段的 1（按钟点），不定时的 2，以后再说的 3
    static func order(_ row: API.TodoRow, now: String) -> (Int, String) {
        if row.overdue || TodoListPlan.passed(row, now: now) { return (0, "\(row.day)T\(row.remindAt ?? "")") }
        if row.isSomeday { return (3, "") }
        if let clock = row.remindAt ?? row.timeWindow?.nudge { return (1, clock) }
        return (2, "")
    }

    /// 这一格还没做完的
    func open(_ lane: TodoQuadrant) -> [API.TodoRow] { (cells[lane] ?? []).filter { !$0.done } }

    /// 马上做多了：最要紧的 3 件留下（就是排在最前的 3 件），其余的挪到排时间
    func overflow() -> [API.TodoRow] { Array(open(.doNow).dropFirst(Self.crowd)) }

    /// 拖的时候带的字（只认自己 App 里的）
    static func dragText(_ row: API.TodoRow) -> String { "pour-todo:\(row.id)" }
    static func dragId(_ text: String) -> Int? {
        text.hasPrefix("pour-todo:") ? Int(text.dropFirst("pour-todo:".count)) : nil
    }
}

extension AppModel {
    /// 放进一格（按住的菜单、四象限里拖、托盘里点）：你选的就不再是猜的；先改界面再发，轻提示能撤销
    func file(_ rows: [API.TodoRow], into lane: TodoQuadrant) {
        let moving = rows.filter { $0.lane != lane }
        guard !moving.isEmpty else { return }
        for row in moving { editTodo(row.id, quadrant: lane) }
        let what = moving.count == 1 ? "「\(moving[0].content)」" : "\(moving.count) 件"
        toast("\(what)放进\(lane.title)", action: "撤销") { [weak self] in
            for row in moving { self?.editTodo(row.id, quadrant: row.lane) }
        }
    }
}
