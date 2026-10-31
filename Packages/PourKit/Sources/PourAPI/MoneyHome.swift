public import Foundation

/// 3.0 钱的主页（docs/3.0/01-需求文档.md 5.2；服务器 2.11.0 的 `/api/money/home`、`/api/money/quick`，
/// 字段和 shared/src/money-home.ts 一字不差）
extension API {
    public struct MoneyHome: Codable, Hashable, Sendable {
        public var month: MoneyMonth
        public var pace: MoneyPace
        /// 你说过的钱的「不超过」目标（看的是这个月才有）
        public var budgets: [MoneyBudgetLine]
        /// 留意的几条、花给了谁、值不值、人情往来（看的是这个月才有）
        public var overview: MoneyOverview?
        /// 钱和你的日子（看的是这个月才有）
        public var findings: MoneyFindingsPage?
    }

    /// 每天累计日常花的：第 i 个是 1 号到 i+1 号一共花了多少
    public struct MoneyPace: Codable, Hashable, Sendable {
        /// 这个月：到今天（过去的月份到月底）
        public var current: [Double]
        /// 上个月：整月；上个月还没开始记的是 nil
        public var previous: [Double]?
    }

    /// 预算的一行：写还能花多少，超了写超了多少
    public struct MoneyBudgetLine: Codable, Hashable, Sendable, Identifiable {
        public var id: Int
        /// 「每月外卖不超过 300 元」
        public var title: String
        public var limit: Double
        public var spent: Double
        /// 还能花多少；超了是负的
        public var left: Double
        /// 用了多少（0–1，超了是 1）
        public var pct: Double
        public var tone: String
        /// 「还能花 ¥64」「超了 ¥36」
        public var text: String
    }

    /// 记一笔的「你常买的」：名目、平常的价、最近 30 天说到几次
    public struct MoneyQuickItem: Codable, Hashable, Sendable, Identifiable {
        public var name: String
        public var amount: Double
        public var count: Int

        public var id: String { name }

        public init(name: String, amount: Double, count: Int) {
            self.name = name
            self.amount = amount
            self.count = count
        }
    }

    /// 留意的一条右边的按钮办的是哪几笔（服务器 2.11.0 起有）
    public struct WatchRef: Codable, Hashable, Sendable {
        public var entryId: Int
        public var index: Int
    }

    struct MoneyQuickPage: Codable, Sendable { let items: [MoneyQuickItem] }
}

extension APIClient {
    /// 钱的主页一次拿全；month 是 nil：这个月
    public func moneyHome(_ month: String?) async throws(APIError) -> API.MoneyHome {
        try await get(month.map { "/api/money/home?month=\($0)" } ?? "/api/money/home")
    }

    /// 记一笔的「你常买的」
    public func moneyQuick() async throws(APIError) -> [API.MoneyQuickItem] {
        let page: API.MoneyQuickPage = try await get("/api/money/quick")
        return page.items
    }
}
