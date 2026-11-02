public import Foundation

// 一个人一页（GET /api/about/person/:name，shared me-person.ts，3.0 第 8 步），字段名一字不差
extension API {
    public struct MePersonPage: Codable, Hashable, Sendable {
        /// 「32 天里 29 天心情挺好以上」「别的日子 26 天里 2 天 · 只是同时出现」
        public struct Mood: Codable, Hashable, Sendable {
            public var title: String
            public var sub: String
        }

        /// 和他一起的一件事：那段话里说这件事的那一句
        public struct Recent: Codable, Hashable, Sendable, Identifiable {
            public var entryId: Int
            public var day: String
            public var text: String

            public var id: Int { entryId }
        }

        /// 花在他身上的：「这 9 周 6 笔，一共 ¥4,134」
        public struct Money: Codable, Hashable, Sendable {
            public var total: Double
            public var count: Int
            public var text: String
        }

        public var name: String
        /// 你说过的关系（「同事」）；名字本身就是称呼的是 nil
        public var relation: String?
        /// family、work、other
        public var group: String
        /// 「家人 · 这 9 周 32 天 · 最近一次 10月27日」
        public var sub: String
        /// 多是做什么（带天数）
        public var acts: [MeCount]
        public var mood: Mood?
        public var recent: [Recent]
        public var money: Money?
        /// 这几周一次都没在一起
        public var empty: Bool
    }
}

extension APIClient {
    public func mePerson(_ name: String) async throws(APIError) -> API.MePersonPage {
        let escaped = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return try await get("/api/about/person/\(escaped)")
    }
}
