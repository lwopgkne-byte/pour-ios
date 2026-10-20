public import Foundation

// 心情从哪来（shared mood-sources.ts 的 MoodSources），字段名一字不差
extension API {
    /// 点开一行看到的那一刻
    public struct MomentExample: Codable, Hashable, Sendable {
        public var entryId: Int
        public var day: String
        public var moment: String
        public var noteId: Int?
    }

    /// 醒着的时间花在哪、好时刻在哪些领域的一行
    public struct MirrorRow: Codable, Hashable, Sendable {
        /// 顶级类别 key；「不算一件事」那一行是 glimpse
        public var key: String
        public var domain: String
        public var emoji: String
        public var hasGoal: Bool
        public var timeShare: Double?
        public var timeUnder1: Bool
        public var goodShare: Double
    }

    public struct MoodSources: Codable, Hashable, Sendable {
        public struct When: Codable, Hashable, Sendable {
            public var good: [String: Int]
            public var bad: [String: Int]
        }

        public struct Person: Codable, Hashable, Sendable {
            public var name: String
            public var good: Int
            public var bad: Int
        }

        public struct Word: Codable, Hashable, Sendable {
            public var word: String
            public var count: Int
        }

        public struct Emotions: Codable, Hashable, Sendable {
            public var good: [Word]
            public var bad: [Word]
        }

        public struct Enough: Codable, Hashable, Sendable {
            public var good: Bool
            public var bad: Bool
            public var time: Bool
        }

        public struct Short: Codable, Hashable, Sendable {
            public var good: String?
            public var bad: String?
            public var time: String?
        }

        public var when: When
        public var goodTotal: Int
        public var badTotal: Int
        public var noMoment: Int
        public var mirror: [MirrorRow]
        public var people: [Person]
        public var emotions: Emotions
        public var enough: Enough
        public var short: Short
        public var examples: [String: [MomentExample]]
    }
}

extension APIClient {
    /// range：30d、90d、year
    public func moodSources(_ range: String) async throws(APIError) -> API.MoodSources {
        try await get("/api/board/mood-sources?range=\(range)")
    }
}
