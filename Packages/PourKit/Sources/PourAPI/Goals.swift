public import Foundation

// 目标（shared goals.ts 的 GoalView、GoalDetail、GoalProgress、SubPeriodView……），字段名一字不差
extension API {
    /// 目标的进度：状态色、进度条、实际和目标、一句话
    public struct GoalProgress: Codable, Hashable, Sendable {
        /// good 不落后、warn 稍微落后、bad 落后较多、none 已不可能完成、idle 还没有状态
        public var tone: String
        /// 进度条的比例 0–1
        public var pct: Double
        /// 周期内实际的量（平均型是平均值，连续型是当前连续天数）
        public var actual: Double
        public var target: Double
        public var unit: String
        /// 累计型、次数型：到昨天为止应该达到多少
        public var expected: Double?
        /// 超前（正）或落后（负）多少
        public var diff: Double?
        /// 平均型：有记录的天数
        public var days: Int?
        /// 平均型：剩余天数里平均每天需要达到多少
        public var neededPerDay: Double?
        /// 连续型：历史最长连续天数
        public var best: Int?
        public var reached: Bool
        public var ended: Bool
        /// 周期还剩几天（含今天）
        public var daysLeft: Int
        /// 「已完成 612 · 超前 3%」
        public var headline: String
    }

    /// 年目标下的一个月、月目标下的一周
    public struct SubPeriod: Codable, Hashable, Sendable, Identifiable {
        public var key: String
        public var label: String
        public var target: Double
        /// 手动调整过
        public var locked: Bool
        /// 包含今天
        public var current: Bool
        public var progress: GoalProgress
        public var weeks: [SubPeriod]?

        public var id: String { key }
    }

    /// 目标绑定的记录：哪个类别、看时长还是数量
    public struct GoalBinding: Codable, Hashable, Sendable {
        public var category: String
        /// duration、count、value
        public var metric: String
        public var metricUnit: String?
        /// 只算名称里带这些字的记录
        public var keywords: [String]?
    }

    /// 绑定的类别被删除或合并了：进度算不了，引导重新绑定
    public struct GoalInvalid: Codable, Hashable, Sendable {
        public struct Suggest: Codable, Hashable, Sendable {
            public var key: String
            public var name: String
        }

        public var message: String
        public var suggest: Suggest?
    }

    /// 一个目标（目标页的一行；GET /api/goals）
    public struct Goal: Codable, Hashable, Sendable, Identifiable {
        public var id: Int
        public var parentId: Int?
        public var title: String
        /// quantity 有数字的、completion 做完就算、parent 模糊目标（下面有子目标）
        public var kind: String
        /// year、month、week
        public var period: String
        /// 每周、每月重复的（「repeat」是关键字，换个名字）
        public var repeats: Bool?
        public var start: String
        public var end: String?
        /// sum 累计、avg 平均、count 次数、streak 连续天数
        public var calc: String?
        /// gte 至少、lte 不超过
        public var direction: String?
        public var target: Double?
        public var unit: String?
        public var binding: GoalBinding?
        /// active、proposed AI 建议的（等确认）、done
        public var status: String
        /// 在等你回答的一句
        public var question: String?
        public var maybeDone: Bool?
        public var rangeLabel: String
        public var progress: GoalProgress
        public var invalid: GoalInvalid?
        public var monthRows: [SubPeriod]?
        public var weekRows: [SubPeriod]?
        /// 锁定月份的总和超过了年目标
        public var overLocked: Bool?
        public var children: [Goal]?

        enum CodingKeys: String, CodingKey {
            case id, parentId, title, kind, period, start, end, calc, direction, target, unit, binding, status
            case question, maybeDone, rangeLabel, progress, invalid, monthRows, weekRows, overLocked, children
            case repeats = "repeat"
        }
    }

    /// 应达 vs 实际曲线上的一个点
    public struct GoalPoint: Codable, Hashable, Sendable {
        public var day: String
        public var actual: Double?
        public var expected: Double?
    }

    /// 贡献给这个目标的一条记录
    public struct GoalContribution: Codable, Hashable, Sendable, Identifiable {
        public var entryId: Int
        public var day: String
        public var text: String
        public var value: Double

        public var id: Int { entryId }
    }

    /// 连续型：最近的某一天做到了没有
    public struct StreakDay: Codable, Hashable, Sendable {
        public var day: String
        public var met: Bool
    }

    /// 目标详情（GET /api/goals/:id）：目标本身 + 曲线、预测、贡献的记录
    public struct GoalDetail: Decodable, Hashable, Sendable {
        public var goal: Goal
        public var series: [GoalPoint]
        public var streakDays: [StreakDay]?
        /// 「按最近的速度，到期末大约完成 62%」
        public var prediction: String
        public var contributions: [GoalContribution]

        enum CodingKeys: String, CodingKey {
            case series, streakDays, prediction, contributions
        }

        public init(from decoder: any Decoder) throws {
            goal = try Goal(from: decoder)
            let box = try decoder.container(keyedBy: CodingKeys.self)
            series = try box.decode([GoalPoint].self, forKey: .series)
            streakDays = try box.decodeIfPresent([StreakDay].self, forKey: .streakDays)
            prediction = try box.decodeIfPresent(String.self, forKey: .prediction) ?? ""
            contributions = try box.decode([GoalContribution].self, forKey: .contributions)
        }
    }

    struct GoalsPage: Decodable {
        let goals: [Goal]
    }
}

extension APIClient {
    public func goals() async throws(APIError) -> [API.Goal] {
        let page: API.GoalsPage = try await get("/api/goals")
        return page.goals
    }

    public func goal(_ id: Int) async throws(APIError) -> API.GoalDetail { try await get("/api/goals/\(id)") }

    /// 原地修改：title、target、category、start……
    public func updateGoal(_ id: Int, _ fields: [String: JSONValue]) async throws(APIError) {
        let _: Empty = try await request("PATCH", "/api/goals/\(id)", json: .object(["fields": .object(fields)]))
    }

    /// 调整某个月的目标值；nil 是恢复按天数自动分配
    public func adjustMonth(_ id: Int, month: String, target: Double?) async throws(APIError) {
        let value: JSONValue = target.map { .number($0) } ?? .null
        let body: JSONValue = .object(["month": .object(["month": .string(month), "target": value])])
        let _: Empty = try await request("PATCH", "/api/goals/\(id)", json: body)
    }

    /// 确认 AI 建议的拆解、回答「就这样」
    public func confirmGoal(_ id: Int) async throws(APIError) {
        let _: Empty = try await request("PATCH", "/api/goals/\(id)", json: .object(["confirm": .bool(true)]))
    }

    public func setGoalDone(_ id: Int, _ done: Bool) async throws(APIError) {
        let _: Empty = try await request("PATCH", "/api/goals/\(id)", json: .object(["done": .bool(done)]))
    }

    /// 手动添加目标
    public func createGoal(_ body: [String: JSONValue]) async throws(APIError) {
        let _: Empty = try await request("POST", "/api/goals", json: .object(body))
    }

    public func deleteGoal(_ id: Int) async throws(APIError) {
        let _: Empty = try await request("DELETE", "/api/goals/\(id)")
    }

    public func restoreGoal(_ id: Int) async throws(APIError) {
        let _: Empty = try await request("POST", "/api/goals/\(id)/restore")
    }
}

/// 目标的写法
extension Show {
    /// 保留一位小数，整数不带「.0」：612、6.8
    public static func fmtNum(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded)
    }

    /// 状态色的说法（读屏）
    public static func toneName(_ tone: String) -> String {
        ["good": "不落后", "warn": "稍微落后", "bad": "落后较多", "none": "已不可能完成", "idle": "还没有状态"][tone] ?? ""
    }

    /// 列表一行右侧的关键数字
    public static func keyNumber(_ goal: API.Goal, _ progress: API.GoalProgress) -> String {
        let unit = goal.unit ?? ""
        if goal.kind == "completion" { return goal.status == "done" ? "已完成" : "" }
        if goal.kind == "parent" { return "\(fmtNum(progress.actual)) / \(fmtNum(progress.target))" }
        if progress.headline == "绑定对象已失效" { return "" }
        switch goal.calc {
        case "avg":
            return progress.days.map { $0 > 0 } == true
                ? "平均 \(fmtNum(progress.actual)) / \(fmtNum(progress.target)) \(unit)"
                : "目标 \(fmtNum(progress.target)) \(unit)"
        case "streak":
            return "\(fmtNum(progress.actual)) / \(fmtNum(progress.target)) 天"
        default:
            return "\(fmtNum(progress.actual)) / \(fmtNum(progress.target)) \(unit)".trimmingCharacters(
                in: .whitespaces)
        }
    }

    /// 列表一行下面的一句话：超前 / 落后多少，或者平均差多少
    public static func paceText(_ goal: API.Goal, _ progress: API.GoalProgress) -> String {
        let headline = progress.headline
        // 做完就算的目标没做完时，「进行中」不带信息，不写
        if goal.kind == "completion" { return headline == "进行中" ? "" : headline }
        if goal.kind != "quantity" { return headline }
        let parts = headline.components(separatedBy: " · ")
        // 平均：右边已经写了「平均 6.8 / 7.5」，下面只说差多少
        if goal.calc == "avg" {
            let rest = parts.dropFirst().joined(separator: " · ")
            return !rest.isEmpty ? rest : (headline.hasPrefix("实际") ? "" : headline)
        }
        if goal.calc == "sum" || goal.calc == "count" || goal.calc == nil {
            if parts.count > 1 { return parts.dropFirst().joined(separator: " · ") }
            return headline.hasPrefix("已用") || headline.hasPrefix("已超过") ? headline : ""
        }
        return headline
    }

    /// 「累计至少 500 公里」
    public static func describeTarget(_ goal: API.Goal) -> String {
        guard goal.kind == "quantity", let target = goal.target else { return "" }
        let calc = ["sum": "累计", "avg": "平均", "count": "", "streak": "连续"][goal.calc ?? "sum"] ?? ""
        let direction = goal.direction == "lte" ? "不超过" : goal.calc == "streak" ? "" : "至少"
        return "\(calc)\(direction) \(fmtNum(target)) \(goal.unit ?? "")".trimmingCharacters(in: .whitespaces)
    }

    /// 周期的叫法：一次的、重复的
    public static func periodName(_ period: String, repeating: Bool) -> String {
        let names = ["year": ("年度", "每年"), "month": ("月度", "每月"), "week": ("本周", "每周")]
        guard let name = names[period] else { return "" }
        return repeating ? name.1 : name.0
    }
}
