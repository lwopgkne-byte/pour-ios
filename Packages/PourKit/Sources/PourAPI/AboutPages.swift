public import Foundation

// 关于我点进去的几页：心情、人、你说的话、你的一年、一块生活（shared me-pages.ts、me-talk.ts、me-themes.ts、me-year.ts）
extension API {
    public struct MeWeekMood: Codable, Hashable, Sendable {
        public struct Bar: Codable, Hashable, Sendable {
            public var value: Double?
            public var days: Int
        }

        public var bars: [Bar]
        public var low: Int?
        public var high: Int?
        public var sentence: String
        public var check: String
    }

    public struct MeMomentRow: Codable, Hashable, Sendable {
        public struct Moment: Codable, Hashable, Sendable {
            public var day: String
            public var text: String
            public var noteId: Int?
        }

        public var key: String
        public var name: String
        public var color: String
        public var count: Int
        public var moments: [Moment]
    }

    public struct MeFeeling: Codable, Hashable, Sendable {
        public var word: String
        public var count: Int
        /// good、bad、unclear
        public var group: String
        /// 1–4：说得越多字越大
        public var size: Int
    }

    public struct MeWhenMood: Codable, Hashable, Sendable {
        public struct Part: Codable, Hashable, Sendable {
            public var name: String
            public var good: Int
            public var bad: Int
            public var days: [String]
        }

        public var parts: [Part]
        public var sentence: String
        public var timed: Int
        public var untimed: Int
    }

    public struct MeMoments: Codable, Hashable, Sendable {
        public var rows: [MeMomentRow]
        public var sentence: String
    }

    public struct MeFeelings: Codable, Hashable, Sendable {
        public var words: [MeFeeling]
        public var sentence: String
    }

    /// 心情那一页
    public struct MeMoodPage: Codable, Hashable, Sendable {
        public var span: String
        public var word: String?
        public var moodDays: Int
        public var pixels: [MeCalWeek]
        public var hasNone: Bool
        public var week: MeWeekMood?
        public var moments: MeMoments?
        public var when: MeWhenMood?
        public var feelings: MeFeelings?
        public var findings: [FindingView]
        public var changes: [MeChange]
    }

    public struct MePerson: Codable, Hashable, Sendable {
        public var name: String
        public var relation: String?
        /// family、work、other
        public var group: String
        public var days: [String]
        public var lastDay: String
        public var doing: String
        /// better、worse、same、few
        public var mood: String
        public var moodText: String
        public var former: Bool
    }

    /// 人那一页
    public struct MePeoplePage: Codable, Hashable, Sendable {
        public var span: String
        public var sentence: String
        public var people: [MePerson]
        public var findings: [FindingView]
        public var changes: [MeChange]
    }

    public struct MeTopic: Codable, Hashable, Sendable {
        public var key: String
        public var name: String
        public var color: String
        public var points: [Double?]
        public var word: String
    }

    public struct MeTheme: Codable, Hashable, Sendable {
        public var key: String
        public var name: String?
        public var notes: Int
        public var days: [String]
        public var points: [Double?]
        public var word: String
        public var quotes: [MeQuote]
    }

    public struct MeWord: Codable, Hashable, Sendable {
        public var key: String
        public var title: String
        public var label: String
        public var value: String
        public var days: [String]
    }

    public struct MeChain: Codable, Hashable, Sendable {
        public struct Step: Codable, Hashable, Sendable {
            public var label: String
            public var what: String
            public var value: String
            public var share: Double
            public var strong: Bool
        }

        public var key: String
        public var title: String
        public var first: String
        public var steps: [Step]
        public var sub: String
        public var days: [String]
    }

    /// 你说的话那一页
    public struct MeTalkPage: Codable, Hashable, Sendable {
        public var span: String
        public var clock: MeClock
        public var topics: [MeTopic]
        public var themes: [MeTheme]
        public var words: [MeWord]
        public var chains: [MeChain]
    }

    public struct MeYearMonth: Codable, Hashable, Sendable {
        public var month: String
        public var name: String
        public var mood: Double?
        public var days: Int
    }

    public struct MeYearSaid: Codable, Hashable, Sendable {
        public var day: String
        public var noteId: Int
        public var text: String
    }

    public struct MeStreak: Codable, Hashable, Sendable {
        public var days: Int
        public var from: String
        public var to: String
    }

    /// 你的一年
    public struct MeYear: Codable, Hashable, Sendable {
        public struct Person: Codable, Hashable, Sendable {
            public var name: String
            public var days: Int
        }

        public struct Emotion: Codable, Hashable, Sendable {
            public var word: String
            public var times: Int
        }

        public var year: Int
        public var span: Int
        public var recorded: Int
        public var notes: Int
        public var streak: MeStreak?
        public var tiles: [MeTile]
        public var people: [Person]
        public var months: [MeYearMonth]
        public var bestMonth: MeYearMonth?
        public var emotions: [Emotion]
        public var first: MeYearSaid?
        public var last: MeYearSaid?
        public var enough: Bool
        public var waiting: String?
        public var sentence: String
    }

    public struct MeWhenCell: Codable, Hashable, Sendable {
        public var weekday: Int
        public var part: Int
        public var count: Int
        public var level: Double
        public var days: [String]
    }

    public struct MeWhen: Codable, Hashable, Sendable {
        public var cells: [MeWhenCell]
        public var sentence: String
    }

    public struct MeMoodView: Codable, Hashable, Sendable {
        public var headline: String
        public var text: String
        public var with: Double
        public var without: Double
        public var withLabel: String
        public var withoutLabel: String
        /// better、worse、same
        public var tone: String
    }

    /// 一块生活（领域）那一页
    public struct MeDomainPage: Codable, Hashable, Sendable {
        public var key: String
        public var name: String
        public var color: String
        public var span: String
        public var headline: String
        public var sub: String
        public var person: String?
        public var calendar: [MeCalWeek]
        public var when: MeWhen?
        public var actsTitle: String
        public var acts: [MeCount]
        public var chips: [MeCount]
        public var mood: MeMoodView?
        public var quotes: [MeQuote]
        public var findings: [FindingView]
        public var changes: [MeChange]
    }
}

extension API {
    /// 一年每天一格（看板的年度热力图）
    public struct YearHeatPage: Codable, Hashable, Sendable {
        public var days: [ChartDay]
        public var unit: String
        public var label: String
    }
}

extension API {
    /// 看板上一个有数的指标（睡眠时长、入睡时间……）
    public struct BoardMetric: Codable, Hashable, Sendable {
        public var id: String
        public var name: String
        public var emoji: String
        public var category: String?
        public var unit: String
        /// sum 加起来、avg 平均、clock 时刻
        public var how: String
    }

    struct BoardMetrics: Codable {
        var metrics: [BoardMetric]
    }

    /// 一个指标按日 / 周 / 月 / 年的变化
    public struct BoardTrend: Codable, Hashable, Sendable {
        public struct Summary: Codable, Hashable, Sendable {
            public var label: String
            public var value: Double?
        }

        public var metric: BoardMetric
        public var points: [ChartPoint]
        public var trend: [Double?]?
        public var yoy: Double?
        public var target: Double?
        public var summary: Summary
        /// 心情按天看时：每一天每一条心情的级别
        public var each: [[Double]]?
    }
}

extension APIClient {
    public func boardMetrics() async throws(APIError) -> [API.BoardMetric] {
        let page: API.BoardMetrics = try await get("/api/board/metrics")
        return page.metrics
    }

    /// dim：day、week、month、year
    public func trend(_ metric: String, dim: String) async throws(APIError) -> API.BoardTrend {
        let key = metric.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? metric
        return try await get("/api/board/trend?metric=\(key)&dim=\(dim)")
    }

    /// by：count 记录量、mood 心情、category:diet 某个领域
    public func yearHeat(_ year: Int, coloring: String) async throws(APIError) -> API.YearHeatPage {
        let key = coloring.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? coloring
        return try await get(
            "/api/board/heatmap?year=\(year)&by=\(key)"
        )
    }

    public func meMood() async throws(APIError) -> API.MeMoodPage { try await get("/api/about/mood") }

    public func mePeople() async throws(APIError) -> API.MePeoplePage { try await get("/api/about/people") }

    public func meTalk() async throws(APIError) -> API.MeTalkPage { try await get("/api/about/talk") }

    public func meYear(_ year: Int) async throws(APIError) -> API.MeYear { try await get("/api/about/year/\(year)") }

    public func meDomain(_ key: String) async throws(APIError) -> API.MeDomainPage {
        try await get("/api/about/domain/\(key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key)")
    }
}
