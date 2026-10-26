public import PourCore

/// 待办和日程合在一张卡里（docs/模块/产品优化.md R6）：全天的（节假日、生日）放最上面一行；
/// 别的和待办按时间排；和你说的待办是同一件的（时间差 15 分钟以内、名字像）只显示待办
public enum AgendaPlan {
    /// 一行：你说的待办，或者日历里的一件
    public enum Row: Identifiable, Hashable, Sendable {
        case todo(API.Entry)
        case event(CalendarItem)

        public var id: String {
            switch self {
            case .todo(let entry): "todo-\(entry.id)"
            case .event(let item): "event-\(item.id)"
            }
        }
    }

    /// 同一件的时间差：15 分钟以内
    static let nearMinutes = 15

    /// 卡里的几行：全天的单放；其余按钟点排（有提醒的待办按提醒的钟点，日程按开始），没有钟点的待办按说的先后放在后面
    public static func rows(todos: [API.Entry], events: [CalendarItem]) -> (allDay: [CalendarItem], rows: [Row]) {
        let shown = visible(events, todos: todos)
        let timed = shown.filter { !$0.allDay }
        let ordered = CanvasPlan.todoOrder(todos)
        var rows: [(key: String, row: Row)] = timed.map { (Self.clock($0.start), .event($0)) }
        for (index, entry) in ordered.enumerated() {
            let remind = remindAt(entry).map(clock)
            rows.append((remind ?? "~\(String(format: "%04d", index))", .todo(entry)))
        }
        let sorted = rows.enumerated().sorted { lhs, rhs in
            lhs.element.key == rhs.element.key ? lhs.offset < rhs.offset : lhs.element.key < rhs.element.key
        }
        return (shown.filter(\.allDay), sorted.map(\.element.row))
    }

    /// 日历里要显示的：和你说的待办是同一件的不再显示（你说的为准）
    public static func visible(_ events: [CalendarItem], todos: [API.Entry]) -> [CalendarItem] {
        events.filter { event in
            !todos.contains { todo in
                guard case .todo(let data) = todo.data else { return false }
                return same(event, data)
            }
        }
    }

    /// 是不是同一件：都有钟点、相差 15 分钟以内，名字像（一个包含另一个，或者有一段至少两个字、占短的那个一半的一样）
    public static func same(_ event: CalendarItem, _ todo: API.TodoData) -> Bool {
        guard !event.allDay, let remind = todo.remindAt else { return false }
        guard abs(PourDate.minutesBetween(event.start, remind)) <= nearMinutes else { return false }
        return similar(event.title, todo.content)
    }

    static func similar(_ lhs: String, _ rhs: String) -> Bool {
        let left = Array(normalized(lhs))
        let right = Array(normalized(rhs))
        guard !left.isEmpty, !right.isEmpty else { return false }
        let shorter = min(left.count, right.count)
        return longestCommon(left, right) >= max(min(2, shorter), (shorter + 1) / 2)
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased().filter { !$0.isWhitespace && !$0.isPunctuation }
    }

    /// 两段字最长的一段一样的有几个字
    private static func longestCommon(_ lhs: [Character], _ rhs: [Character]) -> Int {
        var best = 0
        var previous = [Int](repeating: 0, count: rhs.count + 1)
        for left in lhs {
            var current = [Int](repeating: 0, count: rhs.count + 1)
            for (index, right) in rhs.enumerated() where left == right {
                current[index + 1] = previous[index] + 1
                best = max(best, current[index + 1])
            }
            previous = current
        }
        return best
    }

    private static func remindAt(_ entry: API.Entry) -> String? {
        if case .todo(let todo) = entry.data { todo.remindAt } else { nil }
    }

    /// 「2026-10-26T15:00」→「15:00」（排先后用）
    private static func clock(_ local: String) -> String { String(local.suffix(5)) }
}
