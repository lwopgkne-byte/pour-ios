import Foundation

// 记录、类别、原话：和网关的接口契约 v1 一字不差（gateway/src/contract.ts；PourAITests 拿网关导出的样例核对）

/// 一个数：钱、距离、页数……
public struct Metric: Codable, Hashable, Sendable {
    public var name: String
    public var value: Double
    public var unit: String
    /// 钱的名目（「菜 ¥860」里的菜）
    public var item: String?
    /// 钱是给谁花的
    public var forWhom: String?
    /// 收进来的钱是谁给的
    public var from: String?

    public init(
        name: String, value: Double, unit: String = "", item: String? = nil, forWhom: String? = nil,
        from: String? = nil
    ) {
        self.name = name
        self.value = value
        self.unit = unit
        self.item = item
        self.forWhom = forWhom
        self.from = from
    }

    enum CodingKeys: String, CodingKey {
        case name, value, unit, item, from
        case forWhom = "for"
    }
}

/// 一条记录的内容：事件、感悟、待办、心情
public enum RecordData: Hashable, Sendable {
    case event(Event)
    case insight(Insight)
    case todo(Todo)
    case mood(Mood)

    public struct Event: Codable, Hashable, Sendable {
        public var category: String
        public var label: String
        /// 几点开始、几点结束（本地时刻；跨零点的睡眠结束在第二天）
        public var start: LocalDateTime?
        public var end: LocalDateTime?
        public var durationMin: Int?
        public var metrics: [Metric]
        public var note: String?
        public var people: [String]
        public var things: [String]
        public var places: [String]

        public init(
            category: String, label: String, start: LocalDateTime? = nil, end: LocalDateTime? = nil,
            durationMin: Int? = nil, metrics: [Metric] = [], note: String? = nil, people: [String] = [],
            things: [String] = [], places: [String] = []
        ) {
            self.category = category
            self.label = label
            self.start = start
            self.end = end
            self.durationMin = durationMin
            self.metrics = metrics
            self.note = note
            self.people = people
            self.things = things
            self.places = places
        }
    }

    public struct Insight: Codable, Hashable, Sendable {
        public var title: String
        public var quote: String
        public var tags: [String]

        public init(title: String, quote: String, tags: [String] = []) {
            self.title = title
            self.quote = quote
            self.tags = tags
        }
    }

    public struct Todo: Codable, Hashable, Sendable {
        public var content: String
        public var due: DayString?
        public var done: Bool
        public var people: [String]
        public var things: [String]
        public var places: [String]

        public init(
            content: String, due: DayString? = nil, done: Bool = false, people: [String] = [],
            things: [String] = [], places: [String] = []
        ) {
            self.content = content
            self.due = due
            self.done = done
            self.people = people
            self.things = things
            self.places = places
        }
    }

    public struct Mood: Codable, Hashable, Sendable {
        /// 1–5：很差、不太好、一般、挺好、很好（程序查表定的）
        public var level: Int
        public var tone: String?
        public var strength: String?
        /// 精力 1–5：只在说到时才有
        public var energy: Int?
        public var emotions: [String]
        /// 那一刻：原话里一字不差的一段
        public var moment: String?

        public init(
            level: Int, tone: String? = nil, strength: String? = nil, energy: Int? = nil, emotions: [String] = [],
            moment: String? = nil
        ) {
            self.level = level
            self.tone = tone
            self.strength = strength
            self.energy = energy
            self.emotions = emotions
            self.moment = moment
        }
    }

    public var kind: String {
        switch self {
        case .event: "event"
        case .insight: "insight"
        case .todo: "todo"
        case .mood: "mood"
        }
    }
}

extension RecordData: Codable {
    private enum KindKey: String, CodingKey { case kind }

    public init(from decoder: any Decoder) throws {
        let kind = try decoder.container(keyedBy: KindKey.self).decode(String.self, forKey: .kind)
        switch kind {
        case "event": self = .event(try Event(from: decoder))
        case "insight": self = .insight(try Insight(from: decoder))
        case "todo": self = .todo(try Todo(from: decoder))
        case "mood": self = .mood(try Mood(from: decoder))
        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "不认识的记录种类：\(kind)"))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: KindKey.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case .event(let event): try event.encode(to: encoder)
        case .insight(let insight): try insight.encode(to: encoder)
        case .todo(let todo): try todo.encode(to: encoder)
        case .mood(let mood): try mood.encode(to: encoder)
        }
    }
}

/// 类别（生活领域和它下面的小类）。预置的六个来自网页版（PourData 的 categories.json）
public struct LifeCategory: Codable, Hashable, Sendable, Identifiable {
    public var key: String
    public var name: String
    public var emoji: String
    /// 九个领域色之一：stone、clay、apricot、straw、moss、lake、wisteria、sakura、brick（规范 01 第 3.1 节）
    public var color: String
    public var parent: String?
    /// duration 时长、count 次数，其他是数量的单位（公里、页）
    public var measure: String
    public var synonyms: [String]
    public var order: Int

    public var id: String { key }

    public init(
        key: String, name: String, emoji: String = "", color: String = "stone", parent: String? = nil,
        measure: String = "duration", synonyms: [String] = [], order: Int = 0
    ) {
        self.key = key
        self.name = name
        self.emoji = emoji
        self.color = color
        self.parent = parent
        self.measure = measure
        self.synonyms = synonyms
        self.order = order
    }
}

extension Array where Element == LifeCategory {
    /// 顶级类别：一直往上找（「跑步」的顶级是「运动」）
    public func root(of key: String) -> String {
        var current = key
        for _ in 0..<8 {
            guard let parent = first(where: { $0.key == current })?.parent else { return current }
            current = parent
        }
        return current
    }

    /// 类别的颜色：自己没有就看上级；都没有是「石」
    public func color(of key: String) -> String {
        first(where: { $0.key == key })?.color ?? first(where: { $0.key == root(of: key) })?.color ?? "stone"
    }
}
