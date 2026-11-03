// 一个目标的设置里能改的（服务器 shared/src/goals3.ts 的 settings.edit，2.19.0 起；docs/3.0/06-交互细节.md 第 12 节「设置」）
extension API {
    /// 改类别、只算、周期、从哪天算用的：原值和能选的（点了弹出系统的选择）
    public struct GoalSettingsEdit: Codable, Hashable, Sendable {
        /// 类别的 key；不按类别算的目标没有
        public var category: String?
        /// 只算名称里带的字（空的是整个类别都算）；不按类别算的是 nil
        public var keywords: [String]?
        /// 周期能换成哪几样；每天的、坚持的、大目标是空的
        public var periods: [GoalPeriodOption]
        /// 从哪天算能选的那一段；重复的、每天的、坚持的没有
        public var start: GoalStartRange?
    }

    /// 周期的一样：今年 / 这个月 / 这周（有终点）、每月 / 每周（重复）
    public struct GoalPeriodOption: Codable, Hashable, Sendable {
        public var label: String
        /// year、month、week
        public var period: String
        /// 每月、每周这种重复的（服务器的字段叫 repeat）
        public var repeats: Bool
        public var current: Bool

        private enum CodingKeys: String, CodingKey {
            case label, period, current
            case repeats = "repeat"
        }
    }

    /// 从哪天算：现在是哪天、能选的最早和最晚（「2026-01-01」到今天）
    public struct GoalStartRange: Codable, Hashable, Sendable {
        public var value: String
        public var from: String
        public var to: String
    }
}
