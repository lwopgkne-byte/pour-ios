import PourAPI
import PourDesign
import SwiftUI

/// 一笔钱画成一行（06 交互细节 3.3）：领域图标、名字和种类标签、时间 · 给谁、金额
/// （等报销、借出去的灰；收入、回来的钱、收到的人情绿「+¥」）。主页点一天、每一笔、一天的钱都用它
struct MoneyItemRow: View {
    @AppStorage(MoneyHidden.key) private var hide = false
    let item: API.MoneyItem
    /// 刚记下、还在整理（数字键盘记的一笔，服务器还没整理完）
    var pending = false

    var body: some View {
        MoneyRowLabel(
            Show.spaced(item.name), tags: tags, sub: sub, amount: Show.yuan(item.amount, hide: hide, plus: plus),
            tone: tone
        ) {
            MoneyDomainIcon(domain: item.domain)
        }
    }

    private var tags: [MoneyKindTag] {
        if pending { return [.pending] }
        switch item.kind {
        case "reimburse": return item.settled == true ? [] : [.reimburse]
        case "lend": return item.settled == true ? [] : [.lend]
        case "fixed": return [.fixed]
        case "income": return [.income]
        case "back": return [.returned]
        case "gift": return [.renqing]
        default: return item.renqing != nil ? [.renqing] : []
        }
    }

    private var plus: Bool { ["income", "back", "gift"].contains(item.kind) }

    private var tone: AmountTone {
        if plus { return .income }
        return ["reimburse", "lend"].contains(item.kind) ? .muted : .normal
    }

    /// 「19:40 · 给老同学」「已报销」「已还」
    private var sub: String? {
        var parts: [String] = []
        if let time = item.time { parts.append(time) }
        if !item.who.isEmpty, item.who != "自己" {
            parts.append(item.kind == "gift" ? "\(item.who)给的" : "给\(item.who)")
        }
        if item.settled == true { parts.append(item.kind == "lend" ? "已还" : "已报销") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// 刚记下、还在整理的一笔（数字键盘记的）：右边小字「整理中」，整理完变成正式的一行
struct MoneyPendingRow: View {
    @AppStorage(MoneyHidden.key) private var hide = false
    let pending: PendingMoney

    var body: some View {
        MoneyRowLabel(
            Show.spaced(pending.name), tags: [.pending], sub: pending.time,
            amount: Show.yuan(pending.amount, hide: hide, plus: pending.kind == "income"),
            tone: pending.kind == "income" ? .income : ["reimburse", "lend"].contains(pending.kind) ? .muted : .normal
        ) {
            IconTile(symbol: "yensign", emoji: "", color: Theme.tag("gray"))
        }
    }
}

/// 领域的图标小方块（饮食、出行、购物……）：线条图标，认不出的用它自己的颜色写第一个字
struct MoneyDomainIcon: View {
    let domain: API.MoneyDomainRef

    var body: some View {
        IconTile(
            symbol: CategoryIcon.symbol(key: domain.key, name: domain.name) ?? "yensign",
            emoji: String(domain.name.prefix(1)), color: Theme.tag(domain.color))
    }
}

extension Show {
    /// 月历一格里的钱：不带 ¥，上万写「2万」「1.5万」；遮住金额写「•••」
    static func calendarAmount(_ value: Double, hide: Bool) -> String {
        if hide { return "•••" }
        if value >= 10_000 {
            let tenThousands = (value / 1_000).rounded() / 10
            return tenThousands == tenThousands.rounded() ? "\(Int(tenThousands))万" : "\(tenThousands)万"
        }
        return "\(Int(value.rounded()))"
    }
}
