import Foundation
import PourAPI
import PourCore
import PourDesign

/// 待办 2.0 清单页怎么摆（docs/todo-2.0 第 4 步）：过点了（今天到点没做的 + 前几天没做完的）、今天（全天的日程最前，
/// 不定时的在上，别的按时间、日程穿插；放一放的折成一行放最后）、明天、这周、以后、已完成。
/// 「过点了」跟着时间变，在手机上算（服务器的分组不动）；这一次刚勾掉的留在原地
struct TodoListPlan {
    /// 过点了：今天到点的在前（越早过的越前），再是前几天的（最近的在前）
    var late: [API.TodoRow]
    /// 今天：待办和日程
    var today: [TodayItem]
    /// 今天里放一放的（折成一行「放一放 · 3 件 ›」）
    var later: [API.TodoRow]
    /// 明天、这周、以后（服务器给的组）
    var ahead: [API.TodoGroup]
    var done: API.TodoGroup?

    static func make(page: API.TodoPage, held: [Int: String], events: [CalendarItem], now: String) -> TodoListPlan {
        let sections = TodoBoard.sections(page, held: held)
        let overdue = sections.first { $0.key == "overdue" }?.rows ?? []
        let todayRows = sections.first { $0.key == "today" }?.rows ?? []
        let due = todayRows.filter { Self.passed($0, now: now) }.sorted { ($0.remindAt ?? "") < ($1.remindAt ?? "") }
        let rest = todayRows.filter { !Self.passed($0, now: now) }
        return TodoListPlan(
            late: due + overdue,
            today: TodayItem.merge(rest.filter { $0.lane != .later }, events: events),
            later: rest.filter { $0.lane == .later },
            ahead: sections.filter { ["tomorrow", "week", "later"].contains($0.key) },
            done: sections.first { $0.key == "done" })
    }

    /// 今天的、有具体钟点、钟点已经过了（只说了时间段的不算过点）
    static func passed(_ row: API.TodoRow, now: String) -> Bool {
        guard let clock = row.remindAt else { return false }
        return "\(row.day)T\(clock)" < now
    }

    /// 过点了的往后挪到哪：中午以前「挪到下午」，傍晚以前「挪到晚上」，晚上就不给（只有明天再说、不做了）
    static func laterToday(now: String) -> TodoMove? {
        let hour = Int(now.dropFirst(11).prefix(2)) ?? 0
        if hour < 12 { return .afternoon }
        return hour < 18 ? .evening : nil
    }

    /// 标题下面那一行：「今天还有 5 件 · 完成 1 件」（还有几件 = 过点了 + 今天没做完的；完成的是今天勾的）
    func counts(page: API.TodoPage) -> (left: Int, done: Int) {
        let left = late.filter { !$0.done }.count + today.filter(\.isOpenTodo).count + later.filter { !$0.done }.count
        let finished = page.groups.flatMap(\.rows).filter { $0.done && TodoListPlan.doneOn($0, day: page.today) }
        return (left, Set(finished.map(\.id)).count)
    }

    /// 还没到点的提醒有几个（钟点、时间段开头）：演示数据不排系统通知，按单子数
    static func reminders(_ page: API.TodoPage, now: String) -> Int {
        page.groups.flatMap(\.rows).filter { row in
            guard !row.done, !row.isSomeday else { return false }
            if let clock = row.remindAt { return "\(row.day)T\(clock)" > now }
            if let window = row.timeWindow { return "\(row.day)T\(window.nudge)" > now }
            return false
        }.count
    }

    /// 是不是这一天勾掉的（做完的时刻是世界时，换成手机上的日子比）
    static func doneOn(_ row: API.TodoRow, day: String) -> Bool {
        guard let doneAt = row.doneAt else { return false }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: doneAt) ?? ISO8601DateFormatter().date(from: doneAt) else { return true }
        return PourDate.localDateTime(date, in: .current).hasPrefix(day)
    }
}

/// 过点了往哪挪（行下面的小按钮、组标题旁的「全部挪到…」）
enum TodoMove: Equatable {
    case afternoon, evening, tomorrow

    var title: String {
        switch self {
        case .afternoon: "挪到下午"
        case .evening: "挪到晚上"
        case .tomorrow: "明天再说"
        }
    }
}

extension TodayItem {
    /// 还没做完的待办（日程不算）
    var isOpenTodo: Bool {
        if case .todo(let row) = self { return !row.done }
        return false
    }
}

extension AppModel {
    /// 过点了的挪一挪：挪到今天下午 / 晚上（记成时间段，到时段开头轻提醒），或者明天再说（钟点照旧挪到明天）。
    /// 先改界面再发；轻提示能撤销（挪回原来的日子、钟点、时间段）
    func move(_ rows: [API.TodoRow], to target: TodoMove) {
        guard !rows.isEmpty else { return }
        let before = rows
        for row in rows {
            switch target {
            case .afternoon: editTodo(row.id, day: today, window: .some(.afternoon))
            case .evening: editTodo(row.id, day: today, window: .some(.evening))
            case .tomorrow: editTodo(row.id, day: PourDate.addDays(today, 1))
            }
        }
        let what = rows.count == 1 ? "「\(rows[0].content)」" : "\(rows.count) 件"
        let done =
            switch target {
            case .afternoon: "\(what)挪到下午了"
            case .evening: "\(what)挪到晚上了"
            case .tomorrow: "\(what)挪到明天了"
            }
        toast(done, action: "撤销") { [weak self] in
            for old in before {
                self?.editTodo(old.id, day: old.day, time: .some(old.remindAt), window: .some(old.timeWindow))
            }
        }
    }
}

/// 今天这一组里的一样：待办，或者日历里的日程（只读）
enum TodayItem: Identifiable {
    case todo(API.TodoRow)
    case event(CalendarItem)

    var id: String {
        switch self {
        case .todo(let row): "todo.\(row.id)"
        case .event(let event): "event.\(event.id)"
        }
    }

    /// 待办 2.0：全天的日程最前，不定时的待办在上，别的按时间排（待办按钟点、时间段按开头的钟点，日程按开始）；
    /// 日程和你说的待办是同一件的只显示待办（和画布的待办卡一样，AgendaPlan.same）
    static func merge(_ rows: [API.TodoRow], events: [CalendarItem]) -> [TodayItem] {
        let timed = events.filter { event in
            !event.allDay
                && !rows.contains { row in
                    AgendaPlan.same(event, title: row.content, remindAt: row.remindAt.map { "\(row.day)T\($0)" })
                }
        }
        let allDay = events.filter(\.allDay).map(TodayItem.event)
        let items = (rows.map(TodayItem.todo) + timed.map(TodayItem.event)).enumerated()
            .sorted { ($0.element.clock ?? "", $0.offset) < ($1.element.clock ?? "", $1.offset) }
            .map(\.element)
        return allDay + items
    }

    private var clock: String? {
        switch self {
        case .todo(let row): row.remindAt ?? row.timeWindow?.nudge
        case .event(let event): String(event.start.suffix(5))
        }
    }

    /// 「14:00–15:30」「全天」（待办 2.0 第 2 步：「日历」小标签去掉，只留左边的日历图标）
    static func time(_ event: CalendarItem) -> String {
        event.allDay ? "全天" : "\(event.start.suffix(5))–\(event.end.suffix(5))"
    }
}

extension CalendarLine {
    /// 日历里的一件（待办页、时间线）：日历图标、一行标题、右边几点到几点或「全天」
    init(event: CalendarItem) {
        self.init(Show.spaced(event.title), time: TodayItem.time(event))
    }
}
