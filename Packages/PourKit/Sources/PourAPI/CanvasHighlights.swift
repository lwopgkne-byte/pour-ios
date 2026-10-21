import Foundation
import PourCore

extension CanvasPlan {
    /// 今天的样子里的一个亮点：「上班 11 小时」「喂奶 7 次」「花了 ¥383」「血压 135/85」
    public struct Highlight: Hashable, Sendable {
        /// 点了滚到哪张卡
        public let target: String
        public let label: String
        public let parts: [Part]
        /// 数字前面的「¥」
        public let prefix: String?
    }

    /// 一个数和它的单位
    public struct Part: Hashable, Sendable {
        public let number: String
        public let unit: String

        public init(number: String, unit: String) {
            self.number = number
            self.unit = unit
        }
    }

    /// 这一天的心情：给今天的样子那张卡的底色用（没记心情就是 none，不猜）
    public enum Mood: Sendable, Hashable {
        case good, plain, low, mixed, none
    }

    /// 数量的单位（「跑步 3 公里」「读书 30 页」）；时长、次数、钱、身体的数不在这里
    static let quantityUnits = ["公里", "千米", "米", "页", "杯", "步", "个", "篇", "章", "集", "首", "道", "单", "件"]

    /// 最多 3 个亮点，按这个顺序挑、有才挑：花时间最多的一类 → 次数最多的一类 → 钱 → 身体的数 → 数量。
    /// 只有一件事的一天不放亮点；同一个名字只放一次（「跑步 32 分」有了就不再放「跑步 5 公里」）；
    /// 心情写在今天的样子右上角，不再算一个亮点
    public static func highlights(_ entries: [API.Entry], _ categories: [API.Category]) -> [Highlight] {
        guard entries.count > 1 else { return [] }
        let all = cards(entries, categories)
        let found =
            [longest(all, categories), mostTimes(all, categories)].compactMap(\.self)
            + money(entries, categories) + [body(all), quantity(all)].compactMap(\.self)
        var labels = Set<String>()
        return Array(found.filter { labels.insert($0.label).inserted }.prefix(3))
    }

    /// 花时间最多的一类：「上班 11 小时」「学习 6 小时」「睡了 6 小时 50 分」
    static func longest(_ cards: [Card], _ categories: [API.Category]) -> Highlight? {
        let timed = cards.filter { [.duration, .sleep].contains($0.template) }
        let scored = timed.map { card in (card, card.entries.compactMap(event).reduce(0) { $0 + minutes($1) }) }
        guard let best = scored.max(by: { $0.1 < $1.1 }), best.1 > 0 else { return nil }
        let label = best.0.template == .sleep ? "睡了" : name(best.0, categories)
        return Highlight(target: best.0.id, label: label, parts: durationParts(best.1), prefix: nil)
    }

    /// 次数最多的一类（2 次以上）：同一件事最多的那件「喂奶 7 次」；都不一样时写类别名和一共几次
    static func mostTimes(_ cards: [Card], _ categories: [API.Category]) -> Highlight? {
        let counted = cards.filter { $0.template == .count && $0.entries.count >= 2 }
        guard let card = counted.max(by: { $0.entries.count < $1.entries.count }) else { return nil }
        let labels = Dictionary(grouping: card.entries.compactMap(event), by: \.label).mapValues(\.count)
        let times = { (count: Int) in [Part(number: "\(count)", unit: "次")] }
        if let top = labels.max(by: { ($0.value, $1.key) < ($1.value, $0.key) }), top.value >= 2 {
            return Highlight(target: card.id, label: top.key, parts: times(top.value), prefix: nil)
        }
        return Highlight(target: card.id, label: name(card, categories), parts: times(card.entries.count), prefix: nil)
    }

    /// 钱：今天日常花了多少、收入多少（都有就两个，多的在前）；每月固定扣的（房贷、房租）不算，和钱的汇总卡一样
    static func money(_ entries: [API.Entry], _ categories: [API.Category]) -> [Highlight] {
        let (spent, earned) = Show.money(entries.compactMap(event).map(withoutMonthly))
        let target = moneySummary(entries)?.id ?? moneyCard(entries, categories)
        let spend = spent > 0 ? Highlight(target: target, label: "花了", parts: [yuan(spent)], prefix: "¥") : nil
        let income = earned > 0 ? Highlight(target: target, label: "收入", parts: [yuan(earned)], prefix: "¥") : nil
        return (earned > spent ? [income, spend] : [spend, income]).compactMap(\.self)
    }

    /// 没有单独的钱的卡时，点「花了」滚到那一笔所在的类别卡
    static func moneyCard(_ entries: [API.Entry], _ categories: [API.Category]) -> String {
        entries.first { entry in (event(entry)?.metrics ?? []).contains(where: Show.isMoney) }
            .map { Show.group($0, categories) } ?? moneyKey
    }

    /// 身体的数：最后量的那一次（血压写「135/85」）
    static func body(_ cards: [Card]) -> Highlight? {
        for card in cards {
            let events = card.entries.compactMap(event).filter(hasBody)
            guard let latest = events.max(by: { ($0.start ?? "") < ($1.start ?? "") }) else { continue }
            return bodyHighlight(latest, target: card.id)
        }
        return nil
    }

    /// 一次身体的数：血压的高压、低压合成「135/85」，别的写数和单位
    public static func bodyHighlight(_ event: API.EventData, target: String) -> Highlight? {
        let metrics = (event.metrics ?? []).filter(isBody)
        let high = metrics.first { ["收缩压", "高压"].contains($0.name) || $0.name.hasSuffix("收缩压") }
        let low = metrics.first { ["舒张压", "低压"].contains($0.name) || $0.name.hasSuffix("舒张压") }
        if let high, let low {
            let text = "\(Show.amount(high.value))/\(Show.amount(low.value))"
            return Highlight(target: target, label: "血压", parts: [Part(number: text, unit: "")], prefix: nil)
        }
        guard let first = metrics.first else { return nil }
        let part = Part(number: Show.amount(first.value), unit: first.unit)
        return Highlight(target: target, label: first.name, parts: [part], prefix: nil)
    }

    /// 数量：同一件事、同一个单位加起来，第一个有的（「跑步 3 公里」）
    static func quantity(_ cards: [Card]) -> Highlight? {
        for card in cards {
            for event in card.entries.compactMap(event) {
                guard let metric = (event.metrics ?? []).first(where: { quantityUnits.contains($0.unit) }) else {
                    continue
                }
                let total = card.entries.compactMap(Self.event).filter { $0.label == event.label }
                    .flatMap { $0.metrics ?? [] }.filter { $0.unit == metric.unit }.reduce(0) { $0 + $1.value }
                let part = Part(number: Show.amount(total), unit: metric.unit)
                return Highlight(target: card.id, label: event.label, parts: [part], prefix: nil)
            }
        }
        return nil
    }

    /// 这一天的心情：既有好的又有不好的是「有起有落」，否则看平均
    public static func mood(_ entries: [API.Entry]) -> Mood {
        mood(levels: entries.compactMap { if case .mood(let mood) = $0.data { mood.mood } else { nil } })
    }

    /// 几条心情的五级合成这一天的心情（回顾里的「这一天的样子」也用）
    public static func mood(levels: [Double]) -> Mood {
        guard !levels.isEmpty else { return .none }
        if levels.contains(where: { $0 >= 4 }) && levels.contains(where: { $0 <= 2 }) { return .mixed }
        let average = levels.reduce(0, +) / Double(levels.count)
        return average >= 3.5 ? .good : (average <= 2.5 ? .low : .plain)
    }

    // MARK: - 小帮手

    /// 去掉每月固定扣的钱（`monthly`）：今天日常花的只算这一天的
    public static func withoutMonthly(_ event: API.EventData) -> API.EventData {
        var copy = event
        copy.metrics = event.metrics.map { list in list.filter { $0.monthly != true } }
        return copy
    }

    /// 一件事多长：说了时长用时长，只说了几点到几点用两者之差
    public static func minutes(_ event: API.EventData) -> Int {
        if let duration = event.durationMin { return duration }
        guard let start = event.start, let end = event.end else { return 0 }
        return max(0, PourDate.minutesBetween(start, end))
    }

    /// 「6 小时 50 分」「40 分」「11 小时」
    public static func durationParts(_ minutes: Int) -> [Part] {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return [Part(number: "\(rest)", unit: "分")] }
        return [Part(number: "\(hours)", unit: "小时")] + (rest > 0 ? [Part(number: "\(rest)", unit: "分")] : [])
    }

    /// 钱的数：千位分隔，最多两位小数，不带「¥」
    public static func yuan(_ value: Double) -> Part {
        Part(number: String(Show.yuan(value).dropFirst()), unit: "")
    }

    /// 一类的名字：都是同一件事时用这件事的名字，不一样时用类别名
    static func name(_ card: Card, _ categories: [API.Category]) -> String {
        let labels = Set(card.entries.compactMap(event).map(\.label))
        if labels.count == 1, let only = labels.first { return only }
        return Show.meta(card.id, categories).name
    }
}
