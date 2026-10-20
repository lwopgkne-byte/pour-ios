public import Foundation
import PourCore

extension API {
    /// 一段日子：从哪天到哪天（周报、月报说的是哪一段）
    public struct Period: Codable, Hashable, Sendable {
        public var from: String
        public var to: String
    }

    /// 一条提醒推送到别的渠道（Server酱、Bark）的结果：发出去没有，没发出去为什么
    public struct PushResult: Codable, Hashable, Sendable {
        public var channel: String
        public var ok: Bool
        public var message: String?
    }

    /// 对话面板里的一条系统消息（shared report.ts 的 SystemMessage；规格 12.1：所有提醒同时也出现在对话面板里）
    public struct SystemMessage: Codable, Hashable, Sendable, Identifiable {
        /// 每日回顾：回顾的是哪一天、AI 写的一句话
        public struct Daily: Codable, Hashable, Sendable {
            public var day: String
            public var overview: String
        }

        /// 周报月报：对话里只用到哪一种、从哪天开始（完整的报告在「回顾」页拿）
        public struct ReportLink: Codable, Hashable, Sendable {
            public var kind: String
            public var period: Period
        }

        public var id: Int
        /// morning 早上、evening 晚上、warning 预警、weekly 周报、monthly 月报、test 试一下、todo 待办提醒、daily 每日回顾
        public var kind: String
        public var createdAt: String
        public var title: String
        public var body: String
        public var push: [PushResult]?
        public var daily: Daily?
        public var report: ReportLink?
        public var read: Bool?
    }

    struct MessagesPage: Decodable {
        let messages: [SystemMessage]
    }
}

extension APIClient {
    /// 系统消息：since 是对话里已经拿到的最早那段话的时间，从那以后的都要；
    /// 对话的历史都拿完了就传 nil，服务器给最近 30 条
    public func messages(since: String?) async throws(APIError) -> [API.SystemMessage] {
        let query = since.map { "?since=\(Self.escape($0))" } ?? ""
        let page: API.MessagesPage = try await get("/api/messages\(query)")
        return page.messages
    }

    private static func escape(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
    }
}

extension Show {
    /// 系统消息左边的那个图标
    public static func messageEmoji(_ kind: String) -> String {
        switch kind {
        case "morning": "☀️"
        case "evening": "🌙"
        case "warning": "📉"
        case "weekly", "monthly": "📋"
        case "test": "🔔"
        case "todo": "⏰"
        case "daily": "📖"
        default: "🔔"
        }
    }

    /// 推送渠道的名字（推送没发出去时说是哪个）
    public static func channelName(_ channel: String) -> String {
        ["serverchan": "Server酱", "bark": "Bark"][channel] ?? channel
    }

    /// 周报、月报在「回顾」里的地址（shared period.ts 的 reportPath）
    public static func reportPath(_ kind: String, from: String) -> String {
        kind == "weekly" ? "/review/week/\(from)" : "/review/month/\(from.prefix(7))"
    }

    /// 一个时刻在这台手机上是几点几分，补零（shared 的 formatClock：「09:05」；对话里的时间用它）
    public static func formatClock(_ iso: String, in timeZone: TimeZone = .current) -> String {
        guard let date = instant(iso) else { return "" }
        let local = PourDate.localDateTime(date, in: timeZone)
        return String(local.dropFirst(11).prefix(5))
    }

    /// 一个时刻算哪一天（过了日界线才算新的一天；shared 的 logicalDate）
    public static func logicalDay(_ iso: String, boundary: Int, in timeZone: TimeZone = .current) -> String? {
        instant(iso).map { PourDate.logicalDay($0, in: timeZone, boundary: boundary) }
    }

    /// 服务器给的时刻（「2026-10-19T02:00:00.000Z」，有时不带毫秒）
    public static func instant(_ iso: String) -> Date? {
        let precise = ISO8601DateFormatter()
        precise.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return precise.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
    }
}
