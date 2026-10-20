public import Foundation

// 「Pour 认识的」（shared about.ts 的 About、SleepPattern、Habit、Person、Place、Saying），字段名一字不差
extension API {
    /// 作息的一晚
    public struct Night: Codable, Hashable, Sendable {
        public var day: String
        public var start: String
        public var end: String
        public var minutes: Int
        public var entryId: Int
        public var noteId: Int?
        /// 和平时差得多的那几晚才有：「比平时早起 2 小时」
        public var note: String?
    }

    public struct SleepPattern: Codable, Hashable, Sendable {
        public struct Before: Codable, Hashable, Sendable {
            public var bed: String
        }

        public var key: String
        public var basis: String
        /// right、wrong
        public var mark: String?
        public var markedAt: String?
        public var bed: String
        public var wake: String
        public var minutes: Int
        /// steady、unsteady
        public var steady: String?
        public var weekendDiff: Int?
        public var before: Before?
        public var from: String
        public var to: String
        public var nights: [Night]
        public var outliers: [Night]
    }

    /// 常做的事、地方的依据里的一次
    public struct AboutOccurrence: Codable, Hashable, Sendable {
        public var day: String
        public var at: String?
        public var label: String
        public var entryId: Int
        public var noteId: Int?
    }

    public struct Habit: Codable, Hashable, Sendable {
        public var key: String
        public var basis: String
        public var mark: String?
        public var markedAt: String?
        public var name: String
        public var domain: String
        /// 每周几次；「daily」是几乎每天（服务器给的是数字或者 "daily"）
        public var perWeek: PerWeek
        public var part: String?
        public var times: Int
        public var occurrences: [AboutOccurrence]
    }

    /// 每周几次，或者几乎每天
    public enum PerWeek: Codable, Hashable, Sendable {
        case daily
        case times(Double)

        public init(from decoder: any Decoder) throws {
            let box = try decoder.singleValueContainer()
            if let number = try? box.decode(Double.self) {
                self = .times(number)
            } else {
                self = .daily
            }
        }

        public func encode(to encoder: any Encoder) throws {
            var box = encoder.singleValueContainer()
            switch self {
            case .daily: try box.encode("daily")
            case .times(let number): try box.encode(number)
            }
        }
    }

    /// 从哪段原话学来的
    public struct SaidNote: Codable, Hashable, Sendable {
        public var text: String
        public var at: String
    }

    public struct PersonRelation: Codable, Hashable, Sendable {
        public var id: Int
        public var meaning: String
        public var noteId: Int?
        public var updatedAt: String
        public var note: SaidNote?
    }

    public struct KnownPerson: Codable, Hashable, Sendable {
        public struct Moments: Codable, Hashable, Sendable {
            public var good: Int
            public var bad: Int
        }

        public struct Recent: Codable, Hashable, Sendable {
            public var day: String
            public var label: String
            public var domain: String
            public var entryId: Int
            public var noteId: Int?
        }

        public var key: String
        public var basis: String
        public var mark: String?
        public var name: String
        public var times: Int
        public var firstDay: String
        public var lastDay: String
        public var relation: PersonRelation?
        /// 名字本身就是称呼（儿子、领导）：没有「关系」那一行
        public var titled: Bool
        public var domains: [String]
        public var moments: Moments?
        public var recent: [Recent]
    }

    public struct KnownPlace: Codable, Hashable, Sendable {
        public var key: String
        public var basis: String
        public var mark: String?
        public var name: String
        public var days: Int
        public var lastDay: String
        public var doing: [String]
        public var recent: [AboutOccurrence]
    }

    /// 你的一个说法（个人词典的一条）
    public struct Saying: Codable, Hashable, Sendable {
        public var key: String
        public var id: Int
        public var phrase: String
        public var meaning: String
        public var noteId: Int?
        public var updatedAt: String
        public var note: SaidNote?
    }

    public struct HiddenItem: Codable, Hashable, Sendable {
        public var key: String
        /// sleep、habits、people、places
        public var block: String
        public var text: String
        public var domain: String?
    }

    /// Pour 认识的：作息、常做的事、人和关系、常去的地方、你的说法
    public struct Known: Codable, Hashable, Sendable {
        public var sleep: SleepPattern?
        public var habits: [Habit]
        public var people: [KnownPerson]
        public var places: [KnownPlace]
        public var former: [KnownPerson]
        public var sayings: [Saying]
        public var hidden: [HiddenItem]
    }
}

extension APIClient {
    public func known() async throws(APIError) -> API.Known { try await get("/api/about") }

    /// 标「对」「不对」（nil 是撤销）；basis 是这一条的要点（要点变了标记就不算），sentence 是当时那句话
    public func mark(_ key: String, _ mark: String?, basis: String, sentence: String) async throws(APIError) {
        let _: Empty = try await request(
            "PUT", "/api/about/marks",
            json: .object([
                "key": .string(key), "mark": mark.map { .string($0) } ?? .null, "basis": .string(basis),
                "sentence": .string(sentence),
            ]))
    }

    /// 个人词典：加一条（说法、关系）
    public func addSaying(_ phrase: String, meaning: String, noteId: Int? = nil) async throws(APIError) {
        var body: [String: JSONValue] = ["phrase": .string(phrase), "meaning": .string(meaning)]
        if let noteId { body["noteId"] = .number(Double(noteId)) }
        let _: Empty = try await request("POST", "/api/dictionary", json: .object(body))
    }

    public func editSaying(_ id: Int, phrase: String? = nil, meaning: String? = nil) async throws(APIError) {
        var body: [String: JSONValue] = [:]
        if let phrase { body["phrase"] = .string(phrase) }
        if let meaning { body["meaning"] = .string(meaning) }
        let _: Empty = try await request("PATCH", "/api/dictionary/\(id)", json: .object(body))
    }

    public func deleteSaying(_ id: Int) async throws(APIError) {
        let _: Empty = try await request("DELETE", "/api/dictionary/\(id)")
    }
}

/// 「Pour 认识的」的写法（shared about.ts）
extension Show {
    /// 「07:10」→「7:10」
    public static func hourMinute(_ hhmm: String) -> String { hhmm.replacing(/^0(\d)/) { String($0.output.1) } }

    /// 「7 小时 20 分」「45 分」（shared formatDurationCn）
    public static func durationCn(_ minutes: Int) -> String {
        let sign = minutes < 0 ? "-" : ""
        let total = abs(minutes)
        if total < 60 { return "\(sign)\(total) 分" }
        return total % 60 == 0 ? "\(sign)\(total / 60) 小时" : "\(sign)\(total / 60) 小时 \(total % 60) 分"
    }

    private static func gap(_ minutes: Int) -> String { minutes < 60 ? "\(minutes) 分钟" : durationCn(minutes) }

    private static func sleepNotes(_ sleep: API.SleepPattern) -> [String] {
        var out: [String] = []
        if sleep.steady == "steady" { out.append("几点睡比较固定") }
        if sleep.steady == "unsteady" { out.append("几点睡不太固定") }
        if let diff = sleep.weekendDiff { out.append("周末\(diff > 0 ? "晚" : "早")睡 \(gap(abs(diff)))") }
        if let before = sleep.before { out.append("以前多在 \(hourMinute(before.bed)) 左右睡") }
        return out
    }

    /// 「你通常 23:40 左右睡，7:10 左右起，睡 7 小时 30 分」；full 是详情里的完整版
    public static func sleepSentence(_ sleep: API.SleepPattern, full: Bool = false) -> String {
        let base = "你通常 \(hourMinute(sleep.bed)) 左右睡，\(hourMinute(sleep.wake)) 左右起，睡 \(durationCn(sleep.minutes))"
        guard full else { return base }
        let notes = sleepNotes(sleep)
        return "\(base)。\(notes.isEmpty ? "" : "\(notes.joined(separator: "，"))。")"
    }

    public static func sleepMeta(_ sleep: API.SleepPattern) -> String { sleepNotes(sleep).joined(separator: " · ") }

    private static func perWeek(_ habit: API.Habit) -> String {
        switch habit.perWeek {
        case .daily: "几乎每天"
        case .times(let count): "大约每周 \(Show.fmtNum(count)) 次"
        }
    }

    public static func habitMeta(_ habit: API.Habit) -> String {
        [perWeek(habit), habit.part.map { "多在\($0)" } ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    public static func habitSentence(_ habit: API.Habit) -> String {
        "\(habit.name)：\(perWeek(habit))\(habit.part.map { "，多在\($0)" } ?? "")。"
    }

    public static func personMeta(_ person: API.KnownPerson) -> String {
        [
            "提到 \(person.times) 次", person.domains.isEmpty ? "" : "多是\(person.domains.joined(separator: "、"))",
            "最近 \(monthDay(person.lastDay))",
        ].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    public static func personSummary(_ person: API.KnownPerson) -> String {
        let first =
            "提到 \(person.times) 次\(person.domains.isEmpty ? "" : "，多是\(person.domains.joined(separator: "、"))")。"
        let when = "第一次提到是 \(monthDay(person.firstDay))，最近一次 \(monthDay(person.lastDay))。"
        guard let moments = person.moments else { return first + when }
        let parts = [moments.good > 0 ? "好时刻 \(moments.good) 个" : "", moments.bad > 0 ? "不好的时刻 \(moments.bad) 个" : ""]
        return first + when + "一起的时候，\(parts.filter { !$0.isEmpty }.joined(separator: "，"))。"
    }

    public static func placeMeta(_ place: API.KnownPlace) -> String {
        [
            "去过 \(place.days) 天", place.doing.isEmpty ? "" : "多是\(place.doing.joined(separator: "、"))",
            "最近 \(monthDay(place.lastDay))",
        ].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// 原话里说到这个人的那一小句
    public static func saidClause(_ text: String, name: String, meaning: String) -> String {
        let clauses = text.split(separator: /[，。！？；,.!?;\s]+/).map(String.init).filter { !$0.isEmpty }
        let withName = clauses.filter { $0.contains(name) }
        let hit = withName.first { $0.contains(meaning) } ?? withName.first { $0.contains("是") } ?? withName.first
        return hit ?? (text.count > 20 ? "\(text.prefix(20))…" : text)
    }

    /// 列表里关系最多露 10 个字
    public static func relationShort(_ meaning: String) -> String {
        meaning.count > 10 ? "\(meaning.prefix(10))…" : meaning
    }
}
