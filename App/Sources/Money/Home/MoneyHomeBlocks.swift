import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 这个月（3.0 第三版补上的）：固定的 · 收入 · 人情往来三行，点进去
struct MoneyThisMonth: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    let page: API.MoneyMonth
    let renqing: API.RenqingBrief?

    var body: some View {
        let rows = lines
        if !rows.isEmpty {
            PageSection(title: page.current ? "这个月" : Show.monthName(page.month), padded: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(rows, id: \.title) { row in
                        Button {
                            model.open(row.path)
                        } label: {
                            ThemeListRow(row.title, subtitle: row.text, symbol: row.symbol, color: row.color)
                        }
                        .buttonStyle(PressScale())
                    }
                }
                .padding(.vertical, Theme.Space.tight)
            }
        }
    }

    private struct Line {
        let title: String
        let text: String
        let symbol: String
        let color: Color
        let path: String
    }

    private var lines: [Line] {
        var rows: [Line] = []
        let fixed = page.fixed
        if fixed.paidCount > 0 || fixed.upcoming > 0 {
            let paid = fixed.paidCount > 0 ? "已扣 \(Show.yuan(fixed.paid, hide: hide))" : nil
            let upcoming = fixed.upcoming > 0 ? "还要扣 \(Show.yuan(fixed.upcoming, hide: hide))" : nil
            rows.append(
                Line(
                    title: "固定的", text: [paid, upcoming].compactMap { $0 }.joined(separator: " · "),
                    symbol: Theme.Symbol.fixed, color: Theme.Tile.sky, path: "/money/list/\(page.month)?kind=fixed"))
        }
        if page.income.total > 0, let last = page.income.items.first {
            let more =
                page.income.items.count > 1 ? "\(page.income.items.count) 笔" : "\(Show.monthDay(last.day)) \(last.name)"
            rows.append(
                Line(
                    title: "收入", text: "\(Show.yuan(page.income.total, hide: hide)) · \(more)",
                    symbol: "arrow.down.circle.fill",
                    color: Theme.Tile.green, path: "/money/list/\(page.month)?kind=income"))
        }
        if let renqing {
            let out = renqing.out > 0 ? "送出 \(Show.yuan(renqing.out, hide: hide))" : nil
            let got = renqing.into > 0 ? "收到 \(Show.yuan(renqing.into, hide: hide))" : nil
            let text = [out, got].compactMap { $0 }.joined(separator: " · ")
            rows.append(
                Line(
                    title: "人情往来", text: text.isEmpty ? "来往 \(renqing.times) 次" : text, symbol: Theme.Symbol.renqing,
                    color: Theme.Tile.red, path: "/money/renqing"))
        }
        return rows
    }
}

/// 留意（06 交互细节 3.6）：最多 3 条，一行一件 + 右边按钮（都报销了 · 已经还了 · 不再算固定的）；
/// 点了这一行收起，轻提示能撤销；点一行进「留意的」
struct MoneyWatchCard: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    let lines: [API.WatchLine]
    let done: (String) -> Void

    var body: some View {
        PageSection(title: "留意", link: "全部 ›", open: { model.open("/money/watch") }, content: { rows })
    }

    @ViewBuilder private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            if lines.isEmpty {
                Text("没有要你马上办的。课时、常买的在「全部」里").font(Theme.Typeface.footnote)
                    .foregroundStyle(Theme.Palette.secondaryLabel).padding(.vertical, Theme.Space.small)
            }
            ForEach(Array(lines.prefix(3)), id: \.key) { line in
                HStack(spacing: Theme.Space.small) {
                    Button {
                        model.open("/money/watch")
                    } label: {
                        VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                            Text("\(Show.spaced(line.name)) \(Show.yuan(line.amount, hide: hide))")
                                .font(Theme.Typeface.body).monospacedDigit().foregroundStyle(Theme.Palette.label)
                            Text(Show.maskYuan(line.sub, hide: hide)).font(Theme.Typeface.footnote)
                                .foregroundStyle(Theme.Palette.secondaryLabel)
                        }
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if let title = action(line), let refs = line.refs, !refs.isEmpty {
                        Button(title) { act(line, refs: refs) }
                            .font(Theme.Typeface.footnoteSemibold).buttonStyle(.bordered).buttonBorderShape(.capsule)
                            .tint(Theme.Palette.accent)
                            .accessibilityIdentifier("money.watch.\(line.kind)")
                    }
                }
                .padding(.vertical, Theme.Space.tight)
            }
        }
    }

    /// 右边的按钮：等报销的「都报销了」、借出去的「已经还了」、没在用的「不再算固定的」；快扣的只提醒
    private func action(_ line: API.WatchLine) -> String? {
        switch line.kind {
        case "reimburse": "都报销了"
        case "lend": "已经还了"
        case "unused": "不再算固定的"
        default: nil
        }
    }

    private func act(_ line: API.WatchLine, refs: [API.WatchRef]) {
        let moneyRefs = refs.map { API.MoneyRef(entryId: $0.entryId, index: $0.index) }
        withAnimation(Theme.Motion.standard) { done(line.key) }
        if line.kind == "unused", let ref = moneyRefs.first {
            model.endFixed(ref, ended: true, said: "不再算固定的了：\(line.name)")
        } else {
            model.settle(moneyRefs, settled: true, said: line.kind == "lend" ? "还回来了：\(line.name)" : "报销了：\(line.name)")
        }
    }
}

/// 花在哪（06 交互细节 3.6）：一行一个领域：图标、名字、金额、百分比、同色的条（最长的满格）；点一行看那一类的每一笔
struct MoneyDomainsCard: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    let page: API.MoneyMonth

    var body: some View {
        if page.count >= MoneyLaterCard.enough, page.domains.count >= 2 {
            let total = max(1, page.domains.map(\.amount).reduce(0, +))
            let most = max(1, page.domains.map(\.amount).max() ?? 1)
            PageSection(title: "花在哪", meta: "\(Show.monthName(page.month)) · 点一行看那几笔") {
                domains(total: total, most: most)
            }
        }
    }

    @ViewBuilder private func domains(total: Double, most: Double) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            ForEach(page.domains, id: \.key) { domain in
                Button {
                    model.open("/money/list/\(page.month)?domain=\(domain.key)")
                } label: {
                    row(domain, share: domain.amount / total, bar: domain.amount / most)
                }
                .buttonStyle(PressScale())
            }
            if let note = page.domainNote {
                Text(Show.maskYuan(note, hide: hide)).font(Theme.Typeface.footnote)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
            }
        }
    }

    private func row(_ domain: API.MoneyDomain, share: Double, bar: Double) -> some View {
        let color = Theme.tag(domain.color)
        return VStack(alignment: .leading, spacing: Theme.Space.tight) {
            HStack(spacing: Theme.Space.small) {
                IconTile(
                    symbol: CategoryIcon.symbol(key: domain.key, name: domain.name),
                    emoji: String(domain.name.prefix(1)),
                    color: color)
                Text(domain.name).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                Spacer()
                Text("\(Show.yuan(domain.amount, hide: hide)) · \(Int((share * 100).rounded()))%")
                    .font(Theme.Typeface.subheadline).monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
            }
            GeometryReader { proxy in
                Capsule().fill(color.solid).frame(width: max(Theme.Space.tight, proxy.size.width * bar))
            }
            .frame(height: Theme.Space.snug)
            .accessibilityHidden(true)
        }
        .padding(.vertical, Theme.Space.tight)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// 花给了谁：一家人一起的单独一句；给一个人的一行一个：名字、条、金额
struct MoneyWhoCard: View {
    @AppStorage(MoneyHidden.key) private var hide = false
    let who: API.MoneyWho

    var body: some View {
        let most = max(who.people.map(\.amount).max() ?? 1, 1)
        PageSection(title: "花给了谁", meta: Show.monthName(String(who.from.prefix(7)))) { people(most: most) }
    }

    @ViewBuilder private func people(most: Double) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text("\(Show.monthDay(who.from))以来日常花的 \(Show.yuan(who.total, hide: hide))").font(Theme.Typeface.footnote)
                .monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
            if let family = who.family {
                Text("一家人一起的（吃的、玩的、家里用的）\(Show.yuan(family.amount, hide: hide))，占了\(family.share)")
                    .font(Theme.Typeface.subheadline).monospacedDigit().foregroundStyle(Theme.Palette.label)
            }
            ForEach(who.people, id: \.name) { person in
                HStack(spacing: Theme.Space.small) {
                    Text(person.name).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label).lineLimit(1)
                        .frame(minWidth: Theme.Size.touch, alignment: .leading)
                    GeometryReader { proxy in
                        Capsule().fill(person.strong ? Theme.Palette.accentFill : Theme.Palette.tertiaryLabel)
                            .frame(width: max(Theme.Space.tight, proxy.size.width * person.amount / most))
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: Theme.Space.snug)
                    Text(Show.yuan(person.amount, hide: hide)).font(Theme.Typeface.subheadline).monospacedDigit()
                        .foregroundStyle(Theme.Palette.secondaryLabel).fixedSize()
                }
                .frame(minHeight: Theme.Size.touch)
                .accessibilityElement(children: .combine)
            }
            if let sentence = who.sentence {
                Text(Show.maskYuan(sentence, hide: hide)).font(Theme.Typeface.footnote)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
            }
        }
    }
}

/// 值不值 · 你自己说的（原型钱主页）：标题在卡片外面，下面横着滑一张张白卡（MoneyWorthCard，236 宽，一样高），
/// 一直滑到屏幕边；点一张进那样东西
struct MoneyWorthStrip: View {
    let worth: API.MoneyWorth

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            PageSectionHeader(title: "值不值 · 你自己说的").padding(.top, Theme.Space.medium)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Theme.Space.small + Theme.Space.hairline) {
                    ForEach(worth.good, id: \.entryId) {
                        MoneyWorthCard(thing: $0, good: true, width: MoneyWorthCard.stripWidth)
                    }
                    ForEach(worth.regret, id: \.entryId) {
                        MoneyWorthCard(thing: $0, good: false, width: MoneyWorthCard.stripWidth)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                // 留出卡片的影子
                .padding(.vertical, Theme.Space.small)
            }
            .contentMargins(.horizontal, Theme.Space.screen, for: .scrollContent)
            .padding(.horizontal, -Theme.Space.screen)
        }
    }
}
