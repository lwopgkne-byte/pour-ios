public import Foundation

/// 详情里改时间：改了开始，时长不变、结束跟着挪；只改结束，以结束为准重算时长；
/// 改了时长，结束跟着开始走。凌晨（日界线以前）的钟点算这一天的第二天
public enum WebEdit {
    /// 「8:30」「08:30」→ 当日分钟数；不像钟点返回 nil
    public static func clock(_ text: String) -> Int? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]), (0...23).contains(hour),
            (0...59).contains(minute), parts[1].count == 2
        else { return nil }
        return hour * 60 + minute
    }

    /// 这一天的某个钟点（日界线以前的算第二天）
    static func moment(_ day: DayString, _ minutes: Int, boundary: Int) -> LocalDateTime {
        let date = minutes < boundary ? PourDate.addDays(day, 1) : day
        return String(format: "%@T%02d:%02d", date, minutes / 60, minutes % 60)
    }

    public static func setStart(
        _ event: RecordData.Event, day: DayString, minutes: Int, boundary: Int = PourDate.defaultBoundary
    ) -> RecordData.Event {
        var next = event
        let start = moment(day, minutes, boundary: boundary)
        next.start = start
        if let duration = event.durationMin {
            next.end = PourDate.addMinutes(start, duration)
        } else if let end = event.end {
            let length = PourDate.minutesBetween(start, end)
            next.durationMin = length > 0 ? length : nil
        }
        return next
    }

    public static func setEnd(
        _ event: RecordData.Event, day: DayString, minutes: Int, boundary: Int = PourDate.defaultBoundary
    ) -> RecordData.Event {
        var next = event
        var end = moment(day, minutes, boundary: boundary)
        if let start = event.start {
            // 结束早于开始：跨过了零点（睡觉 23:30 → 7:00）
            if end <= start { end = PourDate.addMinutes(end, 24 * 60) }
            next.durationMin = PourDate.minutesBetween(start, end)
        }
        next.end = end
        return next
    }

    public static func setDuration(_ event: RecordData.Event, minutes: Int) -> RecordData.Event {
        var next = event
        next.durationMin = minutes > 0 ? minutes : nil
        if let start = event.start { next.end = minutes > 0 ? PourDate.addMinutes(start, minutes) : event.end }
        return next
    }

    /// 「儿子、老公 朋友」→ ["儿子", "老公", "朋友"]
    public static func words(_ text: String) -> [String] {
        var seen: [String] = []
        for word in text.split(whereSeparator: { "、，, ".contains($0) || $0.isNewline }) {
            let item = word.trimmingCharacters(in: .whitespaces)
            if !item.isEmpty && !seen.contains(item) { seen.append(item) }
        }
        return seen
    }
}
