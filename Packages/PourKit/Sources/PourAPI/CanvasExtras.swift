import Foundation

// 画布上另外要用到的：「回顾」列表（早上那一行「昨天的回顾好了 →」看昨天的看过没有）、跳过「连接大模型」
extension API {
    /// 「回顾」列表里的一项（网页版 lib/queries.ts 的 ReviewItem）
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
}

extension APIClient {
    public func reviewList() async throws(APIError) -> [API.ReviewItem] {
        let list: API.ReviewList = try await get("/api/review")
        return list.items
    }

    /// 「连接大模型」点了跳过：不再出现，以后在设置里填
    public func dismissSetup() async throws(APIError) {
        let _: Empty = try await request("POST", "/api/llm/dismiss-setup")
    }
}
