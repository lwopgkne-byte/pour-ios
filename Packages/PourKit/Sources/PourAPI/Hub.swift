public import Foundation

/// 3.0「我的」= 全部功能（docs/3.0/01-需求文档.md 2.3；服务器 `GET /api/me/hub`、`PUT /api/me/hub/favorites`，
/// 字段和 shared/src/hub.ts 一字不差）
extension API {
    public struct HubPage: Codable, Hashable, Sendable {
        /// 记了几天（有原话的日子）、几段话
        public let days: Int
        public let notes: Int
        /// Pour 认识你：几个人、几件常做的事、几个常去的地方
        public let known: Known
        /// 常用的格子（没管理过是默认的 8 个，待办、钱在最前面）
        public let favorites: [String]
        /// 管理过常用没有
        public let custom: Bool
        /// 格子角上的字：有要你处理的事才有（watch 留意的几条、review「新」、finds 这周的新发现几条没点）
        public let badges: [Badge]

        public struct Known: Codable, Hashable, Sendable {
            public let people: Int
            public let habits: Int
            public let places: Int
        }

        public struct Badge: Codable, Hashable, Sendable {
            public let tile: String
            public let text: String
        }
    }

    struct HubFavorites: Codable, Sendable {
        let favorites: [String]
    }
}

extension APIClient {
    public func hub() async throws(APIError) -> API.HubPage { try await get("/api/me/hub") }

    /// 管理常用：按顺序存在服务器上（换手机也一样）；回的是存下的样子（不认得的、重复的去掉，最多 8 个）
    public func setFavorites(_ tiles: [String]) async throws(APIError) -> [String] {
        let saved: API.HubFavorites = try await request(
            "PUT", "/api/me/hub/favorites", json: .object(["favorites": .array(tiles.map(JSONValue.string))]))
        return saved.favorites
    }
}
