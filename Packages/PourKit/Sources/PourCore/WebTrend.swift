public import Foundation

/// 详情里的「最近 7 天」（网页版 server/src/services/trend.ts 原样）：一条记录所在那天往前 7 天，同类活动每天的量。
/// 心情每条一个点（一天几条就几个）；事件优先看时长，没有时长看第一个数量，都没有就数次数
public struct WebTrend: Hashable, Sendable {
    public struct Point: Hashable, Sendable {
        public var day: DayString
        public var value: Double?
        /// 心情：这一天每一条的级别
        public var values: [Double]
    }

    public var label: String
    /// 分钟、公里……；心情是 mood
    public var unit: String
    public var points: [Point]

    public static func of(_ entry: Entry, among all: [Entry]) -> WebTrend? {
        let days = (0..<7).map { PourDate.addDays(entry.day, $0 - 6) }
        switch entry.data {
        case .mood:
            let points = days.map { day -> Point in
                let levels = all.filter { $0.day == day }.compactMap { item -> Double? in
                    if case .mood(let mood) = item.data { Double(mood.level) } else { nil }
                }
                let average = levels.isEmpty ? nil : levels.reduce(0, +) / Double(levels.count)
                return Point(day: day, value: average, values: levels)
            }
            return WebTrend(label: "心情", unit: "mood", points: points)
        case .event(let event):
            let first = event.metrics.first
            let unit = event.durationMin != nil ? "分钟" : first?.unit ?? "次"
            let points = days.map { day -> Point in
                let values = all.filter { $0.day == day }.compactMap { item -> Double? in
                    guard case .event(let other) = item.data, same(other, event) else { return nil }
                    if event.durationMin != nil { return other.durationMin.map(Double.init) }
                    if let first {
                        return other.metrics.first { $0.name == first.name || $0.unit == first.unit }?.value
                    }
                    return 1
                }
                return Point(day: day, value: values.isEmpty ? nil : values.reduce(0, +), values: [])
            }
            guard points.contains(where: { $0.value != nil }) else { return nil }
            return WebTrend(label: event.label, unit: unit, points: points)
        default:
            return nil
        }
    }

    /// 同一种活动：同类别，名称相同或互相包含
    private static func same(_ lhs: RecordData.Event, _ rhs: RecordData.Event) -> Bool {
        guard lhs.category == rhs.category else { return false }
        let left = lhs.label.replacingOccurrences(of: " ", with: "").lowercased()
        let right = rhs.label.replacingOccurrences(of: " ", with: "").lowercased()
        return left == right || left.contains(right) || right.contains(left)
    }
}
