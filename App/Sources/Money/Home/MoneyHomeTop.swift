import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 主卡片（06 交互细节 3.1）：「10月日常花的」大数（数字滚动）、「今天 ¥15 · 69 笔」、和上个月比（小胶囊 + 原因）、
/// 每天累计的曲线（按住拖动看每一天）、预算写还能花多少（点了进那个目标）
struct MoneyHero: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    let home: API.MoneyHome
    @State private var whyOpen = false

    var body: some View {
        let page = home.month
        let name = Show.monthName(page.month)
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text(page.current ? "\(name)到今天，日常花的" : "\(name)，日常花的").font(Theme.Typeface.subheadline)
                .foregroundStyle(Theme.Palette.secondaryLabel)
            // 刚用数字键盘记下、还在整理的日常的先加上（整理完换成服务器算的）
            let spent = page.spent + model.pendingSpent(month: page.month)
            Text(Show.yuan(spent, hide: hide)).font(Theme.Typeface.bigNumber).monospacedDigit()
                .foregroundStyle(Theme.Palette.label)
                .contentTransition(.numericText(value: spent))
                .animation(Theme.Motion.standard, value: spent)
                .accessibilityIdentifier("money.spent")
            // 一笔都没有就不写「0 笔」：下面那句说清楚
            if page.count >= 1 {
                Text(countLine(page, name: name)).font(Theme.Typeface.subheadline).monospacedDigit()
                    .foregroundStyle(Theme.Palette.secondaryLabel)
            }
            compare(page, name: name)
            if !page.days.isEmpty || home.pace.previous != nil {
                PaceChart(
                    current: home.pace.current, previous: home.pace.previous, days: Self.days(in: page.month),
                    money: { Show.yuan($0, hide: hide) }, dayName: { "\(Show.monthName(page.month))\($0 + 1)日" }
                )
                .padding(.top, Theme.Space.small)
            }
            if !home.budgets.isEmpty { budgets(home.budgets) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard()
    }

    /// 「今天 ¥15 · 这个月 69 笔」：今天还没说到钱就不写「今天 ¥0」（没说 ≠ 没花）
    private func countLine(_ page: API.MoneyMonth, name: String) -> String {
        let today =
            page.current && (page.todaySpent ?? 0) > 0 ? "今天 \(Show.yuan(page.todaySpent ?? 0, hide: hide)) · " : ""
        return "\(today)\(page.current ? "这个月" : name) \(page.count) 笔"
    }

    /// 和上个月比：小胶囊写差多少（少了绿、多了留意色），后面一句原因；还不能比的说清楚哪天起能比
    @ViewBuilder private func compare(_ page: API.MoneyMonth, name: String) -> some View {
        if let compare = page.compare {
            let parts = compare.text.split(separator: "：", maxSplits: 1).map(String.init)
            let same = abs(compare.diff) <= compare.prevSpent * 0.1
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.small) {
                if !same {
                    Label(
                        "\(compare.diff < 0 ? "少" : "多") \(Show.yuan(abs(compare.diff), hide: hide))",
                        systemImage: compare.diff < 0 ? "arrow.down.right" : "arrow.up.right"
                    )
                    .font(Theme.Typeface.footnoteSemibold).monospacedDigit()
                    .foregroundStyle(compare.diff < 0 ? Theme.Palette.good : Theme.Palette.warnInk)
                    .padding(.horizontal, Theme.Space.small).padding(.vertical, Theme.Space.hairline)
                    .background(compare.diff < 0 ? Theme.Palette.goodFill : Theme.Palette.warnFill, in: Capsule())
                    .fixedSize()
                }
                Text(Show.maskYuan(same ? compare.text : (parts.count > 1 ? parts[1] : "比上个月这时候"), hide: hide))
                    .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    .lineLimit(whyOpen ? nil : 2)
                    .onTapGesture { withAnimation(Theme.Motion.standard) { whyOpen.toggle() } }
            }
            .accessibilityElement(children: .combine)
        } else if let why = explanation(page, name: name) {
            Text(why).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
        }
    }

    private func explanation(_ page: API.MoneyMonth, name: String) -> String? {
        // 这个月还没说到钱：说怎么开始；以前的月份：没说 ≠ 没花
        if page.counts.values.reduce(0, +) == 0 {
            return page.current ? "\(name)还没说到钱。点「记一笔」，或者说一句「午饭 25」。" : "\(name)没说到钱（没说 ≠ 没花）。"
        }
        guard page.current, let from = page.compareFrom else { return nil }
        return "\(Show.monthDay(from))起，就能和上个月比了。"
    }

    /// 预算：一条一条细进度条，写还能花多少；超了写超了多少（留意色，不用红）。点了进那个目标
    private func budgets(_ lines: [API.MoneyBudgetLine]) -> some View {
        VStack(spacing: Theme.Space.small) {
            ForEach(lines) { line in
                Button {
                    model.goalDetail = .init(id: line.id)
                } label: {
                    BudgetRow(
                        Show.spaced(line.title), text: Show.maskYuan(line.text, hide: hide),
                        detail: "已用 \(Show.yuan(line.spent, hide: hide))", pct: line.pct, over: line.left < 0
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("打开这个目标"))
            }
        }
        .padding(.top, Theme.Space.small)
    }

    /// 这个月有几天（横轴到几号）
    static func days(in month: String) -> Int {
        let parts = month.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2,
            let date = Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: 1)),
            let range = Calendar.current.range(of: .day, in: .month, for: date)
        else { return 31 }
        return range.count
    }
}

/// 四个圆按钮（06 交互细节 3.1）：记一笔 · 每一笔 · 留意的（角上数字）· 人情往来
struct MoneyActions: View {
    @Environment(AppModel.self) private var model
    let month: String
    let watchCount: Int

    var body: some View {
        HStack(spacing: 0) {
            RoundAction("记一笔", symbol: Theme.Symbol.add, color: Theme.Quick.money) { model.recordMoney() }
                .accessibilityIdentifier("money.record")
            RoundAction("每一笔", symbol: "list.bullet", color: Theme.Tile.blue) { model.open("/money/list/\(month)") }
                .accessibilityIdentifier("money.list")
            RoundAction("留意的", symbol: Theme.Symbol.watch, color: Theme.Tile.gold, badge: watchCount) {
                model.open("/money/watch")
            }
            .accessibilityIdentifier("money.watch")
            RoundAction("人情往来", symbol: Theme.Symbol.renqing, color: Theme.Tile.red) { model.open("/money/renqing") }
                .accessibilityIdentifier("money.renqing")
        }
        .padding(.vertical, Theme.Space.small)
    }
}
