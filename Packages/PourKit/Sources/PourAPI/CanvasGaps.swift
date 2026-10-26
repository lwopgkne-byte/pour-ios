import PourCore

/// 一天的时间上没记的空当（docs/模块/产品优化.md R1.2）：点一下，输入框先填好「14:00 到 15:30，」，接着说做了什么
extension CanvasPlan {
    public struct Gap: Hashable, Sendable {
        public let start: String
        public let end: String

        public init(start: String, end: String) {
            self.start = start
            self.end = end
        }

        /// 输入框里先填的那一段
        public var prompt: String { "\(Show.clock(start)) 到 \(Show.clock(end))，" }
        /// 读屏念的：「补记 14:00 到 15:30」
        public var spoken: String { "补记 \(Show.clock(start)) 到 \(Show.clock(end))" }
    }

    /// 说了时间的事之间 `minimum` 分钟以上的空当，从 `from` 到 `until`：重叠的事合在一起算，
    /// 空当的两头就是前后那件事的结束和开始
    public static func gaps(
        _ spans: [(start: String, end: String)], from: String, until: String,
        minimum: Int = 30
    ) -> [Gap] {
        guard from < until else { return [] }
        var out: [Gap] = []
        var cursor = from
        func add(_ end: String) {
            let end = min(end, until)
            if end > cursor, PourDate.minutesBetween(cursor, end) >= minimum {
                out.append(Gap(start: cursor, end: end))
            }
        }
        for span in spans.sorted(by: { $0.start < $1.start }) {
            guard cursor < until else { break }
            add(span.start)
            cursor = max(cursor, span.end)
        }
        if cursor < until { add(until) }
        return out
    }

    /// 带子上能补记的空当：早上 6 点以前多半在睡觉，不算；今天到现在为止，以前的日子到 23 点；以后的日子没有
    public static func ribbonGaps(
        _ spans: [(start: String, end: String)], day: String, today: String, now: String
    ) -> [Gap] {
        guard day <= today else { return [] }
        let until = day == today ? now : "\(day)T23:00"
        return gaps(spans, from: "\(day)T06:00", until: until)
    }
}
