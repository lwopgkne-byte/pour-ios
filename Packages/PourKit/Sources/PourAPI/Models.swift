public import Foundation

/// 网页版服务器的数据（shared/src/entries.ts、types.ts、goals.ts 原样）：手机直接用网页版的接口，
/// 业务规则和 AI 全在网页版的服务器上（产品主人 2026-10-19 选的 B：复刻网页版，不在手机上重写）
public enum API {}

extension API {
    /// GET /api/meta
    public struct Meta: Codable, Hashable, Sendable {
        public var today: String
        public var dayBoundary: Int
        public var mode: String?
    }

    /// 一个数：钱、距离、页数……
    public struct Metric: Codable, Hashable, Sendable {
        public struct Returned: Codable, Hashable, Sendable {
            public var amount: Double
            /// refund 退款、aa AA 转回来
            public var why: String
        }

        public var name: String
        public var value: Double
        public var unit: String
        public var item: String?
        public var forWhom: String?
        /// reimburse 能报销、lend 借出去、repay / reimbursed / refund 回来的钱
        public var flag: String?
        public var settled: Bool?
        public var pack: Double?
        public var ended: Bool?
        public var monthly: Bool?
        public var from: String?
        public var returned: Returned?

        enum CodingKeys: String, CodingKey {
            case name, value, unit, item, flag, settled, pack, ended, monthly, from, returned
            case forWhom = "for"
        }

        public init(name: String, value: Double, unit: String, item: String? = nil, forWhom: String? = nil) {
            self.name = name
            self.value = value
            self.unit = unit
            self.item = item
            self.forWhom = forWhom
        }
    }

    public struct Verdict: Codable, Hashable, Sendable {
        /// good 值、regret 后悔
        public var tone: String
        public var quote: String
        public var said: String?
    }

    public struct Renqing: Codable, Hashable, Sendable {
        /// out 送出、in 收到
        public var dir: String
        public var occasion: String
        public var treat: Bool?
    }

    public struct EventData: Codable, Hashable, Sendable {
        public var label: String
        public var start: String?
        public var end: String?
        public var durationMin: Int?
        public var metrics: [Metric]?
        public var note: String?
        public var people: [String]?
        public var things: [String]?
        public var places: [String]?
        public var tags: [String]?
        public var verdict: Verdict?
        public var renqing: Renqing?

        public init(
            label: String, start: String? = nil, end: String? = nil, durationMin: Int? = nil, metrics: [Metric]? = nil
        ) {
            self.label = label
            self.start = start
            self.end = end
            self.durationMin = durationMin
            self.metrics = metrics
        }
    }

    public struct InsightData: Codable, Hashable, Sendable {
        public var title: String
        public var quote: String
        public var tags: [String]
    }

    public struct TodoData: Codable, Hashable, Sendable {
        public var content: String
        public var due: String?
        public var done: Bool
        public var remindAt: String?
        public var reminded: Bool?
        public var people: [String]?
        public var things: [String]?
        public var places: [String]?
    }

    public struct MoodData: Codable, Hashable, Sendable {
        /// 1–5
        public var mood: Double
        public var energy: Double?
        public var emotions: [String]
        public var tone: String?
        public var strength: String?
        public var moment: String?
        public var byYou: Bool?
    }

    /// 一条记录的内容（按种类）
    public enum Payload: Hashable, Sendable {
        case event(EventData)
        case insight(InsightData)
        case todo(TodoData)
        case mood(MoodData)
    }

    /// 记录来自哪段原话
    public struct Source: Codable, Hashable, Sendable {
        public var noteId: Int
        public var span: String
        public var action: String
        public var text: String
        public var createdAt: String
    }

    public struct Related: Codable, Hashable, Sendable {
        public var noteId: Int?
        public var day: String
        public var text: String
    }

    /// 画布上的一条记录（EntryView：带着来源，感悟还带着意思相近的旧笔记）
    public struct Entry: Codable, Hashable, Sendable, Identifiable {
        public var id: Int
        public var day: String
        public var confidence: Double
        /// ok、confirm（待确认）
        public var status: String
        public var question: String?
        /// 事件是类别 key，别的是 insight / todo / mood
        public var category: String
        public var data: Payload
        public var sources: [Source]
        public var related: [Related]?

        public var pending: Bool { status == "confirm" }
        public var kind: String {
            switch data {
            case .event: "event"
            case .insight: "insight"
            case .todo: "todo"
            case .mood: "mood"
            }
        }

        enum CodingKeys: String, CodingKey {
            case id, day, confidence, status, question, category, kind, data, sources, related
        }

        public init(from decoder: any Decoder) throws {
            let box = try decoder.container(keyedBy: CodingKeys.self)
            id = try box.decode(Int.self, forKey: .id)
            day = try box.decode(String.self, forKey: .day)
            confidence = try box.decodeIfPresent(Double.self, forKey: .confidence) ?? 1
            status = try box.decodeIfPresent(String.self, forKey: .status) ?? "ok"
            question = try box.decodeIfPresent(String.self, forKey: .question)
            category = try box.decode(String.self, forKey: .category)
            sources = try box.decodeIfPresent([Source].self, forKey: .sources) ?? []
            related = try box.decodeIfPresent([Related].self, forKey: .related)
            switch try box.decode(String.self, forKey: .kind) {
            case "event": data = .event(try box.decode(EventData.self, forKey: .data))
            case "insight": data = .insight(try box.decode(InsightData.self, forKey: .data))
            case "todo": data = .todo(try box.decode(TodoData.self, forKey: .data))
            default: data = .mood(try box.decode(MoodData.self, forKey: .data))
            }
        }

        public func encode(to encoder: any Encoder) throws {
            var box = encoder.container(keyedBy: CodingKeys.self)
            try box.encode(id, forKey: .id)
            try box.encode(day, forKey: .day)
            try box.encode(confidence, forKey: .confidence)
            try box.encode(status, forKey: .status)
            try box.encodeIfPresent(question, forKey: .question)
            try box.encode(category, forKey: .category)
            try box.encode(kind, forKey: .kind)
            try box.encode(sources, forKey: .sources)
            try box.encodeIfPresent(related, forKey: .related)
            switch data {
            case .event(let value): try box.encode(value, forKey: .data)
            case .insight(let value): try box.encode(value, forKey: .data)
            case .todo(let value): try box.encode(value, forKey: .data)
            case .mood(let value): try box.encode(value, forKey: .data)
            }
        }
    }

    /// 这一天相关的目标
    public struct DayGoal: Codable, Hashable, Sendable, Identifiable {
        public var id: Int
        public var title: String
        /// good / warn / bad / none
        public var tone: String
        public var pct: Double
        public var headline: String
        public var delta: String?
        public var category: String?
    }

    /// GET /api/day/:date
    public struct DayView: Codable, Hashable, Sendable {
        public var day: String
        public var entries: [Entry]
        public var summary: String?
        public var goals: [DayGoal]
    }

    /// 收据里的一项
    public struct ReceiptItem: Codable, Hashable, Sendable {
        public var action: String
        public var kind: String
        public var entryId: Int
        public var text: String
        public var pending: Bool
    }

    /// 提问的回答（先只要文字；来源和图表以后搬）
    public struct Answer: Codable, Hashable, Sendable {
        public var text: String
    }

    public struct Awaiting: Codable, Hashable, Sendable {
        /// 在等确认的是什么（现在只有 delete）
        public var operation: String
        public var entryIds: [Int]

        enum CodingKeys: String, CodingKey {
            case operation = "op"
            case entryIds
        }
    }

    /// 一段原话整理完的结果
    public struct NoteResult: Codable, Hashable, Sendable {
        public var receipt: [ReceiptItem]
        public var reply: String
        public var questions: [String]
        public var notices: [String]
        public var undone: Bool?
        public var created: [String]?
        public var learned: [String]?
        public var goals: [String]?
        public var advanced: [String]?
        public var answer: Answer?
        public var awaiting: Awaiting?
    }

    /// 一段原话：pending 排队、processing 整理中、done、confirm 等确认、failed 处理失败
    public struct Note: Codable, Hashable, Sendable, Identifiable {
        public var id: Int
        public var text: String
        public var createdAt: String
        public var day: String
        public var status: String
        public var result: NoteResult?
        public var error: String?
    }

    public struct NotesPage: Codable, Hashable, Sendable {
        public var notes: [Note]
        public var hasMore: Bool?
    }

    /// 最近 7 天
    public struct Trend: Codable, Hashable, Sendable {
        public struct Point: Codable, Hashable, Sendable {
            public var day: String
            public var value: Double?
            public var values: [Double]?
        }

        public var label: String
        public var unit: String
        public var points: [Point]
    }

    /// 类别表的一项
    public struct Category: Codable, Hashable, Sendable {
        public var key: String
        public var name: String
        public var emoji: String
        public var color: String
        public var parent: String?
        public var measure: String
        public var synonyms: [String]?
    }

    public struct CategoriesPage: Codable, Hashable, Sendable {
        public var categories: [Category]
    }
}
