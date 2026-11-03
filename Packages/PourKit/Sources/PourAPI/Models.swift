import Foundation

/// 服务器的数据（shared/src/entries.ts、types.ts、goals.ts 原样）：手机直接用服务器的接口，
/// 业务规则和 AI 全在 Pour 服务器上（产品主人 2026-10-19 选的 B：不在手机上重写）
public enum API {}

extension API {
    /// GET /api/meta
    public struct Meta: Codable, Hashable, Sendable {
        public var today: String
        public var dayBoundary: Int
        public var mode: String?
        /// 接口的版本（docs/模块/产品优化.md R8，服务器 2.7.0 起有；以前的服务器没有）
        public var api: APIInfo?
        /// 服务器自己的版本号（「2.7.0」）
        public var server: String?
    }

    /// 接口的版本：服务器现在是第几版、还认的最旧的 App
    public struct APIInfo: Codable, Hashable, Sendable {
        public var version: Int
        public var minClient: Int
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
        /// 语录（docs/模块/产品优化.md R4）：用户说「记一句」让记的，quote 就是那句话
        public var saying: Bool?
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
        /// 重复（3.0 第 2 步）：每天、工作日、每周几、每月几号
        public var `repeat`: Repeat?
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
        /// 健康 App 来的（docs/模块/产品优化.md R5）：你没说、手表或手机记的，只能看（编号是负数）；服务器 2.6.0 起有
        public var origin: String?
        /// 你说的这条里，哪几样是健康 App 补上的（「时间」「时长」「距离」）
        public var fromHealth: [String]?

        public var pending: Bool { status == "confirm" }
        /// 健康 App 记的这一条（改、删在健康 App 里）
        public var fromHealthApp: Bool { origin == "health" }
        public var kind: String {
            switch data {
            case .event: "event"
            case .insight: "insight"
            case .todo: "todo"
            case .mood: "mood"
            }
        }

        enum CodingKeys: String, CodingKey {
            case id, day, confidence, status, question, category, kind, data, sources, related, origin, fromHealth
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
            origin = try box.decodeIfPresent(String.self, forKey: .origin)
            fromHealth = try box.decodeIfPresent([String].self, forKey: .fromHealth)
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
            try box.encodeIfPresent(origin, forKey: .origin)
            try box.encodeIfPresent(fromHealth, forKey: .fromHealth)
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
        /// 这一天说到的人、东西、地方、话题，以前说到过多少（服务器 2.1.0 起有，以前的服务器没有）
        public var mentions: [MentionHistory]?
        /// 我的卡片（docs/模块/产品优化.md R3）：说一句建的，服务器按这一天现算
        public var cards: [CardView]?
        /// 健康 App 的步数（R5，服务器 2.6.0 起有；没接健康、没有数据时没有）
        public var health: DayHealth?
    }

    /// 画布「说到的」：一个名字以前说到过多少（服务器 shared/src/mentions.ts，全部由程序数）
    public struct MentionHistory: Codable, Hashable, Sendable {
        /// person / thing / place / tag（话题）
        public var kind: String
        public var name: String
        /// 这一周（周一到这天）有几天说到，含这天
        public var weekDays: Int
        /// 这天第一次说到（以前记了不到 7 天的不算）
        public var firstTime: Bool

        public init(kind: String, name: String, weekDays: Int, firstTime: Bool) {
            self.kind = kind
            self.name = name
            self.weekDays = weekDays
            self.firstTime = firstTime
        }
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
        /// 引用的原话（[#12] 指向它们）
        public var sources: [AnswerSource]?
        public var charts: [ChartSpec]?
        /// 提到的周报、月报：回答下面放一个「查看完整报告」
        public var reports: [ReportLink]?
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
        /// 画布上的卡片和名字变了（docs/模块/产品优化.md R3、R2）：「🗂 新卡片：今年读的书」
        public var cards: [String]?
        public var advanced: [String]?
        public var answer: Answer?
        public var awaiting: Awaiting?
    }

    /// 一段原话：pending 排队、processing 整理中、done、confirm 等确认、failed 处理失败
    public struct Note: Codable, Hashable, Sendable, Identifiable {
        public var id: Int
        public var text: String
        public var createdAt: String
        /// 归到哪一天；补记的是补记的那一天
        public var day: String
        /// 补记（docs/模块/产品优化.md R1.1）：看以前的某一天时说的，记到那一天；createdAt 还是真的说话时刻
        public var backfill: Bool?
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
        /// 一共有多少条记录
        public var count: Int?
    }

    public struct CategoriesPage: Codable, Hashable, Sendable {
        public var categories: [Category]
        /// 整理建议（设置页「类别」最上面）
        public var suggestions: [CategorySuggestion]?
    }
}
