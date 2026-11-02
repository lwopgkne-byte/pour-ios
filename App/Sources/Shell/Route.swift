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
    /// 心情（3.0 第 4 步）：心情页、心情分析、好时刻
    case mood(MoodRoute)
    case about(AboutRoute, ask: KnownAsk?)
    /// 感悟（3.0 第 5 步）：今天重温、语录 ★、按月的卡片
    case insights
    /// 目标（3.0 第 7 步）：首页、一个目标、坚持、预算、我在乎的一块
    case goals(GoalRoute)
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
        case "mood": MoodRoute(base).map { .mood($0) }
        // 以前的「关于我 → 心情」搬进了心情分析
        case "about" where head == "/about/mood": .mood(.analysis)
        case "about": AboutRoute(base).map { .about($0, ask: KnownAsk(path: base)) }
        // 以前「笔记库 → 感悟」搬成了自己的一页
        case "library" where LibraryAsk(path: base).view == "insights": .insights
        case "goals": GoalRoute(head).map { .goals($0) }
        default:
            [
                "/me": .hub, "/todos": .todos, "/insights": .insights,
                "/library": .library(LibraryAsk(path: base)), "/settings": .settings(anchor),
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
        case .mood(let mood): mood.title
        case .about(let about, _): about.title
        case .insights: "感悟"
        case .goals(let goal): goal.title
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
        case (.mood(let left), .mood(let right)): left.kind == right.kind
        case (.about(let left, _), .about(let right, _)): left.kind == right.kind && left.kind != "home"
        case (.goals(let left), .goals(let right)): left.kind == right.kind && left.kind != "goal"
        case (.library, .library), (.settings, .settings), (.hub, .hub), (.todos, .todos),
            (.insights, .insights):
            true
        default: false
        }
    }
}

/// 笔记库打开时：哪一栏（原话 · 好时刻）、从哪一段原话开始看、带着哪个人
/// （「/library?note=12」「/library?view=moments」「/library?tag=小王」；「/library?view=insights」是感悟页）
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
        case .person(let name): "和\(name)的来往"
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
        case .people: "人"
        case .talk: "你说的话"
        case .year: "你的一年"
        }
    }

    var kind: String {
        switch self {
        case .home: "home"
        case .people: "people"
        case .talk: "talk"
        case .year: "year"
        case .domain: "domain"
        }
    }
}

/// 目标的几页（「/goals」「/goals/12」「/goals/streaks」「/goals/budgets」「/goals/care/health」）
enum GoalRoute: Hashable {
    case home
    case goal(Int)
    /// 我的 → 坚持：只看坚持的那几行
    case streaks
    /// 我的 → 预算：说过的「不超过」
    case budgets
    /// 我在乎的一块（领域页上面四块）
    case care(String)

    init?(_ path: String) {
        let parts = path.split(separator: "/").map(String.init)
        switch parts.count {
        case 1: self = .home
        case 2 where parts[1] == "streaks": self = .streaks
        case 2 where parts[1] == "budgets": self = .budgets
        case 2:
            guard let id = Int(parts[1]) else { return nil }
            self = .goal(id)
        case 3 where parts[1] == "care": self = .care(parts[2])
        default: return nil
        }
    }

    /// 导航栏上的名字；一个目标、一块的名字页面自己写
    var title: String {
        switch self {
        case .home: "目标"
        case .goal: "目标"
        case .streaks: "坚持"
        case .budgets: "预算"
        case .care: "我在乎的"
        }
    }

    var kind: String {
        switch self {
        case .home: "home"
        case .goal: "goal"
        case .streaks: "streaks"
        case .budgets: "budgets"
        case .care: "care"
        }
    }
}
