public import Foundation
import PourCore

// 回顾（shared daily.ts、period.ts，web lib/queries.ts 的 DailyReviewPage、PeriodReviewPage、AuditFinding），字段名一字不差
extension API {
    /// 关键数字的一段：数字和它的单位（「8」「小时」）
    public struct NumberPart: Codable, Hashable, Sendable {
        public var number: String
        public var unit: String

        enum CodingKeys: String, CodingKey {
            case number = "n"
            case unit = "u"
        }
    }

    /// 一个关键数字：大号的数字和小号的单位分开（「8 小时 20 分」）
    public struct KeyNumber: Codable, Hashable, Sendable {
        /// sleep、exercise、focus、mood
        public var key: String
        public var label: String
        public var parts: [NumberPart]
        public var text: String
        /// 和平时比：「比平时少 30 分钟」；前面没有数据时是 nil
        public var compare: String?
    }

    /// 做了什么里的一个领域（每日回顾：一条一条；周报月报：一行字）
    public struct ReviewGroup: Codable, Hashable, Sendable {
        public struct Item: Codable, Hashable, Sendable {
            public var entryId: Int
            public var text: String
        }

        public var key: String
        public var emoji: String
        public var name: String
        /// 每日回顾
        public var items: [Item]?
        /// 周报月报：「跑步 4 次、力量 · 2 小时 55 分 · 21 公里」
        public var text: String?
        public var compare: String?
    }

    /// 每日回顾里的一条心情
    public struct ReviewMood: Codable, Hashable, Sendable {
        public var entryId: Int
        public var mood: Double
        public var energy: Double?
        public var emotions: [String]
        public var moment: String?
        /// 几点说的（「16:16」）
        public var at: String?

        /// 和画布上的心情同一个样子显示
        public var data: MoodData {
            MoodData(
                mood: mood, energy: energy, emotions: emotions, tone: nil, strength: nil, moment: moment, byYou: nil)
        }
    }

    /// 每日回顾（GET /api/review/daily/:day）
    public struct DailyReview: Codable, Hashable, Sendable {
        public struct Insight: Codable, Hashable, Sendable {
            public var entryId: Int
            public var quote: String
        }

        public struct OpenTodo: Codable, Hashable, Sendable {
            public var entryId: Int
            public var content: String
        }

        public struct OpenPending: Codable, Hashable, Sendable {
            public var entryId: Int
            public var text: String
            public var question: String
        }

        public struct Open: Codable, Hashable, Sendable {
            public var todos: [OpenTodo]
            public var pending: [OpenPending]
        }

        public struct Today: Codable, Hashable, Sendable {
            public var todos: [String]
            public var goals: [String]
        }

        public var day: String
        public var overview: String
        public var observation: String?
        /// 记录变了，数字按新的算过
        public var updated: Bool
        public var numbers: [KeyNumber]
        /// 这一天的全部记录（时间轴用）
        public var entries: [Entry]
        public var groups: [ReviewGroup]
        public var goals: [DayGoal]
        public var moods: [ReviewMood]
        public var insights: [Insight]
        public var open: Open
        public var today: Today
        /// 这一天说了几段话
        public var notes: Int
    }

    public struct DailyReviewPage: Codable, Hashable, Sendable {
        public var review: DailyReview
        public var messageId: Int?
        public var read: Bool
        public var prev: String?
        public var next: String?
        /// 这一周有周报：那一周的周一
        public var weekly: String?
    }

    /// 周报的一行、月报的一格
    public struct PeriodDay: Codable, Hashable, Sendable {
        public var day: String
        public var recorded: Bool
        /// 那天心情的说法；没说心情是 nil
        public var mood: String?
        /// 那天几条心情的平均（月历上色）
        public var level: Double?
    }

    public struct PeriodMood: Codable, Hashable, Sendable {
        public struct Moment: Codable, Hashable, Sendable {
            public var entryId: Int
            public var day: String
            public var text: String
        }

        public var total: Int
        public var good: Int
        public var bad: Int
        public var moments: [Moment]
    }

    /// 感悟里的一个主题，带着原话
    public struct Theme: Codable, Hashable, Sendable {
        public struct Quote: Codable, Hashable, Sendable {
            public var noteId: Int?
            public var day: String
            public var text: String
        }

        public var theme: String
        public var quotes: [Quote]
    }

    public struct MoneyLine: Codable, Hashable, Sendable {
        public var text: String
        public var compare: String?
    }

    public struct PeriodNext: Codable, Hashable, Sendable {
        public var todos: [String]
        public var goals: [String]
        public var suggestions: [String]
    }

    /// 周报 / 月报（GET /api/review/period/:kind/:day）
    public struct PeriodReview: Codable, Hashable, Sendable {
        /// weekly、monthly
        public var kind: String
        public var period: Period
        public var title: String
        public var overview: String
        public var updated: Bool
        /// 有记录的天数不到一半：只说记到的
        public var sparse: Bool
        public var daysRecorded: Int
        public var totalDays: Int
        public var notes: Int
        public var numbers: [KeyNumber]
        public var days: [PeriodDay]
        /// 周报：这一周有时间的事；月报是空的
        public var entries: [Entry]
        /// 月报：哪几周有周报（那一周的周一）
        public var weeklyReports: [String]
        public var groups: [ReviewGroup]
        public var money: [MoneyLine]
        public var goals: [DayGoal]
        public var mood: PeriodMood?
        public var themes: [Theme]
        public var moodNote: String?
        public var highlights: [String]
        public var concerns: [String]
        public var next: PeriodNext?
        public var categorySuggestions: [String]
    }

    public struct PeriodReviewPage: Codable, Hashable, Sendable {
        public var review: PeriodReview
        public var messageId: Int?
        public var read: Bool
        public var prev: String?
        public var next: String?
    }

    /// 自动检查发现的一处（夜里用更强的模型复查前一天的整理）
    public struct AuditFinding: Codable, Hashable, Sendable, Identifiable {
        public var id: Int
        public var noteId: Int
        public var day: String
        /// 整段原话
        public var text: String
        /// 原话里有问题的那一段
        public var quote: String
        public var reason: String
        /// 当时整理成的样子
        public var before: [String]
        /// 按审核员的改法改完的样子；说不清怎么改就没有
        public var after: [String]?
        public var entryIds: [Int]
    }

    /// 点「确实错了」的结果：fixed 改好了、candidate 记进了「你改过的地方」、manual 要你自己改
    public struct AuditConfirm: Codable, Hashable, Sendable {
        public var kind: String
        public var entryIds: [Int]?
        /// manual 的原因：nofix 审核员说不清怎么改、changed 这条记录后来改过
        public var why: String?
    }

    struct Findings: Decodable {
        let findings: [AuditFinding]
    }
}

extension APIClient {
    public func dailyReview(_ day: String) async throws(APIError) -> API.DailyReviewPage {
        try await get("/api/review/daily/\(day)")
    }

    /// kind：weekly、monthly；day 是那一期的第一天
    public func periodReview(_ kind: String, _ day: String) async throws(APIError) -> API.PeriodReviewPage {
        try await get("/api/review/period/\(kind)/\(day)")
    }

    /// 看过了（回顾列表里变成次要文字色）
    public func markRead(message id: Int) async throws(APIError) {
        let _: Empty = try await request("POST", "/api/messages/\(id)/read")
    }

    /// 没做完的待办带到今天
    public func carry(entry id: Int) async throws(APIError) {
        let _: Empty = try await request("POST", "/api/entries/\(id)/carry")
    }

    public func auditFindings(_ day: String) async throws(APIError) -> [API.AuditFinding] {
        let page: API.Findings = try await get("/api/audit/day/\(day)")
        return page.findings
    }

    public func confirmFinding(_ id: Int) async throws(APIError) -> API.AuditConfirm {
        try await request("POST", "/api/audit/findings/\(id)/confirm")
    }

    public func dismissFinding(_ id: Int) async throws(APIError) {
        let _: Empty = try await request("POST", "/api/audit/findings/\(id)/dismiss")
    }

    public func undoFinding(_ id: Int) async throws(APIError) {
        let _: Empty = try await request("POST", "/api/audit/findings/\(id)/undo")
    }
}

/// 回顾的写法（shared period.ts、review 页面里的小函数）
extension Show {
    /// 回顾列表里的种类
    public static func reviewKind(_ kind: String) -> String {
        ["daily": "每日", "weekly": "每周", "monthly": "每月", "warning": "提醒"][kind] ?? ""
    }

    /// 回顾列表里的时间：「今天 7:30」「昨天」「9月27日 周日」
    public static func reviewWhen(_ iso: String, today: String) -> String {
        guard let date = instant(iso) else { return "" }
        let day = PourDate.localDateTime(date, in: .current).prefix(10)
        let clock = formatClock(iso)
        if String(day) == today { return "今天 \(clock.hasPrefix("0") ? String(clock.dropFirst()) : clock)" }
        return daySeparator(String(day), today: today)
    }

    /// 周报的一行：「2026-10-12」→「周一 12」（shared weekRowLabel）
    public static func weekRowLabel(_ day: String) -> String {
        let weekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        return "\(weekdays[PourDate.weekdayMon0(day)]) \(Int(day.suffix(2)) ?? 0)"
    }

    /// 刚过去的那一期是「上周」「上个月」，更早的不写（shared periodRelative）
    public static func periodRelative(_ kind: String, from: String, today: String) -> String? {
        let previous: String
        if kind == "weekly" {
            let thisMonday = PourDate.addDays(today, -PourDate.weekdayMon0(today))
            previous = PourDate.addDays(thisMonday, -7)
        } else {
            let first = "\(today.prefix(7))-01"
            previous = "\(PourDate.addDays(first, -1).prefix(7))-01"
        }
        return previous == from ? (kind == "weekly" ? "上周" : "上个月") : nil
    }

    /// 这一期怎么称呼：这周、这个月
    public static func periodScope(_ kind: String) -> String { kind == "weekly" ? "这周" : "这个月" }

    /// 「9月」
    public static func monthName(_ month: String) -> String { "\(Int(month.suffix(2)) ?? 0)月" }
}
