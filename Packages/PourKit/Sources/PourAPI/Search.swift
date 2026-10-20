public import Foundation

// 搜索（服务器 routes/search.ts 的 SearchResult）和回答（shared answer.ts），字段名一字不差
extension API {
    public struct SearchResult: Codable, Hashable, Sendable {
        public struct Hit: Codable, Hashable, Sendable {
            /// note 原话、insight 感悟
            public var kind: String
            public var noteId: Int?
            public var entryId: Int?
            public var day: String
            public var text: String
            /// keyword、semantic（按意思找到的）、both
            public var via: String
        }

        public struct Goal: Codable, Hashable, Sendable {
            public var id: Int
            public var title: String
            public var status: String
        }

        public struct Semantic: Codable, Hashable, Sendable {
            /// ready、loading（第一次要准备本地模型）、failed
            public var state: String
            public var message: String?
        }

        public var hits: [Hit]
        public var goals: [Goal]
        /// 输入的是日期（「9月3日」）：打开那一天
        public var day: String?
        public var semantic: Semantic?
    }
}

extension APIClient {
    /// 全局搜索：不经过 AI，原话、感悟（关键词 + 按意思）、目标和日期
    public func search(_ text: String) async throws(APIError) -> API.SearchResult {
        let query = text.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? text
        return try await get("/api/search?q=\(query)")
    }
}

// 回答里的来源和图表（shared answer.ts）
extension API {
    /// 回答引用的一段原话
    public struct AnswerSource: Codable, Hashable, Sendable {
        public var noteId: Int
        public var day: String
        public var text: String
    }

    public struct ReportLink: Codable, Hashable, Sendable {
        public var id: Int
        public var title: String
    }

    /// 图表里的一个点（没有数的那天是 nil）
    public struct ChartPoint: Codable, Hashable, Sendable {
        public var label: String
        public var value: Double?
    }

    public struct ChartDay: Codable, Hashable, Sendable {
        public var day: String
        public var value: Double
    }

    public struct ChartSpan: Codable, Hashable, Sendable {
        public var day: String
        public var start: String
        public var end: String
        public var label: String
        public var color: String
    }

    /// 对话里的图表（规格 5.4 的白名单）：折线、柱状、环形进度、热力图、时间轴
    public enum ChartSpec: Codable, Hashable, Sendable {
        public struct Series: Codable, Hashable, Sendable {
            /// line、bar
            public var type: String
            public var title: String
            /// 单位；时刻类（入睡时间）是 time，数值是当天的分钟数；心情是 mood
            public var unit: String
            public var points: [ChartPoint]
            public var trend: [Double?]?
            public var target: Double?

            public init(
                type: String, title: String, unit: String, points: [ChartPoint], trend: [Double?]?, target: Double?
            ) {
                self.type = type
                self.title = title
                self.unit = unit
                self.points = points
                self.trend = trend
                self.target = target
            }
        }

        public struct Ring: Codable, Hashable, Sendable {
            public var title: String
            public var unit: String
            public var value: Double
            public var target: Double
            public var pct: Double
            public var tone: String
            public var headline: String
        }

        public struct Heatmap: Codable, Hashable, Sendable {
            public var title: String
            public var unit: String
            public var days: [ChartDay]

            public init(title: String, unit: String, days: [ChartDay]) {
                self.title = title
                self.unit = unit
                self.days = days
            }
        }

        public struct Timeline: Codable, Hashable, Sendable {
            public var title: String
            public var items: [ChartSpan]
        }

        case series(Series)
        case ring(Ring)
        case heatmap(Heatmap)
        case timeline(Timeline)
        /// 以后加的种类：不认识就不画
        case unknown(String)

        enum CodingKeys: String, CodingKey { case type, title }

        public init(from decoder: any Decoder) throws {
            let box = try decoder.container(keyedBy: CodingKeys.self)
            switch try box.decode(String.self, forKey: .type) {
            case "line", "bar": self = .series(try Series(from: decoder))
            case "ring": self = .ring(try Ring(from: decoder))
            case "heatmap": self = .heatmap(try Heatmap(from: decoder))
            case "timeline": self = .timeline(try Timeline(from: decoder))
            case let other: self = .unknown(other)
            }
        }

        /// 存下来（对话的缓存）时原样写回去，带着 type
        public func encode(to encoder: any Encoder) throws {
            var box = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .series(let spec): try spec.encode(to: encoder)
            case .ring(let spec):
                try spec.encode(to: encoder)
                try box.encode("ring", forKey: .type)
            case .heatmap(let spec):
                try spec.encode(to: encoder)
                try box.encode("heatmap", forKey: .type)
            case .timeline(let spec):
                try spec.encode(to: encoder)
                try box.encode("timeline", forKey: .type)
            case .unknown(let type): try box.encode(type, forKey: .type)
            }
        }

        public var title: String {
            switch self {
            case .series(let spec): spec.title
            case .ring(let spec): spec.title
            case .heatmap(let spec): spec.title
            case .timeline(let spec): spec.title
            case .unknown: ""
            }
        }
    }
}

extension API {
    /// 一份周报、月报（问答里「查看完整报告」要它是哪一期）
    /// 一期报告是哪种、从哪天起
    public struct ReportPeriod: Decodable, Hashable, Sendable {
        public struct Period: Decodable, Hashable, Sendable {
            public var from: String
        }

        /// weekly、monthly
        public var kind: String
        public var period: Period
    }

    public struct ReportMessage: Decodable, Hashable, Sendable {
        public var report: ReportPeriod?
    }
}

extension APIClient {
    public func report(_ id: Int) async throws(APIError) -> API.ReportMessage { try await get("/api/reports/\(id)") }
}

extension Show {
    /// 心情、精力的平均怎么说（shared between）：整数是那一级，不是整数说「在一般和挺好之间」
    public static func between(_ value: Double, words: [String]) -> String {
        let rounded = (value * 10).rounded() / 10
        let word = { (level: Double) in words[min(5, max(1, Int(level))) - 1] }
        if rounded <= 1 || rounded >= 5 || rounded == rounded.rounded() { return word(rounded.rounded()) }
        return "在\(word(rounded.rounded(.down)))和\(word(rounded.rounded(.up)))之间"
    }
}
