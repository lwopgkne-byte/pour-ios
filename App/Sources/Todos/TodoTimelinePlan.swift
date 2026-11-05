import Foundation
import PourAPI
import PourCore

/// 今天的时间线怎么摆（待办 2.0 第 8 步，docs/todo-2.0 design/after-04-timeline）：
/// 定了钟点的待办是小标签，日程是块（同一时段撞在一起的并排，最多 3 列，多了「+N」）；只有时间段或没时间的在上面的托盘里；
/// 现在以前没安排的钟点收成一条；1 小时以上的空档标出来，建议排一件进去（先排时间那格的，再是带时段的）；
/// 待办的钟点落在日程里写「撞上面试」。钟点都按一天里的第几分钟算
struct TodoTimelinePlan {
    struct Tag: Identifiable {
        let row: API.TodoRow
        let minute: Int
        /// 撞上的日程的简称（「面试」）；取不到是空字符串（写「时间撞了」）；没撞是 nil
        let clash: String?
        var id: Int { row.id }
    }

    struct Event: Identifiable {
        let item: CalendarItem
        let start: Int
        let end: Int
        /// 第几列、这一堆一共几列（最多 3）
        let column: Int
        let columns: Int
        var id: String { item.id }
    }

    struct Gap: Identifiable, Equatable {
        let start: Int
        let end: Int
        var id: Int { start }
        var text: String { "\(Self.clock(start))–\(Self.clock(end))" }

        static func clock(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }
    }

    /// 时间线从几点到几点（整点；默认 8 点到 22 点，有更早、更晚的跟着放大）
    var first: Int
    var last: Int
    /// 现在以前没安排、收起来的那几个钟头（first..<collapsedUntil）；没收是 nil
    var collapsedUntil: Int?
    var tags: [Tag]
    var events: [Event]
    /// 一堆里多出来没画的日程：在哪一分钟、几个
    var more: [(minute: Int, count: Int)]
    var gaps: [Gap]
    /// 还没排时间的（今天只有时间段的、不定时的）
    var tray: [API.TodoRow]
    /// 建议排进哪个空档的那一件
    var suggestion: Suggestion?
    /// 现在是今天的第几分钟（不是今天是 nil）
    var now: Int?

    /// 显示出来的第一个钟头（收起来的不算）
    var shownFrom: Int { collapsedUntil ?? first }

    static let maxColumns = 3
    /// 一个标签占的时间（算空档用）
    static let tagMinutes = 30

    static func make(page: API.TodoPage, held: [Int: String], events: [CalendarItem], now: String, expanded: Bool)
        -> TodoTimelinePlan
    {
        let today = page.today
        let rows = TodoBoard.sections(page, held: held).first { $0.key == "today" }?.rows ?? []
        let timed = events.filter { !$0.allDay && $0.start.hasPrefix(today) }
        let placed = Self.columns(timed, day: today)
        let tags = rows.compactMap { row -> Tag? in
            guard let clock = row.remindAt, let minute = Self.minute(clock) else { return nil }
            let hit = placed.events.first { minute >= $0.start && minute < $0.end }
            return Tag(row: row, minute: minute, clash: hit.map { Self.shortName($0.item.title) })
        }
        .sorted { $0.minute < $1.minute }
        let starts = placed.events.map(\.start) + tags.map(\.minute)
        let ends = placed.events.map(\.end) + tags.map { $0.minute + Self.tagMinutes }
        let first = min(8, (starts.min() ?? 8 * 60) / 60)
        let last = min(24, max(22, ((ends.max() ?? 0) + 59) / 60))
        let nowMinute = now.hasPrefix(today) ? PourDate.minutesOfDay(now) : nil
        var collapsed: Int?
        if let nowMinute, !expanded {
            let until = min((nowMinute - 30) / 60, (starts.min() ?? Int.max) / 60, last - 1)
            if until > first { collapsed = until }
        }
        let tray = rows.filter { !$0.done && $0.remindAt == nil && !$0.isSomeday }
        let busy = placed.events.map { ($0.start, $0.end) } + tags.map { ($0.minute, $0.minute + Self.tagMinutes) }
        let gaps = Self.gaps(busy: busy, from: max(first * 60, nowMinute ?? 0), until: min(last, 22) * 60)
        return TodoTimelinePlan(
            first: first, last: last, collapsedUntil: collapsed, tags: tags, events: placed.events,
            more: placed.more, gaps: gaps, tray: tray, suggestion: Self.suggest(gaps: gaps, tray: tray),
            now: nowMinute)
    }

    /// 「15:00」→ 900
    static func minute(_ clock: String) -> Int? {
        let parts = clock.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return parts[0] * 60 + parts[1]
    }

    // MARK: - 日程并排

    /// 一个日程从第几分钟到第几分钟（放在第几列）
    private struct Span {
        let item: CalendarItem
        let start: Int
        let end: Int
        var column = 0
    }

    /// 撞在一起的日程分列：按开始排，放进第一列空出来的；一堆（连着撞的）一共几列，最多画 3 列，多的数一下
    static func columns(_ items: [CalendarItem], day: String) -> (events: [Event], more: [(minute: Int, count: Int)]) {
        let spans = items.map { item -> Span in
            let start = item.start.hasPrefix(day) ? PourDate.minutesOfDay(item.start) ?? 0 : 0
            let end = item.end.hasPrefix(day) ? PourDate.minutesOfDay(item.end) ?? 24 * 60 : 24 * 60
            return Span(item: item, start: start, end: max(end, start + 15))
        }
        .sorted { ($0.start, -$0.end) < ($1.start, -$1.end) }
        var events: [Event] = []
        var more: [(minute: Int, count: Int)] = []
        var pile: [Span] = []
        var lanes: [Int] = []
        func close() {
            let count = min(lanes.count, maxColumns)
            for span in pile where span.column < maxColumns {
                events.append(
                    Event(item: span.item, start: span.start, end: span.end, column: span.column, columns: count))
            }
            let hidden = pile.filter { $0.column >= maxColumns }
            if let earliest = hidden.map(\.start).min() { more.append((earliest, hidden.count)) }
            pile = []
            lanes = []
        }
        for var span in spans {
            if !pile.isEmpty, span.start >= (lanes.max() ?? 0) { close() }
            if let free = lanes.firstIndex(where: { $0 <= span.start }) {
                lanes[free] = span.end
                span.column = free
            } else {
                lanes.append(span.end)
                span.column = lanes.count - 1
            }
            pile.append(span)
        }
        if !pile.isEmpty { close() }
        return (events, more)
    }

    /// 日程的简称（「撞上面试」）：认得出的说法取说法，取不到是空的（写「时间撞了」）
    static func shortName(_ title: String) -> String {
        let words = [
            "面试", "评审", "周会", "例会", "早会", "会议", "访谈", "培训", "上课", "电话", "约会", "聚餐", "体检", "开会", "直播",
            "复盘", "汇报", "讲座", "考试",
        ]
        return words.first { title.contains($0) } ?? ""
    }

    // MARK: - 空档

    /// 1 小时以上的空档（从现在往后到 22 点）：开头取到下一个半点
    static func gaps(busy: [(Int, Int)], from: Int, until: Int) -> [Gap] {
        var out: [Gap] = []
        var cursor = (from + 29) / 30 * 30
        for (start, end) in busy.sorted(by: { $0.0 < $1.0 }) {
            if start - cursor >= 60 { out.append(Gap(start: cursor, end: min(start, until))) }
            cursor = max(cursor, (end + 29) / 30 * 30)
            if cursor >= until { break }
        }
        if until - cursor >= 60 { out.append(Gap(start: cursor, end: until)) }
        return out.filter { $0.end - $0.start >= 60 }
    }

    /// 建议：把哪一件排进哪个空档的哪一刻
    struct Suggestion {
        let gap: Gap
        let row: API.TodoRow
        let at: Int
    }

    /// 建议排进去的一件：先排时间那格的，再是带时间段的；找第一个排得进的空档
    static func suggest(gaps: [Gap], tray: [API.TodoRow]) -> Suggestion? {
        let ordered =
            tray.filter { $0.lane == .schedule } + tray.filter { $0.lane != .schedule && $0.timeWindow != nil }
        for gap in gaps {
            for row in ordered {
                if let at = place(row, in: gap) { return Suggestion(gap: gap, row: row, at: at) }
            }
        }
        return nil
    }

    /// 排进这个空档的哪一刻：没时间段的从空档开头；有时间段的，时间段和空档重叠的那一截要有 1 小时，
    /// 排在时段开头的钟点（下午 14:00），钟点不在那一截里就排在那一截的开头
    static func place(_ row: API.TodoRow, in gap: Gap) -> Int? {
        guard let window = row.timeWindow else { return gap.start }
        let from = max(gap.start, window.hours.lowerBound * 60)
        let until = min(gap.end, (window.hours.upperBound + 1) * 60)
        guard until - from >= 60 else { return nil }
        let nudge = minute(window.nudge) ?? from
        return nudge >= from && nudge + 60 <= until ? nudge : from
    }
}
