import PourAPI
import PourDesign
import SwiftUI

/// 「钱」（docs/prd-money.md）：这个月日常花了多少、每天花在哪、固定的和收入、留意、花在哪、
/// 花给了谁、值不值；点进去是一天的钱、每一笔、留意的、一样东西、人情往来。数字全部是服务器现算的。
/// 3.0 外壳（第 1 步）：一个地址一页，点进去的推进导航栈，翻上一个月、下一天换掉这一页（AppModel.open）
struct MoneyPage: View {
    @Environment(AppModel.self) private var model
    let route: MoneyRoute

    var body: some View {
        switch route {
        case .month(let month): MoneyMonthView(month: month ?? String(model.today.prefix(7)), navigate: navigate)
        case .day(let day): MoneyDayView(day: day, navigate: navigate)
        case .list(let month, let filter): MoneyListView(month: month, filter: filter, navigate: navigate)
        case .watch: MoneyWatchView(navigate: navigate)
        case .thing(let id): MoneyThingView(id: id, navigate: navigate)
        case .renqing: RenqingView(navigate: navigate)
        case .person(let name): RenqingPersonView(name: name, navigate: navigate)
        }
    }

    /// 换到一个页面地址（钱里互相跳、去别处）
    private func navigate(_ path: String) {
        model.open(path)
    }
}

/// 只看一类：固定的、收入（kind），或者某一块生活（domain）
struct MoneyFilter: Hashable {
    var kind: String?
    var domain: String?
}

/// 钱里的一页
enum MoneyRoute: Hashable {
    /// nil 是这个月
    case month(String?)
    case day(String)
    case list(String, MoneyFilter)
    case watch
    case thing(Int)
    case renqing
    case person(String)

    /// 「/money」「/money/2026-09」「/money/day/2026-10-18」「/money/list/2026-10?kind=fixed」「/money/watch」
    /// 「/money/thing/22」「/money/renqing」「/money/renqing/小李」
    init?(_ path: String) {
        let pieces = path.split(separator: "?", maxSplits: 1).map(String.init)
        let parts = pieces[0].split(separator: "/").map { String($0).removingPercentEncoding ?? String($0) }
        guard parts.first == "money" else { return nil }
        switch (parts.count, parts.dropFirst().first) {
        case (1, _): self = .month(nil)
        case (2, "watch"): self = .watch
        case (2, "renqing"): self = .renqing
        case (2, let month?) where month.wholeMatch(of: /\d{4}-(0[1-9]|1[0-2])/) != nil: self = .month(month)
        case (3, "day"): self = .day(parts[2])
        case (3, "list"): self = .list(parts[2], Self.filter(pieces.count > 1 ? pieces[1] : ""))
        case (3, "thing") where Int(parts[2]) != nil: self = .thing(Int(parts[2]) ?? 0)
        case (3, "renqing"): self = .person(parts[2])
        default: return nil
        }
    }

    private static func filter(_ query: String) -> MoneyFilter {
        var filter = MoneyFilter()
        for pair in query.split(separator: "&") {
            let item = pair.split(separator: "=", maxSplits: 1).map { String($0).removingPercentEncoding ?? String($0) }
            guard item.count == 2 else { continue }
            if item[0] == "kind" { filter.kind = item[1] }
            if item[0] == "domain" { filter.domain = item[1] }
        }
        return filter
    }
}

/// 遮住金额（docs/prd-money.md 5.10）：只记在这台手机上
struct MoneyHidden {
    static let key = "pour.money.hidden"
}

extension View {
    /// 钱的一页的外框：能上下滚，左右滑翻上一页（往右滑）、下一页（往左滑）；和回顾一样
    func moneyPage(prev: (() -> Void)? = nil, next: (() -> Void)? = nil) -> some View {
        reviewPage(prev: prev, next: next)
    }
}
