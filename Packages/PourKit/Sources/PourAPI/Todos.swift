import Foundation

/// 待办 2.0 四象限（docs/todo-2.0；服务器 shared/src/todos.ts TODO_QUADRANTS）：颜色永远配图标，不只靠颜色分
public enum TodoQuadrant: Int, CaseIterable, Sendable, Hashable {
    /// 还没分：AI 拿不准、旧数据，等你点一下
    case unsorted = 0
    /// 马上做：重要 · 紧急
    case doNow = 1
    /// 排时间：重要 · 不急
    case schedule = 2
    /// 快速办：紧急 · 不重要
    case quick = 3
    /// 放一放：不急 · 不重要
    case later = 4

    /// 四个能选的（还没分不算）：左上马上做、右上排时间、左下快速办、右下放一放
    public static let sorted: [TodoQuadrant] = [.doNow, .schedule, .quick, .later]

    public var title: String {
        switch self {
        case .unsorted: "还没分"
        case .doNow: "马上做"
        case .schedule: "排时间"
        case .quick: "快速办"
        case .later: "放一放"
        }
    }

    public var subtitle: String {
        switch self {
        case .unsorted: "AI 拿不准"
        case .doNow: "重要 · 紧急"
        case .schedule: "重要 · 不急"
        case .quick: "紧急 · 不重要"
        case .later: "不急 · 不重要"
        }
    }

    /// 圈里、标题旁的图标（SF Symbol）；还没分是空心圈，没有图标
    public var symbol: String? {
        switch self {
        case .unsorted: nil
        case .doNow: "flame.fill"
        case .schedule: "star.fill"
        case .quick: "bolt.fill"
        case .later: "cloud.fill"
        }
    }
}

/// 待办 2.0 时间段：只说了上午、下午、晚上（和具体钟点二选一）；时段开头轻提醒一次
public enum TimeWindow: String, CaseIterable, Sendable, Hashable {
    case morning, afternoon, evening

    public var title: String {
        switch self {
        case .morning: "上午"
        case .afternoon: "下午"
        case .evening: "晚上"
        }
    }

    /// 时段开头轻提醒的钟点（服务器 WINDOW_NUDGES；之后做进设置）
    public var nudge: String {
        switch self {
        case .morning: "09:00"
        case .afternoon: "14:00"
        case .evening: "19:00"
        }
    }

    /// 这个时段从几点到几点（判断现在在不在这个时段、追问时给哪几个钟点）
    public var hours: ClosedRange<Int> {
        switch self {
        case .morning: 6...11
        case .afternoon: 12...17
        case .evening: 18...23
        }
    }
}

/// 3.0 待办（docs/3.0/01-需求文档.md 第 4 章、06 交互细节第 2 节；服务器 2.10.0 的 `/api/todos`，
/// 字段和 shared/src/todos.ts、when.ts 一字不差）
extension API {
    /// 重复：每天、工作日、每周几（周一是 0）、每月几号
    public enum Repeat: Codable, Hashable, Sendable {
        case daily
        case weekdays
        case weekly([Int])
        case monthly(Int)

        enum CodingKeys: String, CodingKey { case kind, days, day }

        public init(from decoder: any Decoder) throws {
            let box = try decoder.container(keyedBy: CodingKeys.self)
            switch try box.decode(String.self, forKey: .kind) {
            case "weekdays": self = .weekdays
            case "weekly": self = .weekly(try box.decode([Int].self, forKey: .days))
            case "monthly": self = .monthly(try box.decode(Int.self, forKey: .day))
            default: self = .daily
            }
        }

        public func encode(to encoder: any Encoder) throws {
            var box = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .daily: try box.encode("daily", forKey: .kind)
            case .weekdays: try box.encode("weekdays", forKey: .kind)
            case .weekly(let days):
                try box.encode("weekly", forKey: .kind)
                try box.encode(days, forKey: .days)
            case .monthly(let day):
                try box.encode("monthly", forKey: .kind)
                try box.encode(day, forKey: .day)
            }
        }

        public var json: JSONValue {
            switch self {
            case .daily: .object(["kind": .string("daily")])
            case .weekdays: .object(["kind": .string("weekdays")])
            case .weekly(let days):
                .object(["kind": .string("weekly"), "days": .array(days.map { .number(Double($0)) })])
            case .monthly(let day): .object(["kind": .string("monthly"), "day": .number(Double(day))])
            }
        }
    }

    public struct TodoRow: Codable, Hashable, Sendable, Identifiable {
        public let id: Int
        public var content: String
        /// 哪天做：有期限按期限，没有按说的那天
        public var day: String
        /// 提醒的钟点（HH:MM）；不提醒是 nil
        public var remindAt: String?
        public var done: Bool
        public var doneAt: String?
        public var `repeat`: Repeat?
        /// 「每周一、三」「工作日」
        public var repeatText: String?
        /// 哪天做已经过了、还没做完
        public var overdue: Bool
        /// 推迟以前最早的那个时间
        public var snoozedFrom: String?
        public var people: [String]
        public var things: [String]
        public var places: [String]
        /// 建它的那段原话
        public var source: Source?
        /// 待办 2.0：象限（0 还没分）。旧服务器、旧缓存没有这几样，都是可选的，解码不会坏
        public var quadrant: Int?
        /// 象限是 AI 猜的
        public var quadrantByAI: Bool?
        /// 只说了上午、下午、晚上（morning · afternoon · evening）；认不出的当没有
        public var window: String?
        /// 以后再说：不定日子
        public var someday: Bool?
        /// 你排的顺序（同一天里第几个，清单里拖过才有；服务器 2.21 起有）
        public var order: Int?
        /// 到点响铃：像闹钟一样叫（服务器 2.22 起有；只对有钟点的是 true）
        public var alarm: Bool?

        public var lane: TodoQuadrant { TodoQuadrant(rawValue: quadrant ?? 0) ?? .unsorted }
        /// 到点像闹钟一样响（有钟点、开了响铃）
        public var rings: Bool { alarm == true && remindAt != nil }
        public var guessed: Bool { quadrantByAI == true && lane != .unsorted }
        public var timeWindow: TimeWindow? { window.flatMap(TimeWindow.init(rawValue:)) }
        public var isSomeday: Bool { someday == true }

        public struct Source: Codable, Hashable, Sendable {
            public let noteId: Int
            public let text: String
            /// 什么时候说的（ISO 时刻；服务器 2.10.0 起有）
            public let at: String?

            public init(noteId: Int, text: String, at: String? = nil) {
                self.noteId = noteId
                self.text = text
                self.at = at
            }
        }

        public init(
            id: Int, content: String, day: String, remindAt: String? = nil, done: Bool = false, doneAt: String? = nil,
            repeat rule: Repeat? = nil, repeatText: String? = nil, overdue: Bool = false, snoozedFrom: String? = nil,
            people: [String] = [], things: [String] = [], places: [String] = [], source: Source? = nil,
            quadrant: TodoQuadrant = .unsorted, guessed: Bool = false, window: TimeWindow? = nil, someday: Bool = false,
            alarm: Bool = false
        ) {
            self.id = id
            self.content = content
            self.day = day
            self.remindAt = remindAt
            self.done = done
            self.doneAt = doneAt
            self.repeat = rule
            self.repeatText = repeatText
            self.overdue = overdue
            self.snoozedFrom = snoozedFrom
            self.people = people
            self.things = things
            self.places = places
            self.source = source
            self.quadrant = quadrant.rawValue
            self.quadrantByAI = guessed
            self.window = window?.rawValue
            self.someday = someday
            self.alarm = alarm
        }
    }

    public struct TodoGroup: Codable, Hashable, Sendable, Identifiable {
        /// overdue · today · tomorrow · week · later · done
        public let key: String
        /// 「以前没做完的」「今天 · 10月27日 周二」「明天」「这周」「以后」「已完成」
        public var title: String
        public var rows: [TodoRow]

        public var id: String { key }

        public init(key: String, title: String, rows: [TodoRow]) {
            self.key = key
            self.title = title
            self.rows = rows
        }
    }

    public struct TodoPage: Codable, Hashable, Sendable {
        public let today: String
        /// 只有有东西的组（「今天」一直在），顺序就是页面上的顺序
        public var groups: [TodoGroup]
        /// 还没做完的一共几件（今天和以前的）
        public var open: Int

        public init(today: String, groups: [TodoGroup], open: Int) {
            self.today = today
            self.groups = groups
            self.open = open
        }
    }

    /// 手机排系统通知用：没做完、带提醒、还没到点的
    public struct TodoReminder: Codable, Hashable, Sendable {
        public let id: Int
        public let content: String
        /// 本地时刻 YYYY-MM-DDTHH:MM
        public let at: String
        /// 哪天说的（通知正文「你 10月26日说的」）
        public let said: String?
        /// 待办 2.0：只说了时间段的轻提醒（morning / afternoon / evening）；有钟点的、旧服务器是 nil
        public let window: String?
        /// 到点响铃：排成系统闹钟（服务器 2.22 起有）
        public let alarm: Bool?
    }

    /// 快加时边打边认的结果（服务器 parseWhen）
    public struct When: Codable, Hashable, Sendable {
        public let day: String?
        public let time: String?
        public let `repeat`: Repeat?
        public let repeatText: String?
        /// 认出来的字在原话里的位置 [开始, 结束)：JS 的下标（UTF-16）
        public let spans: [[Int]]
        /// 去掉时间以后要做的事
        public let title: String
        /// 「明天 15:00」「今天下午」；什么都没认出是 nil
        public let label: String?
        /// 待办 2.0：只说了上午、下午、晚上（没说几点）；旧服务器没有
        public let window: String?
    }

    /// 收据里一件待办现在的样子（说一句的结果卡片：哪一格 · 哪天 · 几点）
    public struct ReceiptTodo: Codable, Hashable, Sendable {
        public var content: String
        /// 哪天；以后再说是 nil
        public var day: String?
        /// 几点（HH:MM）
        public var time: String?
        public var window: String?
        public var quadrant: Int
        /// 格子是 AI 猜的
        public var guessed: Bool
        /// 到点响铃（服务器 2.22 起有）
        public var alarm: Bool?

        public init(
            content: String, day: String?, time: String?, window: String?, quadrant: Int, guessed: Bool,
            alarm: Bool = false
        ) {
            self.content = content
            self.day = day
            self.time = time
            self.window = window
            self.quadrant = quadrant
            self.guessed = guessed
            self.alarm = alarm
        }

        /// 到点像闹钟一样响（有钟点、开了响铃）
        public var rings: Bool { alarm == true && time != nil }

        public var lane: TodoQuadrant { TodoQuadrant(rawValue: quadrant) ?? .unsorted }
        public var timeWindow: TimeWindow? { window.flatMap(TimeWindow.init(rawValue:)) }
    }

    struct TodoReminders: Codable, Sendable { let reminders: [TodoReminder] }
    struct TodoOne: Codable, Sendable { let todo: TodoRow }
    struct TodoAdded: Codable, Sendable { let todo: TodoRow? }
    struct TodoNext: Codable, Sendable { let next: TodoRow? }
    struct TodoMoved: Codable, Sendable { let moved: [Int] }
}

/// 推迟到哪（服务器算具体时刻）
public enum SnoozePreset: String, CaseIterable, Sendable {
    case hour, tonight, tomorrow, saturday, monday
}

extension APIClient {
    public func todos() async throws(APIError) -> API.TodoPage { try await get("/api/todos") }

    /// 全部没做完、带提醒、还没到点的（最近 60 条）：排系统通知用
    public func todoReminders() async throws(APIError) -> [API.TodoReminder] {
        let page: API.TodoReminders = try await get("/api/todos?reminders=1")
        return page.reminders
    }

    /// 只认不建（加待办时边打边认）
    public func parseWhen(_ text: String) async throws(APIError) -> API.When {
        try await request("POST", "/api/todos/parse", json: .object(["text": .string(text)]))
    }

    /// 快加：原话先存，程序认好时间马上建好；clientId 防重复
    @discardableResult
    public func addTodo(_ text: String, clientId: String) async throws(APIError) -> API.TodoRow? {
        let added: API.TodoAdded = try await request(
            "POST", "/api/todos", json: .object(["text": .string(text), "clientId": .string(clientId)]))
        return added.todo
    }

    public func snooze(todo id: Int, to preset: SnoozePreset) async throws(APIError) -> API.TodoRow {
        let one: API.TodoOne = try await request(
            "POST", "/api/todos/\(id)/snooze", json: .object(["preset": .string(preset.rawValue)]))
        return one.todo
    }

    /// 推迟到自己挑的那天那个钟点（time 是 nil：只挪日子、不提醒）
    public func snooze(todo id: Int, day: String, time: String?) async throws(APIError) -> API.TodoRow {
        let one: API.TodoOne = try await request(
            "POST", "/api/todos/\(id)/snooze",
            json: .object(["day": .string(day), "time": time.map(JSONValue.string) ?? .null]))
        return one.todo
    }

    /// 详情里改：只改给了的；time、repeat、window 用 .some(nil) 表示「不提醒」「不重复」「不要时间段」
    public func editTodo(
        _ id: Int, content: String? = nil, day: String? = nil, time: String?? = nil, repeat rule: API.Repeat?? = nil,
        quadrant: TodoQuadrant? = nil, window: TimeWindow?? = nil, someday: Bool? = nil
    ) async throws(APIError) -> API.TodoRow {
        var body: [String: JSONValue] = [:]
        if let content { body["content"] = .string(content) }
        if let day { body["day"] = .string(day) }
        if let time { body["time"] = time.map(JSONValue.string) ?? .null }
        if let rule { body["repeat"] = rule?.json ?? .null }
        if let quadrant { body["quadrant"] = .number(Double(quadrant.rawValue)) }
        if let window { body["window"] = window.map { .string($0.rawValue) } ?? .null }
        if let someday { body["someday"] = .bool(someday) }
        let one: API.TodoOne = try await request("PATCH", "/api/todos/\(id)", json: .object(body))
        return one.todo
    }

    /// 重复的「只删这一次」：回下一次的那条
    @discardableResult
    public func skipTodo(_ id: Int) async throws(APIError) -> API.TodoRow? {
        let next: API.TodoNext = try await request("POST", "/api/todos/\(id)/skip")
        return next.next
    }

    /// 以前没做完的带到今天（ids 是 nil：全部）
    @discardableResult
    public func carryTodos(_ ids: [Int]? = nil) async throws(APIError) -> [Int] {
        let body: JSONValue = ids.map { .object(["ids": .array($0.map { .number(Double($0)) })]) } ?? .object([:])
        let moved: API.TodoMoved = try await request("POST", "/api/todos/carry", json: body)
        return moved.moved
    }
}
