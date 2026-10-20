public import Foundation

// 关于我（shared me.ts、me-pages.ts、me-care.ts、me-talk.ts、me-themes.ts、me-year.ts），字段名一字不差
extension API {
    /// 方块图里的一块：说到它的段数、占多少（0–100）
    public struct MeTile: Codable, Hashable, Sendable {
        public var key: String
        public var name: String
        public var color: String
        public var notes: Int
        public var share: Int
    }

    public struct MeComposition: Codable, Hashable, Sendable {
        public var days: Int
        public var total: Int
        public var tiles: [MeTile]
        /// 说得少的：最下面一条「还在攒的」
        public var later: [MeTile]
        public var sentence: String
    }

    /// 日历的一天：on 有、off 记了没有、none 没说话、future 还没到
    public struct MeCalDay: Codable, Hashable, Sendable {
        public var day: String
        public var state: String
        public var level: Double?
    }

    public struct MeCalWeek: Codable, Hashable, Sendable {
        public var label: String
        public var days: [MeCalDay]
    }

    public struct MeClock: Codable, Hashable, Sendable {
        public struct Part: Codable, Hashable, Sendable {
            public var name: String
            public var from: Int
            public var to: Int
        }

        public var hours: [Int]
        public var part: Part?
        public var share: Double
        public var peak: Int?
        public var sentence: String
        public var total: Int
    }

    /// 换个角度看你：一个大字、一句结论、一张小图
    public struct MeAngle: Codable, Hashable, Sendable {
        public struct Bar: Codable, Hashable, Sendable {
            public var name: String
            public var share: Double
            /// better、worse、same、few
            public var mood: String
        }

        /// mood、people、money、talk
        public var key: String
        public var title: String
        public var big: String
        public var sub: String
        public var pixels: [MeCalWeek]?
        public var bars: [Bar]?
        public var week: [Double]?
        public var clock: MeClock?
    }

    public struct RecipeRow: Codable, Hashable, Sendable {
        public var name: String
        public var good: Int
        public var bad: Int
        public var days: [String]
    }

    /// 好日子的配方
    public struct MeRecipe: Codable, Hashable, Sendable {
        public var size: Int
        public var good: [RecipeRow]
        public var bad: [RecipeRow]
    }

    /// 你没注意到的变化：一句话 + 小曲线
    public struct MeChange: Codable, Hashable, Sendable {
        public var key: String
        public var text: String
        public var from: String
        public var to: String
        public var sub: String
        public var points: [Double]
        /// 领域色；mood 是强调色；gray 灰
        public var color: String
        public var domain: String?
        public var person: String?
    }

    public struct MeWaiting: Codable, Hashable, Sendable {
        public var key: String
        public var name: String
        public var text: String
    }

    /// 「关于我」主页
    public struct MeHomePage: Codable, Hashable, Sendable {
        public var caption: String
        public var composition: MeComposition
        public var angles: [MeAngle]
        public var recipe: MeRecipe?
        public var changes: [MeChange]
        public var waiting: [MeWaiting]
        public var findings: [FindingView]
    }

    /// 说的和做的
    public struct CareRow: Codable, Hashable, Sendable {
        public struct Said: Codable, Hashable, Sendable {
            /// goal、insight
            public var kind: String
            public var day: String
            public var text: String
            public var entryId: Int?
            public var noteId: Int?
        }

        public var key: String
        public var name: String
        public var said: [Said]
        public var minutes: Double?
        public var money: Double?
        public var text: String
        public var weekendMinutes: Double?
        public var share: Double?
        public var days: [String]
    }

    public struct MeCare: Codable, Hashable, Sendable {
        public var rows: [CareRow]
        public var hidden: Bool
    }

    /// 时间去向的一类
    public struct TimeItem: Codable, Hashable, Sendable {
        public var category: String
        public var name: String
        public var emoji: String
        public var color: String
        public var minutes: Double
        public var share: Double
    }

    struct TimePage: Codable {
        var items: [TimeItem]
    }

    public struct MeCount: Codable, Hashable, Sendable {
        public var name: String
        public var count: Int
        public var days: [String]
    }

    public struct MeQuote: Codable, Hashable, Sendable {
        public var text: String
        public var day: String
        public var noteId: Int

        public init(text: String, day: String, noteId: Int) {
            self.text = text
            self.day = day
            self.noteId = noteId
        }
    }
}

extension APIClient {
    public func meHome() async throws(APIError) -> API.MeHomePage { try await get("/api/about/home") }

    public func meCare() async throws(APIError) -> API.MeCare { try await get("/api/about/care") }

    /// 时间去向：说了时长的事按类别占比（days：7、30、90）
    public func timeGone(days: Int) async throws(APIError) -> [API.TimeItem] {
        let page: API.TimePage = try await get("/api/board/time?days=\(days)")
        return page.items
    }

    /// 这周的新发现：说中了 · 早知道 · 没意思 · 不对（nil 是撤销）
    public func vote(about key: String, _ vote: String?) async throws(APIError) {
        let _: Empty = try await request(
            "POST", "/api/about/findings/vote",
            json: .object(["key": .string(key), "vote": vote.map { .string($0) } ?? .null]))
    }

    /// 「说的和做的」不想看（hidden false 是恢复）
    public func hideCare(_ hidden: Bool) async throws(APIError) {
        let _: Empty = try await request(
            "POST", "/api/about/hide", json: .object(["key": .string("care"), "hidden": .bool(hidden)]))
    }
}
