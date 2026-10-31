public import Foundation

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
            people: [String] = [], things: [String] = [], places: [String] = [], source: Source? = nil
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
        /// 「明天 15:00」；什么都没认出是 nil
        public let label: String?
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

    /// 详情里改：只改给了的；time、repeat 用 .some(nil) 表示「不提醒」「不重复」
    public func editTodo(
        _ id: Int, content: String? = nil, day: String? = nil, time: String?? = nil, repeat rule: API.Repeat?? = nil
    ) async throws(APIError) -> API.TodoRow {
        var body: [String: JSONValue] = [:]
        if let content { body["content"] = .string(content) }
        if let day { body["day"] = .string(day) }
        if let time { body["time"] = time.map(JSONValue.string) ?? .null }
        if let rule { body["repeat"] = rule?.json ?? .null }
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
