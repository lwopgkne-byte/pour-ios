public import Foundation

/// 健康 App 的步数、睡眠、锻炼（docs/模块/产品优化.md R5）：手机读了送给服务器；归到哪天、和你说的合在一起由服务器定
extension API {
    /// 送给服务器的一段时间（时刻都是带时区的 ISO）：这段时间里服务器上原来的整个换掉
    public struct HealthUpload: Codable, Hashable, Sendable {
        public var from: String
        public var to: String
        public var steps: [HealthStep]
        public var sleep: [HealthSleep]
        public var workouts: [HealthWorkout]

        public init(from: String, to: String, steps: [HealthStep], sleep: [HealthSleep], workouts: [HealthWorkout]) {
            self.from = from
            self.to = to
            self.steps = steps
            self.sleep = sleep
            self.workouts = workouts
        }
    }

    /// 一小时的步数
    public struct HealthStep: Codable, Hashable, Sendable {
        public var start: String
        public var count: Int

        public init(start: String, count: Int) {
            self.start = start
            self.count = count
        }
    }

    /// 睡眠的一段：asleep 睡着、inBed 在床上、awake 中间醒着
    public struct HealthSleep: Codable, Hashable, Sendable {
        public var start: String
        public var end: String
        public var stage: String

        public init(start: String, end: String, stage: String) {
            self.start = start
            self.end = end
            self.stage = stage
        }
    }

    /// 一次锻炼
    public struct HealthWorkout: Codable, Hashable, Sendable {
        public var id: String
        public var activity: String
        public var start: String
        public var end: String
        public var durationMin: Double
        /// 距离（公里）
        public var kilometers: Double?

        enum CodingKeys: String, CodingKey {
            case id, activity, start, end, durationMin
            case kilometers = "km"
        }

        public init(
            id: String, activity: String, start: String, end: String, durationMin: Double, kilometers: Double?
        ) {
            self.id = id
            self.activity = activity
            self.start = start
            self.end = end
            self.durationMin = durationMin
            self.kilometers = kilometers
        }
    }

    /// 服务器上有没有健康的数据、上次什么时候送的
    public struct HealthStatus: Codable, Hashable, Sendable {
        public var connected: Bool
        public var syncedAt: String?
    }

    /// 健康一页（服务器 2.20.0 `/api/health/page`；照可交互原型「健康」）：走了多少步、那一觉、最近 7 天的锻炼。
    /// 你说的为准，同一次只算一次；今天还没有步数、那一觉的给昨天的（day 写着是哪天）
    public struct HealthPage: Codable, Hashable, Sendable {
        public struct Steps: Codable, Hashable, Sendable {
            public var day: String
            public var count: Double
            /// 你自己说的步数（不是健康 App 的）
            public var said: Bool
            /// 「每天走 8000 步」这样的目标
            public var goal: Double?
        }

        public var connected: Bool
        public var syncedAt: String?
        public var today: String
        public var steps: Steps?
        public var sleep: HealthItem?
        public var workouts: [HealthItem]
    }

    /// 健康一页的一觉、一次锻炼
    public struct HealthItem: Codable, Hashable, Sendable {
        public var day: String
        public var label: String
        public var start: String?
        public var end: String?
        public var minutes: Double?
        public var kilometers: Double?
        /// 你说过的；false 是只有健康 App 记的
        public var said: Bool
        /// 你说的这条里健康 App 补上的几样（「时间」「时长」「距离」）
        public var fromHealth: [String]

        enum CodingKeys: String, CodingKey {
            case day, label, start, end, minutes, said, fromHealth
            case kilometers = "km"
        }
    }

    /// 画布上这一天健康 App 的：步数（锻炼、睡眠在 entries 里，`origin` 是 health）
    public struct DayHealth: Codable, Hashable, Sendable {
        public var steps: Int?

        public init(steps: Int?) {
            self.steps = steps
        }
    }
}

extension API.HealthUpload {
    /// 时刻写成服务器认得的 ISO（UTC：「2026-10-26T23:02:00Z」）
    public static func stamp(_ date: Date) -> String { date.ISO8601Format() }
}

extension APIClient {
    /// 送一段时间的健康数据；返回哪几天变了
    @discardableResult
    public func putHealth(_ upload: API.HealthUpload) async throws(APIError) -> [String] {
        let reply: Changed = try await request("PUT", "/api/health", encoding: upload)
        return reply.changed
    }

    public func healthStatus() async throws(APIError) -> API.HealthStatus { try await get("/api/health") }

    /// 健康一页（要服务器 2.20.0）
    public func healthPage() async throws(APIError) -> API.HealthPage { try await get("/api/health/page") }

    /// 断开健康：服务器上的全部删掉
    public func forgetHealth() async throws(APIError) {
        let _: Empty = try await request("DELETE", "/api/health")
    }

    private struct Changed: Decodable {
        let changed: [String]
    }
}
