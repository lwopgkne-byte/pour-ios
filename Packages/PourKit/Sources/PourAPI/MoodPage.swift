import Foundation
import PourCore

// 3.0 心情页（服务器 shared/src/mood-page.ts，字段名一字不差）：一次拿全今天的每一刻、这个月每天的心情和那天的每一刻、
// 平均、一周里哪天低、好时刻、发现、变化；记心情用的常用情绪词
extension API {
    /// 一刻心情（一条心情记录）
    public struct MoodMoment: Codable, Hashable, Sendable, Identifiable {
        public var entryId: Int
        public var day: String
        /// 说这句话的时刻（「08:20」）；找不到原话是 nil
        public var time: String?
        /// 1–5
        public var mood: Double
        /// 「挺好」
        public var word: String
        public var emotions: [String]
        /// 精力 1–5；没说是 nil
        public var energy: Double?
        /// 那一刻（原话里的一段）；没说因为什么是 nil
        public var moment: String?
        public var byYou: Bool
        public var noteId: Int?

        public var id: Int { entryId }
        /// 1–5 的一档（四舍五入）
        public var level: Int { min(5, max(1, Int(mood.rounded()))) }
    }

    /// 月历的一格：那天的心情（一天几条取平均）和那天的每一刻
    public struct MoodDay: Codable, Hashable, Sendable {
        public var day: String
        public var mood: Double
        /// 「挺好」「有起有落」
        public var word: String
        public var moments: [MoodMoment]

        public var level: Int { min(5, max(1, Int(mood.rounded()))) }
    }

    public struct MoodPage: Codable, Hashable, Sendable {
        public struct Good: Codable, Hashable, Sendable {
            public var total: Int
            public var recent: [MoodMoment]
        }

        public var today: String
        public var month: String
        public var current: Bool
        public var todayMoments: [MoodMoment]
        /// 「2 刻 · 有起有落」；今天还没说心情是 nil
        public var todaySummary: String?
        public var days: [MoodDay]
        /// 「平均在一般和挺好之间 · 25 天说到了心情」
        public var monthLine: String?
        public var prevMonth: String?
        public var nextMonth: String?
        public var week: MeWeekMood?
        public var good: Good
        public var findings: [FindingView]
        public var changes: [MeChange]
    }

    /// 记心情用的常用情绪词：好的、不好的各一排，按你说得多的排
    public struct MoodWords: Codable, Hashable, Sendable {
        public var good: [String]
        public var bad: [String]

        public init(good: [String], bad: [String]) {
            self.good = good
            self.bad = bad
        }

        /// 还没拿到服务器的：常用的那几个（06 交互细节 4.2 的顺序）
        public static let common = MoodWords(
            good: ["开心", "放松", "满足", "平静", "期待", "感激", "骄傲"], bad: ["累", "烦躁", "焦虑", "失落", "委屈", "生气", "难过"])
    }
}

extension APIClient {
    /// 心情页；month 是 nil 时是这个月
    public func moodPage(_ month: String? = nil) async throws(APIError) -> API.MoodPage {
        try await get(month.map { "/api/mood/page?month=\($0)" } ?? "/api/mood/page")
    }

    public func moodWords() async throws(APIError) -> API.MoodWords { try await get("/api/mood/words") }
}

extension API.MoodMoment {
    /// 好时刻（全部，`/api/moments`）的一条：从一条心情记录来（不是心情的是 nil）
    public init?(moment: API.Moment) {
        guard case .mood(let data) = moment.entry.data else { return nil }
        let level = min(5, max(1, Int(data.mood.rounded())))
        self.init(
            entryId: moment.entry.id, day: moment.entry.day, time: nil, mood: data.mood,
            word: Show.moodWords[level - 1], emotions: data.emotions, energy: data.energy, moment: data.moment,
            byYou: data.byYou == true, noteId: moment.noteId)
    }
}
