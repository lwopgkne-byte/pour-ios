import Foundation
import PourAPI

/// 3.0 外壳里推进来的一页（docs/3.0/01-需求文档.md 2.6 页面地图、07 开发任务清单 1.6）。
/// 根是生活画布，不在这里；别的页都推进同一个导航栈，返回一路回到画布。
/// 页面地址（服务器、对话、推送里的「/review/2026-10-18」「/money/watch」……）照旧认：`Route(path:)` 一条一条对上
enum Route: Hashable {
    /// 我的 = 全部功能（画布左上角「我」）
    case hub
    /// 待办（3.0 第 2 步：画布待办卡的标题、我的 → 待办、点了通知）
    case todos
    /// 回顾：nil 是列表
    case review(ReviewRoute?)
    case money(MoneyRoute)
    case about(AboutRoute, ask: KnownAsk?)
    case goals
    case library(LibraryAsk)
    /// 设置：打开时滚到哪一块（「data」）
    case settings(String?)

    /// 页面地址 → 推哪一页；认不得的是 nil。「/」是画布（不推页，回到底）
    init?(path: String) {
        let parts = path.split(separator: "#", maxSplits: 1).map(String.init)
        let base = parts.first ?? path
        let anchor = parts.count > 1 ? parts[1] : nil
        let head = base.split(separator: "?", maxSplits: 1).first.map(String.init) ?? base
        guard let route = Self.page(head: head, base: base, anchor: anchor) else { return nil }
        self = route
    }

    /// 「/review/…」「/money/…」「/about/…」各自认；只有一层的（/me、/goals、/library、/settings）要一字不差
    private static func page(head: String, base: String, anchor: String?) -> Route? {
        switch head.split(separator: "/").first.map(String.init) {
        case "review":
            if head == "/review" { .review(nil) } else { ReviewRoute(head).map { .review($0) } }
        case "money": MoneyRoute(base).map { .money($0) }
        case "about": AboutRoute(base).map { .about($0, ask: KnownAsk(path: base)) }
        default:
            [
                "/me": .hub, "/todos": .todos, "/goals": .goals, "/library": .library(LibraryAsk(path: base)),
                "/settings": .settings(anchor),
            ][head]
        }
    }

    /// 这一页的名字：导航栏上、下一页的返回按钮上（「‹ 人情往来」；太长的由系统换成「返回」）
    var title: String {
        switch self {
        case .hub: "我的"
        case .todos: "待办"
        case .review(nil): "回顾"
        case .review(.daily?): "每日回顾"
        case .review(.period(let kind, _)?): kind == "monthly" ? "月报" : "周报"
        case .money(let money): money.title
        case .about(let about, _): about.title
        case .goals: "目标"
        case .library: "笔记库"
        case .settings: "设置"
        }
    }

    /// 同一种页面里翻页（上一天、下一个月、换一个领域）：换掉最上面这一页，不再往里推一层。
    /// 不然左右滑翻十天，要按十次返回
    func sameKind(as other: Route) -> Bool {
        switch (self, other) {
        case (.review(.daily?), .review(.daily?)), (.review(.period?), .review(.period?)): true
        case (.money(let left), .money(let right)): left.kind == right.kind
        case (.about(let left, _), .about(let right, _)): left.kind == right.kind && left.kind != "home"
        case (.library, .library), (.settings, .settings), (.goals, .goals), (.hub, .hub), (.todos, .todos): true
        default: false
        }
    }
}

/// 笔记库打开时：哪一栏（原话 · 感悟 · 好时刻）、从哪一段原话开始看、带着哪个人
/// （「/library?note=12」「/library?view=insights」「/library?tag=小王」）
struct LibraryAsk: Hashable {
    var view = "notes"
    var note: Int?
    var tag = ""

    init(view: String = "notes", note: Int? = nil, tag: String = "") {
        self.view = view
        self.note = note
        self.tag = tag
    }

    init(path: String) {
        let query = URLComponents(string: path)?.queryItems ?? []
        let value = { (name: String) in query.first { $0.name == name }?.value }
        view = value("view").flatMap { ["insights", "moments"].contains($0) ? $0 : nil } ?? "notes"
        note = value("note").flatMap(Int.init)
        tag = value("tag") ?? ""
    }
}

extension KnownAsk {
    /// 「/about?item=person:小王」「/about?find=老地方」（对话里「记住了」的链接）；都没有是 nil
    init?(path: String) {
        let query = URLComponents(string: path)?.queryItems ?? []
        let item = query.first { $0.name == "item" }?.value
        let find = query.first { $0.name == "find" }?.value
        guard item != nil || find != nil else { return nil }
        self.init(item: item, find: find)
    }
}

extension MoneyRoute {
    var title: String {
        switch self {
        case .month: "钱"
        case .day(let day): Show.monthDay(day)
        case .list: "每一笔"
        case .watch: "留意的"
        case .thing: "一样东西"
        case .renqing: "人情往来"
        case .person(let name): name
        }
    }

    /// 哪一种页（翻页时只换同一种）
    var kind: String {
        switch self {
        case .month: "month"
        case .day: "day"
        case .list: "list"
        case .watch: "watch"
        case .thing: "thing"
        case .renqing: "renqing"
        case .person: "person"
        }
    }
}

extension AboutRoute {
    var title: String {
        switch self {
        case .home, .domain: "关于我"
        case .mood: "心情"
        case .people: "人"
        case .talk: "你说的话"
        case .year: "你的一年"
        }
    }

    var kind: String {
        switch self {
        case .home: "home"
        case .mood: "mood"
        case .people: "people"
        case .talk: "talk"
        case .year: "year"
        case .domain: "domain"
        }
    }
}
