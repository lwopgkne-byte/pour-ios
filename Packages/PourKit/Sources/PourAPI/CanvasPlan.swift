import Foundation

/// 生活画布 2.0「由内容决定」（docs/模块/生活画布2.0.md 第 4 节）：这一天有什么，就长出什么卡片。
/// 卡片选哪种样子、多大、什么顺序，今天的样子挑哪几个亮点——都由这里的纯函数定（不靠 AI），单元测试覆盖几种人的一天
public enum CanvasPlan {
    /// 卡片的样子：按「这一类数据长什么样」选，不按固定的几个类别；`mentions` 是这一天说到的人、东西、地方、话题
    public enum Template: String, Sendable, Hashable {
        case duration, count, quantity, body, sleep, diet, money, mood, insight, todo, general, mentions
    }

    /// 半宽还是整行
    public enum Size: Sendable, Hashable {
        case half, full
    }

    /// 一张卡：哪一类（顶级类别的 key，或 insight / todo / mood；钱的汇总卡是 `moneyKey`）、什么样子、多大、里面的记录
    public struct Card: Identifiable, Hashable, Sendable {
        public let id: String
        public let template: Template
        public let size: Size
        public let entries: [API.Entry]
        /// 拼着身体数据（健康卡：上面是血压，下面是吃药几次）
        public let withBody: Bool

        public init(id: String, template: Template, size: Size, entries: [API.Entry], withBody: Bool) {
            self.id = id
            self.template = template
            self.size = size
            self.entries = entries
            self.withBody = withBody
        }
    }

    /// 排好的一行：一张整行，或者两张半宽
    public enum Row: Identifiable, Hashable, Sendable {
        case full(Card)
        case pair(Card, Card)

        public var id: String {
            switch self {
            case .full(let card): "full-\(card.id)"
            case .pair(let left, let right): "pair-\(left.id)-\(right.id)"
            }
        }
    }

    /// 钱的汇总卡的 id（类别的 key 里没有这个）
    public static let moneyKey = "money"
    /// 「说到的」那张卡的 id
    public static let mentionsKey = "mentions"

    /// 类别表里没有时，预置类别的计量方式
    static let builtInMeasure: [String: String] = ["exercise": "duration", "study": "duration", "work": "duration"]

    /// 这一天的卡片，按行排好
    public static func rows(_ entries: [API.Entry], _ categories: [API.Category]) -> [Row] {
        pair(cards(entries, categories))
    }

    /// 这一天的卡片（还没配对）。待办和提醒永远最前（做完了也不往后挪：产品主人 2026-10-21 说跑到下面是毛病）；
    /// 然后钱的汇总卡、说到的人和东西，其余按类别表的顺序，感悟、心情放最后
    public static func cards(_ entries: [API.Entry], _ categories: [API.Category]) -> [Card] {
        let keys = entries.map { Show.group($0, categories) }
        let ordered = Show.sortGroups(Array(Set(keys)), categories, openTodos: true)
        var out = ordered.map { key in card(key, entries.filter { Show.group($0, categories) == key }, categories) }
        var index = out.first?.id == "todo" ? 1 : 0
        if let money = moneySummary(entries) {
            out.insert(money, at: min(index, out.count))
            index += 1
        }
        if mentions(entries).count >= 2 {
            let card = Card(id: mentionsKey, template: .mentions, size: .full, entries: [], withBody: false)
            out.insert(card, at: min(index, out.count))
        }
        return out
    }

    /// 待办的先后：有提醒的按提醒时间在前，其余按说的先后；做没做完不改变位置（勾掉不会跳到下面去）
    public static func todoOrder(_ entries: [API.Entry]) -> [API.Entry] {
        entries.sorted { lhs, rhs in
            let left = remindAt(lhs)
            let right = remindAt(rhs)
            if left != right { return (left ?? "~") < (right ?? "~") }
            return lhs.id < rhs.id
        }
    }

    private static func remindAt(_ entry: API.Entry) -> String? {
        if case .todo(let todo) = entry.data { todo.remindAt } else { nil }
    }

    /// 这一天说到的人、东西、地方、话题（按说的先后，不重复）
    public struct Mentions: Hashable, Sendable {
        public var people: [String] = []
        public var things: [String] = []
        public var places: [String] = []
        public var topics: [String] = []

        public var count: Int { people.count + things.count + places.count + topics.count }
    }

    /// 从事件、待办、感悟里收：和谁、什么东西、在哪、话题（事件和感悟的标签）
    public static func mentions(_ entries: [API.Entry]) -> Mentions {
        var out = Mentions()
        func add(_ items: [String]?, _ path: WritableKeyPath<Mentions, [String]>) {
            for item in items ?? [] {
                let name = item.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty, !out[keyPath: path].contains(name) { out[keyPath: path].append(name) }
            }
        }
        for entry in entries {
            switch entry.data {
            case .event(let event):
                add(event.people, \.people)
                add(event.things, \.things)
                add(event.places, \.places)
                add(event.tags, \.topics)
            case .todo(let todo):
                add(todo.people, \.people)
                add(todo.things, \.things)
                add(todo.places, \.places)
            case .insight(let insight):
                add(insight.tags, \.topics)
            case .mood:
                break
            }
        }
        return out
    }

    /// 一类的卡片
    static func card(_ key: String, _ items: [API.Entry], _ categories: [API.Category]) -> Card {
        let template = template(key, items, categories)
        let events = items.compactMap(event)
        let withBody =
            ![.body, .sleep, .diet, .mood, .insight, .todo].contains(template) && events.contains(where: hasBody)
        return Card(
            id: key, template: template, size: size(template, items, withBody: withBody), entries: items,
            withBody: withBody)
    }

    /// 选样子：睡眠、饮食、心情、感悟、待办各有自己的；别的按类别表的计量方式（时长、次数、单位）
    static func template(_ key: String, _ items: [API.Entry], _ categories: [API.Category]) -> Template {
        if let own = ["sleep": Template.sleep, "diet": .diet, "mood": .mood, "insight": .insight, "todo": .todo][key] {
            return own
        }
        let events = items.compactMap(event)
        if !events.isEmpty && events.allSatisfy(hasBody) { return .body }
        let measure = categories.first { $0.key == key }?.measure ?? builtInMeasure[key] ?? ""
        let timed = events.contains { $0.durationMin != nil || ($0.start != nil && $0.end != nil) }
        switch measure {
        case "duration": return timed ? .duration : .general
        case "count": return .count
        case "": return .general
        default:
            let measured = events.contains { ($0.metrics ?? []).contains { $0.unit == measure } }
            return measured ? .quantity : (timed ? .duration : .general)
        }
    }

    /// 半宽：只有一个主数、内容不超过两行；整行：列表
    static func size(_ template: Template, _ items: [API.Entry], withBody: Bool) -> Size {
        switch template {
        case .todo, .insight, .mentions: return .full
        case .mood:
            let moments = items.contains {
                if case .mood(let mood) = $0.data { !(mood.moment ?? "").isEmpty } else { false }
            }
            return moments || items.count > 2 ? .full : .half
        case .money: return .half
        case .body: return Set(items.compactMap(event).compactMap(bodyKind)).count > 1 ? .full : .half
        case .diet: return items.count > 1 ? .full : .half
        default: return withBody || items.count > 2 ? .full : .half
        }
    }

    /// 半宽两两成对；单出一张拉满一行。为了不留空，后面最近的半宽卡可以往前挪一位来配对
    public static func pair(_ cards: [Card]) -> [Row] {
        var rows: [Row] = []
        var index = 0
        while index < cards.count {
            let card = cards[index]
            let next = index + 1 < cards.count ? cards[index + 1] : nil
            let after = index + 2 < cards.count ? cards[index + 2] : nil
            if card.size == .full {
                rows.append(.full(card))
                index += 1
            } else if let next, next.size == .half {
                rows.append(.pair(card, next))
                index += 2
            } else if let next, let after, after.size == .half {
                rows.append(.pair(card, after))
                rows.append(.full(next))
                index += 3
            } else {
                rows.append(.full(card))
                index += 1
            }
        }
        return rows
    }

    /// 钱的汇总卡：两笔以上，或者有收入，才单独出来（只有一笔时它的类别卡上已经写了）
    static func moneySummary(_ entries: [API.Entry]) -> Card? {
        let withMoney = entries.filter { entry in
            guard let event = event(entry) else { return false }
            return (event.metrics ?? []).contains(where: Show.isMoney)
        }
        let (_, earned) = Show.money(withMoney.compactMap(event))
        guard withMoney.count >= 2 || earned > 0 else { return nil }
        return Card(id: moneyKey, template: .money, size: .half, entries: withMoney, withBody: false)
    }

    /// 一张卡的名字、emoji、颜色：钱的汇总卡、说到的不是类别，自己写
    public static func meta(_ key: String, _ categories: [API.Category]) -> Show.Meta {
        switch key {
        case moneyKey: Show.Meta(name: "钱", emoji: "💰", color: "yellow")
        case mentionsKey: Show.Meta(name: "说到的", emoji: "💬", color: "blue")
        default: Show.meta(key, categories)
        }
    }

    // MARK: - 小帮手

    /// 记录里的事件（不是事件的是 nil）
    public static func event(_ entry: API.Entry) -> API.EventData? {
        if case .event(let event) = entry.data { event } else { nil }
    }

    /// 身体的数：血压、体重、血糖、心率、体温、血氧
    static let bodyNames = ["血压", "收缩压", "舒张压", "高压", "低压", "体重", "血糖", "心率", "体温", "血氧"]

    public static func isBody(_ metric: API.Metric) -> Bool {
        bodyNames.contains { metric.name.contains($0) }
    }

    /// 这件事带着身体的数
    public static func hasBody(_ event: API.EventData) -> Bool {
        (event.metrics ?? []).contains(where: isBody)
    }

    /// 一件事量的是哪种身体的数（血压的高压、低压算一种）
    static func bodyKind(_ event: API.EventData) -> String? {
        guard let metric = (event.metrics ?? []).first(where: isBody) else { return nil }
        return ["收缩压", "舒张压", "高压", "低压", "血压"].contains { metric.name.contains($0) } ? "血压" : metric.name
    }
}
