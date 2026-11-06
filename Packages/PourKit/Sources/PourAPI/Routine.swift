public import Foundation

extension API {
    /// 作息（待办的时间线，服务器 2.23.0，产品主人 2026-11-06）：每天差不多的几段时间——睡觉、上班、忙着。
    /// 时间线上画成淡淡的底色，睡觉的那段收起来，空档不往睡觉、忙着的时间里排
    public struct Routine: Codable, Hashable, Sendable {
        public var blocks: [RoutineBlock]
        /// 自己设过；没设过是服务器按睡前问、免打扰算出来的一段睡觉
        public var custom: Bool

        public init(blocks: [RoutineBlock], custom: Bool) {
            self.blocks = blocks
            self.custom = custom
        }
    }

    public struct RoutineBlock: Codable, Hashable, Sendable, Identifiable {
        /// sleep 睡觉（收起来）· work 上班、上学（画出来，空档照找）· busy 忙着（通勤、吃饭、健身：不往里排）
        public enum Kind: String, Codable, Sendable, CaseIterable {
            case sleep, work, busy
        }

        /// 编辑时认哪一段（只在手机上，不发给服务器）
        public var id = UUID()
        public var title: String
        /// 以后的服务器多了别的种类：当成忙着
        public var kind: String
        /// HH:MM；可以跨过半夜（23:30 到 07:00）
        public var from: String
        public var to: String
        /// 周几（0 周一 … 6 周日）；跨过半夜的算开始那天
        public var days: [Int]

        public var sort: Kind { Kind(rawValue: kind) ?? .busy }

        public init(title: String, kind: Kind, from: String, to: String, days: [Int]) {
            self.title = title
            self.kind = kind.rawValue
            self.from = from
            self.to = to
            self.days = days
        }

        enum CodingKeys: String, CodingKey {
            case title, kind, from, to, days
        }
    }

    struct RoutineBody: Encodable, Sendable { let blocks: [RoutineBlock] }
}

extension APIClient {
    public func routine() async throws(APIError) -> API.Routine { try await get("/api/routine") }

    /// 整份换掉（作息弹框点「保存」），回来的是存好的
    public func saveRoutine(_ blocks: [API.RoutineBlock]) async throws(APIError) -> API.Routine {
        try await request("PUT", "/api/routine", encoding: API.RoutineBody(blocks: blocks))
    }
}
