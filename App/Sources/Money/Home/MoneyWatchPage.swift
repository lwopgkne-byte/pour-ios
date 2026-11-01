import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 留意的（01 需求文档 5.6、06 交互细节 10.2）：你顺口说过的、和钱有关的事，每一块一张卡片——
/// 等你拿回来的（等报销列每一笔 +「都报销了」；借出去写原话和过去几天 +「已经还了」）→ 每个月固定的（月尺 + 一行一笔）
/// → 买了还没用完的（一节一个点）→ 常买的（最近三次、下次大约哪天）→ 你说过的预算（点进那个目标）。
/// 一行能左滑办事，办完轻提示带撤销；不推送、不打红点
struct MoneyWatchPage: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    @State private var page: API.MoneyWatchPage?
    @State private var problem: String?

    var body: some View {
        List {
            if let page {
                content(page)
            } else if let problem {
                ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
                    .listRowBackground(Color.clear)
            } else {
                ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(Theme.Space.medium)
        .scrollContentBackground(.hidden)
        .background(Theme.Palette.background)
        .refreshable { await load() }
        .task(id: model.dataVersion) { await load() }
    }

    @ViewBuilder private func content(_ page: API.MoneyWatchPage) -> some View {
        let empty =
            page.pending.total == 0 && page.fixed.rows.isEmpty && page.packs.isEmpty && page.frequent.isEmpty
            && page.budgets.isEmpty
        Section {
            Text(
                empty
                    ? "现在没有要留意的。等报销的、借出去的、每个月固定扣的，说过就会出现在这里。"
                    : "你顺口说过的、和钱有关的事，Pour 替你记着。办完了点一下、左滑，或者说一声，就清掉。"
            )
            .font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: Theme.Space.tight, bottom: 0, trailing: Theme.Space.tight))
        }
        if page.pending.total > 0 { pending(page) }
        if !page.fixed.rows.isEmpty { MoneyFixedSection(page: page) }
        if !page.packs.isEmpty { MoneyPacksSection(packs: page.packs) }
        if !page.frequent.isEmpty { MoneyFrequentSection(rows: Array(page.frequent.prefix(4)), today: page.today) }
        if !page.budgets.isEmpty { budgets(page.budgets) }
        Section {
        } footer: {
            Text("这里的每一条都来自你说过的话，点开能看到原话").font(Theme.Typeface.footnote)
                .foregroundStyle(Theme.Palette.secondaryLabel).frame(maxWidth: .infinity)
        }
    }

    // MARK: - 等你拿回来的

    @ViewBuilder private func pending(_ page: API.MoneyWatchPage) -> some View {
        Section {
            if let reimburse = page.pending.reimburse { reimburseRows(reimburse) }
            ForEach(page.pending.lends, id: \.item.entryId) { lend in
                lendRow(lend, quote: page.quotes[String(lend.item.entryId)])
            }
        } header: {
            MoneySectionHeader("等你拿回来的", value: Show.yuan(page.pending.total, hide: hide))
        }
    }

    /// 等报销：先一行合计，再一笔一行（左滑「已报销」），最后「都报销了」
    @ViewBuilder private func reimburseRows(_ reimburse: API.MoneyWatchPage.Reimburse) -> some View {
        let names = reimburse.items.map(\.name).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        VStack(alignment: .leading, spacing: Theme.Space.hairline) {
            MoneyWatchTitle("等报销", amount: Show.yuan(reimburse.total, hide: hide))
            Text("\(reimburse.items.count) 笔\(names.count == 1 ? names[0] : "")，你说过能报销")
                .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
        }
        .padding(.vertical, Theme.Space.tight)
        ForEach(reimburse.items, id: \.self) { item in
            Button {
                model.openMoney(item)
            } label: {
                HStack {
                    Text("\(Show.monthDay(item.day)) · \(Show.spaced(item.name))")
                    Spacer()
                    Text(Show.yuan(item.amount, hide: hide))
                }
                .font(Theme.Typeface.subheadline).monospacedDigit().foregroundStyle(Theme.Palette.label)
                .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing) {
                Button("已报销") {
                    model.settle(
                        [.init(entryId: item.entryId, index: item.index)], settled: true, said: "报销了：\(item.name)")
                }
                .tint(Theme.Palette.accentFill)
            }
            .accessibilityIdentifier("watch.reimburseItem")
        }
        VStack(alignment: .leading, spacing: 0) {
            ThemeTextButton("都报销了") {
                model.settle(
                    reimburse.items.map { .init(entryId: $0.entryId, index: $0.index) }, settled: true,
                    said: "\(reimburse.items.count) 笔标成已报销了")
            }
            .accessibilityIdentifier("watch.reimburseAll")
            Text("只到了一部分就说一声，比如「报销到账 93」").font(Theme.Typeface.footnote)
                .foregroundStyle(Theme.Palette.secondaryLabel).padding(.bottom, Theme.Space.tight)
        }
    }

    /// 借出去的一笔：借给谁、你当时怎么说的、过去几天了、「已经还了」（左滑也行）
    private func lendRow(_ lend: API.MoneyWatchPage.Lend, quote: String?) -> some View {
        let who = !lend.item.who.isEmpty && lend.item.who != "自己" ? lend.item.who : "别人"
        let repaid = {
            model.settle(
                [.init(entryId: lend.item.entryId, index: lend.item.index)], settled: true,
                said: "还回来了：借给\(who)")
        }
        let since = "\(Show.monthDay(lend.item.day)) · 过去 \(lend.days) 天了"
        return VStack(alignment: .leading, spacing: Theme.Space.small) {
            // 名字、钱、原话、过去几天读成一句（这一行能左滑：单独的小字会被审计当成能点的、嫌太小）
            VStack(alignment: .leading, spacing: Theme.Space.small) {
                MoneyWatchTitle("借给\(who)", amount: Show.yuan(lend.item.amount, hide: hide))
                if let quote { Text("「\(quote)」").font(Theme.Typeface.quote).foregroundStyle(Theme.Palette.label) }
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(Text(since))
            HStack(alignment: .firstTextBaseline) {
                Text(since).font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(
                    Theme.Palette.secondaryLabel
                )
                .accessibilityHidden(true)
                Spacer()
                ThemeTextButton("已经还了", action: repaid).accessibilityIdentifier("watch.repaid")
            }
        }
        .padding(.top, Theme.Space.small)
        .swipeActions(edge: .trailing) {
            Button("已还", action: repaid).tint(Theme.Palette.accentFill)
        }
    }

    // MARK: - 你说过的预算

    private func budgets(_ budgets: [API.MoneyBudget]) -> some View {
        Section {
            ForEach(budgets, id: \.id) { budget in
                Button {
                    model.openGoal(budget.id)
                } label: {
                    BudgetRow(
                        Show.spaced(budget.title), text: Show.spaced(budget.headline), pct: budget.pct,
                        over: budget.tone == "bad" || budget.tone == "warn"
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            MoneySectionHeader("你说过的预算")
        }
    }

    private func load() async {
        let path = "/api/money/watch"
        if page == nil, let saved: API.MoneyWatchPage = model.client.cached(path) { page = saved }
        do throws(APIError) {
            page = try await model.client.moneyWatch()
            problem = nil
        } catch {
            if page == nil { problem = error.message }
        }
    }
}

/// 一块的标题（插图列表的组头）：左边名字，右边一个数（「等你拿回来的 ¥2,056」）
struct MoneySectionHeader: View {
    let title: String
    let value: String?

    init(_ title: String, value: String? = nil) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
            Spacer()
            if let value {
                Text(value).font(Theme.Typeface.subheadline).monospacedDigit()
                    .foregroundStyle(Theme.Palette.secondaryLabel)
            }
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// 一张卡片里一件事的第一行：名字、钱（半粗）
struct MoneyWatchTitle: View {
    let name: String
    let amount: String

    init(_ name: String, amount: String) {
        self.name = name
        self.amount = amount
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.small) {
            Text(Show.spaced(name)).frame(maxWidth: .infinity, alignment: .leading)
            Text(amount).monospacedDigit()
        }
        .font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
        .accessibilityElement(children: .combine)
    }
}
