import Foundation

// 3.0 目标的弹层和我在乎的（服务器 shared/src/goals3.ts、care.ts）：WOOP、GROW、每周回顾、领域页、理解卡
extension API {
    // MARK: - WOOP、GROW、每周回顾

    /// WOOP 的一屏
    public struct WoopStep: Codable, Hashable, Sendable {
        /// why、obstacle、plan
        public var key: String
        public var question: String
        public var sub: String?
        public var options: [CoachOption]

        private enum CodingKeys: String, CodingKey {
            case key, sub, options
            case question = "q"
        }
    }

    /// 从下周一重新开始
    public struct GrowRestart: Codable, Hashable, Sendable {
        public var day: String
        public var text: String

        private enum CodingKeys: String, CodingKey {
            case text
            case day = "on"
        }
    }

    /// 一个现成的回答：宋体那一句、出处（点开看那句原话）或者怎么想到的
    public struct CoachOption: Codable, Hashable, Sendable {
        public var text: String
        public var source: GoalQuote?
        public var how: String?
    }

    public struct WoopPage: Codable, Hashable, Sendable {
        public var title: String
        public var steps: [WoopStep]
        public var remindQ: String
        public var reminds: [GoalRemind]
        public var three: GoalThree?
    }

    public struct GrowOption: Codable, Hashable, Sendable, Identifiable {
        /// down、weekend、ifthen、pause、ease
        public var key: String
        public var title: String
        public var how: String
        public var when: String
        public var cost: String
        public var target: Double?
        public var newTitle: String?
        public var ifthen: String?
        public var remind: GoalRemind?
        public var until: String?
        public var line: String

        public var id: String { key }
    }

    public struct GrowPage: Codable, Hashable, Sendable {
        public struct Facts: Codable, Hashable, Sendable {
            public var lead: String
            public var more: String?
            public var quotes: [GoalQuote]
        }

        public var title: String
        public var sub: String
        public var ask: String
        public var askSub: String
        public var facts: Facts
        public var blockers: [CoachOption]
        public var blockerFoot: String?
        public var options: [GrowOption]
        public var restart: GrowRestart
        public var letgoWhys: [String]
    }

    public struct WeeklyReview: Codable, Hashable, Sendable {
        public struct Row: Codable, Hashable, Sendable, Identifiable {
            public var id: Int
            public var title: String
            public var done: Bool
            public var sub: String
            public var value: String
        }

        public struct Observation: Codable, Hashable, Sendable {
            public var text: String
            public var foot: String
        }

        public struct Adjust: Codable, Hashable, Sendable, Identifiable {
            public var id: Int
            public var title: String
            public var why: String
            public var option: GrowOption
        }

        public struct Next: Codable, Hashable, Sendable, Identifiable {
            public var id: Int
            public var goal: String
            public var text: String
            public var todo: WeeklyTodo
        }

        public var from: String
        public var to: String
        public var title: String
        public var rows: [Row]
        public var observation: Observation?
        public var adjust: [Adjust]
        public var next: [Next]
        public var nextFoot: String
        public var seen: Bool
    }

    // MARK: - 我在乎的

    public struct CareWish: Codable, Hashable, Sendable {
        public struct Source: Codable, Hashable, Sendable {
            public var noteId: Int?
            public var day: String
            public var text: String
        }

        public var text: String
        public var agreed: Bool
        public var sources: [Source]
    }

    public struct CareArea: Codable, Hashable, Sendable, Identifiable {
        public var key: String
        public var name: String
        public var icon: String
        public var categories: [String]
        public var scores: [String: Int]
        public var wish: CareWish?

        public var id: String { key }
    }

    public struct CareSettings: Codable, Hashable, Sendable {
        public var areas: [CareArea]
        public var agreed: Bool
        public var max: Int?
    }

    /// 领域页上面四块（GET /api/care/:key）
    public struct CareDomain: Codable, Hashable, Sendable {
        public struct Area: Codable, Hashable, Sendable {
            public var key: String
            public var name: String
            public var icon: String
            public var categories: [String]?
        }

        public struct Invest: Codable, Hashable, Sendable {
            public var line: String
            public var rows: [CareInvestRow]
            public var foot: String
        }

        public struct Score: Codable, Hashable, Sendable {
            public var quarter: String
            public var value: Int?
            public var prev: Int?
            public var foot: String
        }

        public var area: Area
        public var wish: CareWish?
        public var goals: [GoalCard]
        public var empty: GoalsHome.Suggestion?
        public var invest: Invest
        public var score: Score
        public var money: Bool
    }

    // MARK: - 定目标的理解卡

    public struct GoalPlanView: Codable, Hashable, Sendable {
        public var title: String
        public var type: String
        public var period: String
        public var from: String
        public var counted: String
        public var quotes: [GoalQuote]
        public var care: String?
        /// 点「对」时原样发回去
        public var operation: JSONValue

        private enum CodingKeys: String, CodingKey {
            case title, type, period, from, counted, quotes, care
            case operation = "op"
        }
    }

    public struct GoalPositive: Codable, Hashable, Sendable {
        public var why: String
        public var plan: GoalPlanView
    }

    public struct GoalOffer: Codable, Hashable, Sendable {
        public var value: Double
        public var unit: String
        public var text: String
    }

    public struct SayOption: Codable, Hashable, Sendable {
        public var text: String
        public var say: String
    }

    /// 说一句的理解：plan 理解卡、ask 问一句、vague 模糊的、split 拆开的、dup 已经有了
    public struct GoalUnderstand: Codable, Hashable, Sendable {
        public var kind: String
        public var plan: GoalPlanView?
        public var note: String?
        public var positive: GoalPositive?
        public var question: String?
        public var sub: String?
        public var options: [SayOption]?
        public var title: String?
        public var lead: String?
        public var children: [GoalPlanView]?
        public var skipped: [String]?
        public var goal: GoalCard?
        public var offer: GoalOffer?
    }

    public struct GoalMade: Codable, Hashable, Sendable {
        public var id: Int
        public var ids: [Int]
        public var line: String
        public var big: Bool
    }
}

extension API.GoalChart: Codable {
    private enum Keys: String, CodingKey {
        case kind, from, days, today, target, unit, actual, expected, slow, fast, ticks, rows, line, lineLabel, format,
            money, points, title, sub
    }

    /// 「days」在 line 里是一共几天（数），在 days 里是 30 天的格子（数组）
    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: Keys.self)
        kind = try box.decode(String.self, forKey: .kind)
        from = try box.decodeIfPresent(String.self, forKey: .from)
        length = try? box.decodeIfPresent(Int.self, forKey: .days)
        cells = try? box.decodeIfPresent([Day].self, forKey: .days)
        today = try box.decodeIfPresent(Int.self, forKey: .today)
        target = try box.decodeIfPresent(Double.self, forKey: .target)
        unit = try box.decodeIfPresent(String.self, forKey: .unit)
        actual = try box.decodeIfPresent([Double].self, forKey: .actual)
        expected = try box.decodeIfPresent([Double].self, forKey: .expected)
        slow = try box.decodeIfPresent(Double.self, forKey: .slow)
        fast = try box.decodeIfPresent(Double.self, forKey: .fast)
        ticks = try box.decodeIfPresent([Tick].self, forKey: .ticks)
        rows = try box.decodeIfPresent([Row].self, forKey: .rows)
        line = try box.decodeIfPresent(Double.self, forKey: .line)
        lineLabel = try box.decodeIfPresent(String.self, forKey: .lineLabel)
        format = try box.decodeIfPresent(String.self, forKey: .format)
        money = try box.decodeIfPresent(Bool.self, forKey: .money)
        points = try box.decodeIfPresent([Point].self, forKey: .points)
        title = try box.decodeIfPresent(String.self, forKey: .title)
        sub = try box.decodeIfPresent(String.self, forKey: .sub)
    }

    public func encode(to encoder: any Encoder) throws {
        var box = encoder.container(keyedBy: Keys.self)
        try box.encode(kind, forKey: .kind)
        try box.encodeIfPresent(from, forKey: .from)
        if let cells { try box.encode(cells, forKey: .days) } else { try box.encodeIfPresent(length, forKey: .days) }
        try box.encodeIfPresent(today, forKey: .today)
        try box.encodeIfPresent(target, forKey: .target)
        try box.encodeIfPresent(unit, forKey: .unit)
        try box.encodeIfPresent(actual, forKey: .actual)
        try box.encodeIfPresent(expected, forKey: .expected)
        try box.encodeIfPresent(slow, forKey: .slow)
        try box.encodeIfPresent(fast, forKey: .fast)
        try box.encodeIfPresent(ticks, forKey: .ticks)
        try box.encodeIfPresent(rows, forKey: .rows)
        try box.encodeIfPresent(line, forKey: .line)
        try box.encodeIfPresent(lineLabel, forKey: .lineLabel)
        try box.encodeIfPresent(format, forKey: .format)
        try box.encodeIfPresent(money, forKey: .money)
        try box.encodeIfPresent(points, forKey: .points)
        try box.encodeIfPresent(title, forKey: .title)
        try box.encodeIfPresent(sub, forKey: .sub)
    }
}
