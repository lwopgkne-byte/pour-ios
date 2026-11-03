import Foundation

// MARK: - 请求

extension APIClient {
    public static let goalsHomePath = "/api/goals/home"

    /// 目标首页一次拿全
    public func goalsHome() async throws(APIError) -> API.GoalsHome { try await get(Self.goalsHomePath) }

    /// 一个目标的全部块；每个月的那几行（年目标拆到月）还在旧的详情里
    public func goalPage(_ id: Int) async throws(APIError) -> (page: API.GoalPage, months: [API.SubPeriod]) {
        let holder: API.GoalPageHolder = try await get("/api/goals/\(id)")
        return (holder.page, holder.monthRows ?? [])
    }

    /// 暂停 / 继续 / 标记完成 / 放下 / 再试试 / 改回进行中
    public func goalAct(_ id: Int, _ action: String, until: String? = nil, why: String? = nil) async throws(APIError)
        -> API.GoalDone
    {
        struct Body: Encodable {
            let action: String
            let until: String?
            let why: String?
        }
        return try await request("POST", "/api/goals/\(id)/act", encoding: Body(action: action, until: until, why: why))
    }

    /// 改名称、目标值、我在乎的、补假、少提醒、提醒、三句话
    public func goalSet(_ id: Int, _ change: GoalChange) async throws(APIError) -> API.GoalDone {
        try await request("POST", "/api/goals/\(id)/set", encoding: change)
    }

    public func goalMilestone(_ id: Int, index: Int, done: Bool) async throws(APIError) -> API.GoalDone {
        struct Body: Encodable {
            let index: Int
            let done: Bool
        }
        return try await request("POST", "/api/goals/\(id)/milestone", encoding: Body(index: index, done: done))
    }

    /// 回答「算不算」
    public func goalAnswer(_ id: Int, counts: Bool) async throws(APIError) -> API.GoalDone {
        try await request("POST", "/api/goals/\(id)/ask", json: .object(["counts": .bool(counts)]))
    }

    /// 撤销：恢复到改之前的版本
    public func goalUndo(_ versions: [Int]) async throws(APIError) {
        let _: Empty = try await request(
            "POST", "/api/goals/undo", json: .object(["undo": .array(versions.map { .number(Double($0)) })]))
    }

    public func goalGrow(_ id: Int) async throws(APIError) -> API.GrowPage { try await get("/api/goals/\(id)/grow") }

    /// 选了一个办法，马上生效
    public func applyGrow(_ id: Int, key: String, restart: Bool, remind: API.GoalRemind?, ifthen: String?)
        async throws(APIError) -> API.GoalDone
    {
        struct Body: Encodable {
            let key: String
            let restart: Bool
            let remind: API.GoalRemind?
            let ifthen: String?
        }
        return try await request(
            "POST", "/api/goals/\(id)/grow", encoding: Body(key: key, restart: restart, remind: remind, ifthen: ifthen))
    }

    public func goalWoop(_ id: Int) async throws(APIError) -> API.WoopPage { try await get("/api/goals/\(id)/woop") }

    public func goalsWeekly() async throws(APIError) -> API.WeeklyReview { try await get("/api/goals/weekly") }

    /// 每周回顾看完了
    public func weeklySeen(_ from: String) async throws(APIError) {
        let _: Empty = try await request(
            "POST", "/api/goals/weekly", json: .object(["seen": .bool(true), "from": .string(from)]))
    }

    /// 下周最重要的一件放进待办：回待办的编号（撤销就删它）和轻提示
    public func weeklyTodo(_ todo: API.WeeklyTodo) async throws(APIError) -> (entryId: Int, toast: String) {
        struct Out: Decodable {
            let entryId: Int
            let toast: String
        }
        let out: Out = try await request("POST", "/api/goals/weekly/todo", encoding: todo)
        return (out.entryId, out.toast)
    }

    /// 手机排的目标通知：「如果就」、每周回顾、先停一个月回来的前一天
    public func goalReminders() async throws(APIError) -> API.GoalReminderList { try await get("/api/goals/reminders") }

    public func care() async throws(APIError) -> API.CareSettings { try await get("/api/care") }

    /// 改几块、点头
    public func saveCare(areas: [API.CareArea]?, agreed: Bool?) async throws(APIError) -> API.CareSettings {
        struct Area: Encodable {
            let key: String
            let name: String
            let icon: String
            let categories: [String]
        }
        struct Body: Encodable {
            let areas: [Area]?
            let agreed: Bool?
        }
        let body = Body(
            areas: areas?.map { Area(key: $0.key, name: $0.name, icon: $0.icon, categories: $0.categories) },
            agreed: agreed)
        return try await request("PUT", "/api/care", encoding: body)
    }

    public func careDomain(_ key: String) async throws(APIError) -> API.CareDomain { try await get("/api/care/\(key)") }

    /// 这个季度打几分；回原来的分（撤销时再发一次）
    public func careScore(_ key: String, _ value: Int?) async throws(APIError) -> (toast: String, before: Int?) {
        struct Out: Decodable {
            let toast: String
            let before: Int?
        }
        let out: Out = try await request(
            "POST", "/api/care/\(key)/score", json: .object(["value": value.map { .number(Double($0)) } ?? .null]))
        return (out.toast, out.before)
    }

    /// 我想成为：「对，就这句」或者自己写一句
    public func careWish(_ key: String, text: String?, agreed: Bool) async throws(APIError) {
        struct Body: Encodable {
            let text: String?
            let agreed: Bool
        }
        let _: Empty = try await request("POST", "/api/care/\(key)/wish", encoding: Body(text: text, agreed: agreed))
    }

    /// 说一句 → 理解卡（不建任何东西）
    public func understandGoal(_ text: String) async throws(APIError) -> API.GoalUnderstand {
        try await request("POST", "/api/goals/understand", json: .object(["text": .string(text)]))
    }

    /// 理解卡上点「对」：建
    public func planGoal(_ operation: JSONValue, care: String?, children: [JSONValue]? = nil, title: String? = nil)
        async throws(APIError) -> API.GoalMade
    {
        var body: [String: JSONValue] = ["op": operation, "care": care.map { .string($0) } ?? .null]
        if let children { body["children"] = .array(children) }
        if let title { body["title"] = .string(title) }
        return try await request("POST", "/api/goals/plan", json: .object(body))
    }
}

/// 改一个目标的一样（POST /api/goals/:id/set）：没写的不改；提醒写 .some(nil) 是不提醒
public struct GoalChange: Encodable, Sendable {
    public var title: String?
    public var target: Double?
    public var care: String??
    public var restPerWeek: Int?
    public var quiet: Bool?
    public var remind: API.GoalRemind??
    public var three: API.GoalThree?

    public init(
        title: String? = nil, target: Double? = nil, care: String?? = nil, restPerWeek: Int? = nil, quiet: Bool? = nil,
        remind: API.GoalRemind?? = nil, three: API.GoalThree? = nil
    ) {
        self.title = title
        self.target = target
        self.care = care
        self.restPerWeek = restPerWeek
        self.quiet = quiet
        self.remind = remind
        self.three = three
    }

    private enum Keys: String, CodingKey { case title, target, care, restPerWeek, quiet, remind, three }

    public func encode(to encoder: any Encoder) throws {
        var box = encoder.container(keyedBy: Keys.self)
        try box.encodeIfPresent(title, forKey: .title)
        try box.encodeIfPresent(target, forKey: .target)
        if let care { try box.encode(care, forKey: .care) }
        try box.encodeIfPresent(restPerWeek, forKey: .restPerWeek)
        try box.encodeIfPresent(quiet, forKey: .quiet)
        if let remind { try box.encode(remind, forKey: .remind) }
        try box.encodeIfPresent(three, forKey: .three)
    }
}
