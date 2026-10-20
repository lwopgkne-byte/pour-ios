import PourAPI
import PourDesign
import SwiftUI

/// 留意的（网页版 MoneyWatchPage.tsx，docs/prd-money.md 5.5）：你顺口说过的、和钱有关的事——等你拿回来的、
/// 每个月固定的、买了还没用完的、常买的、你说过的预算。办完了点一下就清掉（带撤销），或者说一声。不推送、不打红点
struct MoneyWatchView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    let navigate: (String) -> Void
    @State private var page: API.MoneyWatchPage?
    @State private var problem: String?

    var body: some View {
        Group {
            if let page {
                content(page)
            } else if let problem {
                WebErrorState(problem) { Task { await load() } }
            } else {
                ReviewSkeleton()
            }
        }
        .moneyPage()
        .task(id: model.dataVersion) { await load() }
    }

    @ViewBuilder private func content(_ page: API.MoneyWatchPage) -> some View {
        let empty =
            page.pending.total == 0 && page.fixed.rows.isEmpty && page.packs.isEmpty && page.frequent.isEmpty
            && page.budgets.isEmpty
        VStack(alignment: .leading, spacing: Web.space6) {
            MoneyHead(title: "留意的") {
                navigate("/money")
            } sub: {
                Text("你顺口说过的、和钱有关的事，Pour 替你记着。办完了点一下，或者说一声，就清掉。").font(Web.body)
                    .foregroundStyle(Web.fg)
            }
            if empty {
                Text("现在没有要留意的。等报销的、借出去的、每个月固定扣的，说过就会出现在这里。").font(Web.body)
                    .foregroundStyle(Web.fgSecondary)
            }
            if page.pending.total > 0 { PendingCards(page: page) }
            if !page.fixed.rows.isEmpty { FixedSection(page: page) }
            if !page.packs.isEmpty {
                ReviewSection(title: "买了还没用完的") {
                    VStack(spacing: Web.space3) { ForEach(page.packs, id: \.entryId) { pack($0) } }
                }
            }
            if !page.frequent.isEmpty {
                ReviewSection(title: "常买的") {
                    VStack(spacing: Web.space3) {
                        ForEach(page.frequent.prefix(4), id: \.name) { frequent($0, today: page.today) }
                    }
                }
            }
            if !page.budgets.isEmpty { budgets(page.budgets) }
            ReviewFoot { Text("这里的每一条都来自你说过的话，点开能看到原话") }
        }
    }

    /// 你说过的预算：点开是那个目标
    private func budgets(_ budgets: [API.MoneyBudget]) -> some View {
        ReviewSection(title: "你说过的预算") {
            VStack(alignment: .leading, spacing: Web.space4) {
                ForEach(budgets, id: \.id) { budget in
                    Button {
                        model.openGoal(budget.id)
                    } label: {
                        VStack(alignment: .leading, spacing: Web.space2) {
                            Text(Show.spaced(budget.title)).font(Web.body).foregroundStyle(Web.fg)
                            GoalBar(pct: budget.pct, tone: budget.tone)
                            Text(Show.spaced(budget.headline)).font(Web.caption).foregroundStyle(Web.fgTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(WebPressStyle(radius: Web.radiusControl))
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    /// 买了还没用完的（课时、次卡）：一节一个点，说到上过的深
    private func pack(_ pack: API.PackRow) -> some View {
        let unit = pack.name.contains("课") ? "节" : "次"
        let owner = !pack.who.isEmpty && pack.who != "自己" && pack.who != "一家人" ? "\(pack.who)的" : ""
        let used = pack.used.map(Show.monthDay).joined(separator: "、")
        let each = Show.yuan((pack.amount / Double(pack.pack)).rounded(), hide: hide)
        let said = "你说到\(unit == "节" ? "上过" : "用了") \(pack.used.count) \(unit)\(used.isEmpty ? "" : "：\(used)")"
        return Button {
            navigate("/money/thing/\(pack.entryId)")
        } label: {
            MoneyCard {
                MoneyCardHead(
                    name: "\(owner)\(pack.name) · \(pack.pack) \(unit)", amount: Show.yuan(pack.amount, hide: hide))
                PourFlowLayout(spacing: Web.space3, lineSpacing: Web.space2) {
                    ForEach(0..<pack.pack, id: \.self) { index in
                        Circle().fill(index < pack.used.count ? Web.fgSecondary : Web.lineStrong)
                            .frame(width: Web.space3, height: Web.space3)
                    }
                }
                .padding(.top, Web.space2).padding(.bottom, Web.space1)
                .accessibilityLabel(Text("\(pack.pack) \(unit)里你说到上过 \(pack.used.count) \(unit)"))
                Text(Show.spaced("\(Show.monthDay(pack.day))买的，每\(unit) \(each) · \(said)"))
                    .font(Web.caption).foregroundStyle(Web.fgTertiary)
            }
        }
        .buttonStyle(.plain)
    }

    /// 常买的：大约多久买一次、最近三次、按平常下次大约哪天、价钱怎么变
    private func frequent(_ row: API.FrequentRow, today: String) -> some View {
        let every = row.every >= 14 ? "大约 \(Int((Double(row.every) / 7).rounded())) 周买一次" : "大约 \(row.every) 天买一次"
        return MoneyCard {
            HStack(alignment: .firstTextBaseline, spacing: Web.space2) {
                Text(row.name).font(Web.bodySemibold).foregroundStyle(Web.fg).frame(
                    maxWidth: .infinity, alignment: .leading)
                Text(every).font(Web.caption).foregroundStyle(Web.fgTertiary)
            }
            HStack(spacing: Web.space2) {
                ForEach(row.recent, id: \.day) { buy in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Show.monthDay(buy.day)).font(Web.caption).foregroundStyle(Web.fgTertiary)
                        Text(Show.yuan(buy.amount, hide: hide)).font(Web.bodySemibold).foregroundStyle(Web.fg)
                    }
                    .monospacedDigit()
                    .padding(.vertical, Web.space2).padding(.horizontal, Web.space3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: Web.radiusControl).fill(Web.bg))
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, Web.space2).padding(.bottom, Web.space1)
            Text(
                rich(
                    row.next >= today
                        ? [.init("按平常，"), .bold("\(Show.monthDay(row.next))前后"), .init("又该买了")]
                        : [.init("按平常，"), .bold(Show.monthDay(row.next)), .init("就该买了")]))
            if let price = row.price {
                Text(Show.spaced(Show.maskYuan(price, hide: hide))).font(Web.caption).foregroundStyle(Web.fgTertiary)
            }
        }
    }

    private func load() async {
        do {
            page = try await model.client.moneyWatch()
            problem = nil
        } catch {
            problem = error.readable
        }
    }
}

/// 一件事一张浅底的卡片
struct MoneyCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Web.space1) { content() }
            .padding(Web.space4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Web.radiusPanel).fill(Web.bgSubtle))
    }
}

/// 卡片第一行：名字和钱（半粗）
struct MoneyCardHead: View {
    let name: String
    let amount: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Web.space2) {
            Text(Show.spaced(name)).frame(maxWidth: .infinity, alignment: .leading)
            Text(amount).monospacedDigit()
        }
        .font(Web.bodySemibold).foregroundStyle(Web.fg)
        .accessibilityElement(children: .combine)
    }
}

/// 等你拿回来的：等报销的一张卡片（「都报销了」）、借出去的一笔一张（「已经还了」）
private struct PendingCards: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    let page: API.MoneyWatchPage

    var body: some View {
        ReviewSection(title: "等你拿回来的 · \(Show.yuan(page.pending.total, hide: hide))") {
            VStack(spacing: Web.space3) {
                if let reimburse = page.pending.reimburse { reimburseCard(reimburse) }
                ForEach(page.pending.lends, id: \.item.entryId) { lend in
                    MoneyCard {
                        let who = !lend.item.who.isEmpty && lend.item.who != "自己" ? lend.item.who : "别人"
                        MoneyCardHead(name: "借给\(who)", amount: Show.yuan(lend.item.amount, hide: hide))
                        if let quote = page.quotes[String(lend.item.entryId)] {
                            Text("「\(quote)」").font(Web.quote).foregroundStyle(Web.fg)
                        }
                        Text("\(Show.monthDay(lend.item.day)) · 过去 \(lend.days) 天了").font(Web.caption)
                            .foregroundStyle(Web.fgTertiary)
                        foot {
                            WebTextButton("已经还了") {
                                model.settle(
                                    [.init(entryId: lend.item.entryId, index: lend.item.index)], settled: true,
                                    said: "标成已还了")
                            }
                        }
                    }
                }
            }
        }
    }

    private func reimburseCard(_ reimburse: API.MoneyWatchPage.Reimburse) -> some View {
        let names = reimburse.items.map(\.name).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        return MoneyCard {
            MoneyCardHead(name: "等报销", amount: Show.yuan(reimburse.total, hide: hide))
            Text("\(reimburse.items.count) 笔\(names.count == 1 ? names[0] : "")，你说过能报销").font(Web.caption)
                .foregroundStyle(Web.fgTertiary)
            VStack(spacing: 0) {
                ForEach(reimburse.items, id: \.self) { item in
                    HStack {
                        Text(Show.spaced("\(Show.monthDay(item.day)) · \(item.name)"))
                        Spacer()
                        Text(Show.yuan(item.amount, hide: hide))
                    }
                    .font(Web.body).foregroundStyle(Web.fgSecondary).monospacedDigit()
                    .frame(minHeight: Web.touch)
                    .overlay(alignment: .top) { Rectangle().fill(Web.line).frame(height: 1) }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, Web.space2)
            foot {
                WebTextButton("都报销了") {
                    model.settle(
                        reimburse.items.map { .init(entryId: $0.entryId, index: $0.index) }, settled: true,
                        said: "\(reimburse.items.count) 笔标成已报销了")
                }
                Text("只到了一部分就说一声，比如「报销到账 93」").font(Web.caption).foregroundStyle(Web.fgTertiary)
            }
        }
    }

    private func foot<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: Web.space3) { content() }
            .frame(maxWidth: .infinity, minHeight: Web.touch, alignment: .leading)
            .overlay(alignment: .top) { Rectangle().fill(Web.line).frame(height: 1) }
    }
}
