public import Foundation
import PourCore

// 钱的几页（「留意的」、一样东西、人情往来）和接口（web lib/queries.ts、money-parts.tsx 的 useMoneyActions）
extension API {
    public struct FixedRow: Codable, Hashable, Sendable {
        public struct Unused: Codable, Hashable, Sendable {
            public var key: String
            public var lastMention: String
        }

        public var name: String
        public var dayOfMonth: Int
        public var amount: Double
        public var paidOn: String?
        public var lastDay: String
        /// 还有几天扣（0 是今天）
        public var dueIn: Int?
        public var lastEntryId: Int
        public var lastIndex: Int
        public var unused: Unused?
    }

    /// 买了还没用完的（课时、次卡）
    public struct PackRow: Codable, Hashable, Sendable {
        public var entryId: Int
        public var name: String
        public var who: String
        public var day: String
        public var amount: Double
        public var pack: Int
        public var used: [String]
    }

    /// 常买的
    public struct FrequentRow: Codable, Hashable, Sendable {
        public struct Buy: Codable, Hashable, Sendable {
            public var day: String
            public var amount: Double
        }

        public var name: String
        public var every: Int
        public var last: String
        public var next: String
        public var recent: [Buy]
        public var price: String?
    }

    public struct MoneyBudget: Codable, Hashable, Sendable {
        public var id: Int
        public var title: String
        public var headline: String
        public var pct: Double
        public var tone: String
    }

    public struct MoneyWatchPage: Codable, Hashable, Sendable {
        public struct Reimburse: Codable, Hashable, Sendable {
            public var total: Double
            public var items: [MoneyItem]
        }

        public struct Lend: Codable, Hashable, Sendable {
            public var item: MoneyItem
            public var days: Int
        }

        public struct Pending: Codable, Hashable, Sendable {
            public var total: Double
            public var reimburse: Reimburse?
            public var lends: [Lend]
        }

        public struct Fixed: Codable, Hashable, Sendable {
            public var total: Double
            public var rows: [FixedRow]
        }

        public var today: String
        public var pending: Pending
        public var fixed: Fixed
        public var packs: [PackRow]
        public var frequent: [FrequentRow]
        /// 借出去的那几笔你当时怎么说的（记录 id → 原话里的那一段）
        public var quotes: [String: String]
        public var budgets: [MoneyBudget]
    }

    /// 一样东西的那一页
    public struct MoneyThingPage: Codable, Hashable, Sendable {
        public struct Bought: Codable, Hashable, Sendable {
            public var day: String
            public var text: String
        }

        public var entryId: Int
        public var day: String
        public var name: String
        public var amount: Double
        public var who: String
        public var verdict: Verdict?
        public var durable: Bool
        public var uses: [ThingUse]
        public var perUse: Double?
        public var bought: Bought?
    }

    /// 人情一边：多少钱、送礼几次、请客几次
    public struct RenqingSide: Codable, Hashable, Sendable {
        public var amount: Double
        public var gifts: Int
        public var treats: Int
    }

    /// 和一个人的来往（人情往来那一页的一行）
    public struct RenqingPersonLine: Codable, Hashable, Sendable {
        public struct Last: Codable, Hashable, Sendable {
            public var day: String
            public var text: String
        }

        public var name: String
        public var relation: String?
        public var out: RenqingSide
        public var into: RenqingSide
        public var last: Last

        enum CodingKeys: String, CodingKey {
            case name, relation, out, last
            case into = "in"
        }
    }

    public struct RenqingPage: Codable, Hashable, Sendable {
        public struct Unknown: Codable, Hashable, Sendable {
            public var times: Int
            public var amount: Double
        }

        public var started: String?
        public var out: RenqingSide
        public var into: RenqingSide
        public var people: [RenqingPersonLine]
        public var unknown: Unknown?

        enum CodingKeys: String, CodingKey {
            case started, out, people, unknown
            case into = "in"
        }
    }

    public struct RenqingPersonPage: Codable, Hashable, Sendable {
        public struct Row: Codable, Hashable, Sendable {
            public var entryId: Int
            public var day: String
            public var dir: String
            public var text: String
            public var together: [String]
            public var quote: String?
        }

        public var name: String
        public var relation: String?
        public var out: RenqingSide
        public var into: RenqingSide
        public var rows: [Row]

        enum CodingKeys: String, CodingKey {
            case name, relation, out, rows
            case into = "in"
        }
    }

    /// 记录里的哪一笔钱
    public struct MoneyRef: Hashable, Sendable {
        public var entryId: Int
        public var index: Int

        public init(entryId: Int, index: Int) {
            self.entryId = entryId
            self.index = index
        }
    }
}

extension APIClient {
    public func moneyMonth(_ month: String) async throws(APIError) -> API.MoneyMonth {
        try await get("/api/money/\(month)")
    }

    public func moneyDay(_ day: String) async throws(APIError) -> API.MoneyDayPage {
        try await get("/api/money/day/\(day)")
    }

    public func moneyOverview() async throws(APIError) -> API.MoneyOverview { try await get("/api/money/overview") }

    public func moneyWatch() async throws(APIError) -> API.MoneyWatchPage { try await get("/api/money/watch") }

    public func moneyThing(_ id: Int) async throws(APIError) -> API.MoneyThingPage {
        try await get("/api/money/thing/\(id)")
    }

    public func moneyFindings() async throws(APIError) -> API.MoneyFindingsPage { try await get("/api/money/findings") }

    public func renqing() async throws(APIError) -> API.RenqingPage { try await get("/api/money/renqing") }

    public func renqing(person name: String) async throws(APIError) -> API.RenqingPersonPage {
        let path = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(["/"])) ?? name
        return try await get("/api/money/renqing/\(path)")
    }

    /// 「都报销了」「已经还了」（settled false 是撤销）
    public func settle(_ refs: [API.MoneyRef], settled: Bool) async throws(APIError) {
        let list = refs.map {
            JSONValue.object(["entryId": .number(Double($0.entryId)), "index": .number(Double($0.index))])
        }
        let _: Empty = try await request(
            "POST", "/api/money/settle", json: .object(["refs": .array(list), "settled": .bool(settled)]))
    }

    /// 「不再算固定的」（ended false 是改回来）
    public func endFixed(_ ref: API.MoneyRef, ended: Bool) async throws(APIError) {
        let _: Empty = try await request(
            "POST", "/api/money/fixed-end",
            json: .object([
                "entryId": .number(Double(ref.entryId)), "index": .number(Double(ref.index)), "ended": .bool(ended),
            ]))
    }

    /// 钱和你的日子：说中了 · 早知道 · 没意思 · 不对（nil 是撤销）
    public func vote(finding key: String, _ vote: String?) async throws(APIError) {
        let _: Empty = try await request(
            "POST", "/api/money/findings/vote",
            json: .object(["key": .string(key), "vote": vote.map { .string($0) } ?? .null]))
    }
}

/// 钱的写法（web money-parts.tsx、shared tidy.ts）
extension Show {
    /// 一笔钱怎么写：「¥3,126」；遮住时「¥•••」；收入前面加「+」
    public static func yuan(_ value: Double, hide: Bool, plus: Bool = false) -> String {
        hide ? "¥•••" : "\(plus ? "+" : "")\(yuan(value))"
    }

    /// 句子里的钱也遮住
    public static func maskYuan(_ text: String, hide: Bool) -> String {
        hide ? text.replacing(/¥[\d,.]+/, with: "¥•••") : text
    }

    /// 「8月10日」
    public static func monthDay(_ day: String) -> String {
        "\(Int(day.dropFirst(5).prefix(2)) ?? 0)月\(Int(day.suffix(2)) ?? 0)日"
    }

    /// 「周一」
    public static func weekday(_ day: String) -> String {
        ["周一", "周二", "周三", "周四", "周五", "周六", "周日"][PourDate.weekdayMon0(day)]
    }

    /// 这个月的地址：这个月就是 /money
    public static func moneyPath(_ month: String, today: String) -> String {
        today.hasPrefix(month) ? "/money" : "/money/\(month)"
    }

    /// 「退了 ¥299」「AA 转回 ¥60」
    public static func returnedNote(_ returned: API.Metric.Returned) -> String {
        "\(returned.why == "refund" ? "退了" : "AA 转回") \(yuan(returned.amount))"
    }

    /// 每一笔旁边的小标签：日常的不写（人情写「人情」）
    public static func kindTag(_ item: API.MoneyItem) -> String? {
        switch item.kind {
        case "daily": item.renqing == nil ? nil : "人情"
        case "gift": "人情"
        case "fixed": "固定的"
        case "reimburse", "lend": flagNote(item.kind, settled: item.settled)
        case "income": "收入"
        case "back": "回来的钱"
        default: nil
        }
    }

    /// 给谁：自己的不写；名目里已经说了的不重复；收到的人情写「大姐给的」
    public static func whoLabel(_ item: API.MoneyItem) -> String {
        let who = item.who
        if who.isEmpty || who == "自己" || item.name.contains(who) { return "" }
        if item.kind == "gift" { return "\(who)给的" }
        return who == "一家人" ? "一家人" : "给\(who)"
    }

    /// 固定的那一行下面：在扣钱却没说到用它（shared unusedText）
    public static func unusedText(_ row: API.FixedRow) -> String {
        guard let unused = row.unused else { return "" }
        return "\(monthDay(row.lastDay))又扣了；\(monthDay(unused.lastMention))以后没说到\(unused.key)"
    }
}
