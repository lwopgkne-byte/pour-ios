import PourDesign
import SwiftUI

/// 「我的」里的一个功能格子（docs/3.0/01-需求文档.md 2.3、06 交互细节第 8 节的图标对照）：
/// 键和服务器的 `HUB_TILES` 一样（常用里存的就是它）；别名给顶上搜功能用（搜「报销」找到「留意的」）
struct HubTile: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let color: Color
    let aliases: [String]

    /// 点了去哪（页面地址，today 是服务器的今天）。3.0.1 照原型补上了健康、日历、值不值三页；
    /// 固定的去每一笔里只看固定的，新发现去关于我（原型也是这样）
    func path(today: String) -> String {
        let month = String(today.prefix(7))
        if id == "money-list" { return "/money/list/\(month)" }
        if id == "fixed" { return "/money/list/\(month)?kind=fixed" }
        return Self.paths[id] ?? "/"
    }

    private static let paths = [
        "todos": "/todos", "money": "/money", "mood": "/mood", "insights": "/insights", "calendar": "/calendar",
        "health": "/health", "review": "/review", "library": "/library", "moments": "/mood/moments",
        "year": "/about/year", "about": "/about", "finds": "/about", "people": "/about/people", "talk": "/about/talk",
        "watch": "/money/watch", "budget": "/goals/budgets", "renqing": "/money/renqing", "worth": "/money/worth",
        "goals": "/goals", "streak": "/goals/streaks",
    ]
}

enum HubCatalog {
    /// 全部功能：一组一张白卡片（组名在左上角小字），照微信「服务」
    static let groups: [(name: String, tiles: [String])] = [
        ("记录", ["todos", "money", "mood", "insights", "health"]),
        ("回看", ["review", "calendar", "library", "moments", "year"]),
        ("了解自己", ["about", "people", "talk", "finds"]),
        ("钱", ["money-list", "watch", "fixed", "renqing", "worth"]),
        ("目标", ["goals", "streak", "budget"]),
    ]

    /// 常用最多几个（一行 4 个、两行）
    static let maxFavorites = 8

    /// 没管理过常用时（服务器也这么给）：待办、钱排在最前面
    static let defaultFavorites = ["todos", "money", "mood", "insights", "review", "goals", "library", "calendar"]

    static let tiles: [String: HubTile] = Dictionary(
        uniqueKeysWithValues: [
            HubTile(
                id: "todos", name: "待办", symbol: Theme.Symbol.todos, color: Theme.Tile.blue,
                aliases: ["提醒", "任务", "要做的", "清单"]),
            HubTile(
                id: "money", name: "钱", symbol: Theme.Symbol.money, color: Theme.Tile.amber,
                aliases: ["花钱", "记账", "支出", "收入", "账"]),
            HubTile(
                id: "mood", name: "心情", symbol: Theme.Symbol.mood, color: Theme.Tile.pink,
                aliases: ["情绪", "开心", "难过", "累"]),
            HubTile(
                id: "insights", name: "感悟", symbol: Theme.Symbol.insights, color: Theme.Tile.gold,
                aliases: ["想法", "感想", "语录", "记一句"]),
            HubTile(
                id: "health", name: "健康", symbol: Theme.Symbol.health, color: Theme.Tile.red,
                aliases: ["步数", "睡眠", "运动", "手表"]),
            HubTile(
                id: "review", name: "回顾", symbol: Theme.Symbol.review, color: Theme.Tile.indigo,
                aliases: ["日报", "周报", "月报", "总结", "昨天"]),
            HubTile(
                id: "calendar", name: "日历", symbol: Theme.Symbol.calendar, color: Theme.Tile.sky,
                aliases: ["哪天", "日子", "跳到"]),
            HubTile(
                id: "library", name: "笔记库", symbol: Theme.Symbol.library, color: Theme.Tile.violet,
                aliases: ["原话", "笔记", "说过的话", "记录"]),
            HubTile(
                id: "moments", name: "好时刻", symbol: Theme.Symbol.moments, color: Theme.Tile.rose,
                aliases: ["开心的事", "美好", "高兴"]),
            HubTile(
                id: "year", name: "你的一年", symbol: Theme.Symbol.year, color: Theme.Tile.green,
                aliases: ["今年", "年度", "一年"]),
            HubTile(
                id: "about", name: "关于我", symbol: Theme.Symbol.about, color: Theme.Tile.purple,
                aliases: ["了解", "我", "认识我"]),
            HubTile(
                id: "people", name: "人", symbol: Theme.Symbol.people, color: Theme.Tile.berry,
                aliases: ["朋友", "家人", "同事", "谁"]),
            HubTile(
                id: "talk", name: "你说的话", symbol: Theme.Symbol.talk, color: Theme.Tile.indigo,
                aliases: ["说法", "口头禅", "常说"]),
            HubTile(
                id: "finds", name: "新发现", symbol: Theme.Symbol.finds, color: Theme.Tile.green,
                aliases: ["发现", "规律"]),
            HubTile(
                id: "money-list", name: "每一笔", symbol: Theme.Symbol.moneyList, color: Theme.Tile.amber,
                aliases: ["流水", "账单", "明细"]),
            HubTile(
                id: "watch", name: "留意的", symbol: Theme.Symbol.watch, color: Theme.Tile.orange,
                aliases: ["报销", "借出", "没还", "要扣"]),
            HubTile(
                id: "fixed", name: "固定的", symbol: Theme.Symbol.fixed, color: Theme.Tile.bronze,
                aliases: ["房租", "会员", "订阅", "每月"]),
            HubTile(
                id: "renqing", name: "人情往来", symbol: Theme.Symbol.renqing, color: Theme.Tile.brick,
                aliases: ["红包", "礼金", "随礼", "份子钱"]),
            HubTile(
                id: "worth", name: "值不值", symbol: Theme.Symbol.worth, color: Theme.Tile.green,
                aliases: ["值得", "后悔", "买的东西"]),
            HubTile(
                id: "goals", name: "目标", symbol: Theme.Symbol.goals, color: Theme.Tile.green,
                aliases: ["计划", "想做到"]),
            HubTile(
                id: "streak", name: "坚持", symbol: Theme.Symbol.streak, color: Theme.Tile.red,
                aliases: ["打卡", "连续", "习惯"]),
            HubTile(
                id: "budget", name: "预算", symbol: Theme.Symbol.budget, color: Theme.Tile.amber,
                aliases: ["不超过", "限额", "省钱"]),
        ].map { ($0.id, $0) })

    /// 顶上搜功能：名字或别名里有这几个字的（按全部功能的顺序）
    static func search(_ query: String) -> [HubTile] {
        let words = query.trimmingCharacters(in: .whitespaces)
        guard !words.isEmpty else { return [] }
        return groups.flatMap(\.tiles).compactMap { tiles[$0] }.filter { tile in
            tile.name.contains(words) || tile.aliases.contains { $0.contains(words) || words.contains($0) }
        }
    }
}

/// 一个格子的样子：图标（角上的字、管理时的 −、+）+ 名字（最多 4 个字，一行）
struct HubTileView: View {
    let tile: HubTile
    let badge: String?
    /// nil：没在管理；true：点了放进去（+）；false：点了拿出来（−）
    let mark: Bool?

    var body: some View {
        VStack(spacing: Theme.Space.small) {
            HubTileIcon(symbol: tile.symbol, color: tile.color)
                .overlay(alignment: .topTrailing) {
                    if let badge { HubBadge(badge).offset(x: Theme.Space.small, y: -Theme.Space.snug) }
                }
                .overlay(alignment: .topLeading) {
                    if let mark { HubMark(adding: mark).offset(x: -Theme.Space.small, y: -Theme.Space.small) }
                }
                .hubJiggle(mark != nil)
            Text(tile.name).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.label).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(.isButton)
    }

    private var label: String {
        switch mark {
        case true?: "\(tile.name)，放进常用"
        case false?: "\(tile.name)，从常用拿出来"
        case nil: badge.map { "\(tile.name)，\($0)" } ?? tile.name
        }
    }
}
