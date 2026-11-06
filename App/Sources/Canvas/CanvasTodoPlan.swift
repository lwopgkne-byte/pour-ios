import Foundation
import PourAPI
import PourCore

/// 画布上的待办卡怎么摆（待办 2.0 第 9 步，docs/todo-2.0 design/after-01-home）：最多 4 行，多了「还有 N 件 ›」；
/// 过点的在前 → 马上做（按时间）→ 日程 → 其余的待办按时间（不定时的最后）；全天的不在卡里。日程排在其余的待办前面：
/// 设计稿那天 15:00 的面试排在 12:30 的喝三瓶水前面（约好的事比自己排的事要紧）；
/// 开始时间一样、去掉开头的人名后名字一样的日程合成一行「2 场面试：潘志文、陈宏远」，右边「15:00 起」
struct CanvasTodoPlan {
    enum Item: Identifiable {
        case todo(API.TodoRow)
        case event(EventLine)

        var id: String {
            switch self {
            case .todo(let row): "todo.\(row.id)"
            case .event(let line): "event.\(line.id)"
            }
        }
    }

    /// 卡里的一行日程（合起来的几场也是一行）
    struct EventLine {
        let id: String
        let title: String
        let time: String
        /// 排的时候用的钟点（全天的是「00:00」）
        let start: String
    }

    var shown: [Item]
    /// 没摆出来、还没做完的待办有几件
    var more: Int

    static let limit = 4

    /// 排的时候：哪一组、组里的钟点
    private struct Keyed {
        let group: Int
        let clock: String
        let item: Item
    }

    static func make(rows: [API.TodoRow], events: [CalendarItem], now: String) -> CanvasTodoPlan {
        var keyed = rows.map { row in
            let key = Self.key(row, now: now)
            return Keyed(group: key.group, clock: key.clock, item: .todo(row))
        }
        keyed += lines(events).map { Keyed(group: 2, clock: $0.start, item: .event($0)) }  // 日程
        let sorted = keyed.enumerated().sorted { lhs, rhs in
            (lhs.element.group, lhs.element.clock, lhs.offset) < (rhs.element.group, rhs.element.clock, rhs.offset)
        }
        .map(\.element.item)
        let shown = Array(sorted.prefix(limit))
        let ids = Set(
            shown.compactMap { item -> Int? in
                if case .todo(let row) = item { row.id } else { nil }
            })
        return CanvasTodoPlan(shown: shown, more: rows.filter { !$0.done && !ids.contains($0.id) }.count)
    }

    /// 排在哪一组、组里按什么钟点：过点了 0，马上做 1，（日程 2），其余 3（不定时的排在其余的最后）
    static func key(_ row: API.TodoRow, now: String) -> (group: Int, clock: String) {
        if row.overdue || TodoListPlan.passed(row, now: now) { return (0, "\(row.day)T\(row.remindAt ?? "")") }
        let clock = row.remindAt ?? row.timeWindow?.nudge ?? "~"
        return (row.lane == .doNow ? 1 : 3, clock)
    }

    /// 日程排成几行：全天的一件一行；同一个钟点开始、去掉人名后一样的合成一行
    static func lines(_ events: [CalendarItem]) -> [EventLine] {
        // 全天的不进待办卡（写在顶上的日子后面，CanvasTopBar.withAllDay）
        var out: [EventLine] = []
        let timed = Dictionary(grouping: events.filter { !$0.allDay }) { String($0.start.suffix(5)) }
        for (start, group) in timed.sorted(by: { $0.key < $1.key }) {
            let parts = group.map(split)
            let rest = parts.first?.rest
            if group.count > 1, parts.allSatisfy({ $0.name != nil && $0.rest == rest }) {
                let short = TodoTimelinePlan.shortName(rest ?? "")
                let what = short.isEmpty ? "个日程" : "场\(short)"
                out.append(
                    EventLine(
                        id: group.map(\.id).joined(separator: "+"),
                        title: "\(group.count) \(what)：\(parts.compactMap(\.name).joined(separator: "、"))",
                        time: "\(start) 起", start: start))
            } else {
                out += group.map {
                    EventLine(id: $0.id, title: Show.spaced($0.title), time: TodayItem.time($0), start: start)
                }
            }
        }
        return out
    }

    /// 「潘志文 直播带货主播-男女不限 线下面试」→ 人名「潘志文」+ 其余（开头 2–4 个汉字、后面一个空格才算人名）
    static func split(_ event: CalendarItem) -> (name: String?, rest: String) {
        let parts = event.title.split(separator: " ", maxSplits: 1).map(String.init)
        guard parts.count == 2, (2...4).contains(parts[0].count),
            parts[0].unicodeScalars.allSatisfy({ (0x4E00...0x9FFF).contains($0.value) })
        else { return (nil, event.title) }
        return (parts[0], parts[1])
    }
}
