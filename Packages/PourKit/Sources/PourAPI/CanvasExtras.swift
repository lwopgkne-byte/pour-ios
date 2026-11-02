import Foundation

// 画布上另外要用到的：「回顾」列表（早上那一行「昨天的回顾好了 →」看昨天的看过没有）、跳过「连接大模型」
extension API {
    /// 「回顾」列表里的一项
    public struct ReviewItem: Codable, Hashable, Sendable, Identifiable {
        public var id: Int
        /// daily 每日回顾、weekly、monthly、warning……
        public var kind: String
        public var title: String
        public var summary: String
        /// 每日回顾回顾的是哪一天；周报、预警没有
        public var day: String?
        /// 周报月报那一期的第一天
        public var from: String?
        public var createdAt: String
        public var read: Bool
    }

    struct ReviewList: Decodable {
        let items: [ReviewItem]
    }

    /// 3.0 回顾页的一张卡（GET /api/review?kind=day|week|month）
    public struct ReviewCard: Codable, Hashable, Sendable, Identifiable {
        public var id: Int
        /// daily、weekly、monthly
        public var kind: String
        public var title: String
        public var summary: String
        /// 每日回顾回顾的是哪一天
        public var day: String?
        /// 周报月报那一期的第一天
        public var from: String?
        public var createdAt: String
        public var read: Bool
        /// 事实变了、重写过（「已更新」）
        public var updated: Bool
        /// 几个数：「睡眠 6:50」「运动 5 次」「心情 挺好」
        public var chips: [String]
    }

    /// 需要留意：最近 7 天没看过的预警，一行一件；ids 是那几条消息（「知道了」都标成看过）
    public struct ReviewAttention: Codable, Hashable, Sendable {
        public var lines: [String]
        public var ids: [Int]
    }

    public struct ReviewListPage: Codable, Hashable, Sendable {
        public var items: [ReviewCard]
        public var attention: ReviewAttention?
    }
}

extension APIClient {
    public func reviewList() async throws(APIError) -> [API.ReviewItem] {
        let list: API.ReviewList = try await get("/api/review")
        return list.items
    }

    /// 3.0 回顾页的一段：day 每日回顾 · week 周报 · month 月报
    public func reviewList(_ tab: String) async throws(APIError) -> API.ReviewListPage {
        try await get(Self.reviewListPath(tab))
    }

    public static func reviewListPath(_ tab: String) -> String { "/api/review?kind=\(tab)" }

    /// 「连接大模型」点了跳过：不再出现，以后在设置里填
    public func dismissSetup() async throws(APIError) {
        let _: Empty = try await request("POST", "/api/llm/dismiss-setup")
    }
}
