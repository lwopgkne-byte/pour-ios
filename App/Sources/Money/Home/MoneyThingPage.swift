import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 一样东西（01 需求文档 5.6、06 交互细节 10.2，值不值的卡片点进来）：第一屏「每次 ¥180」大字 +「用了 5 次。每用一次，它就更划算一点」
/// + 台阶线（左边「¥899 买的时候」、右边「现在每次 ¥180」）；你怎么说它（宋体，「买的那天说的 / 买了 8 天以后说的」）；
/// 说到用它的每一次（点开原话）；买的那天。出去玩的不按次数除，只写「之后又说起 3 次」；还没用的说怎么才会有
struct MoneyThingPage: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    let id: Int
    @State private var page: API.MoneyThingPage?
    @State private var problem: String?
    @State private var all = false

    /// 说到用它的那几次：先列最近的几次，其余点「全部」
    private static let firstUses = 4

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
        .task(id: "\(id)-\(model.dataVersion)") { await load() }
    }

    @ViewBuilder private func content(_ thing: API.MoneyThingPage) -> some View {
        let count = thing.uses.count
        let uses = Array(thing.uses.reversed())
        Section { hero(thing, count: count) }
        if let verdict = thing.verdict {
            Section {
                VStack(alignment: .leading, spacing: Theme.Space.small) {
                    Text("「\(verdict.quote)」").font(Theme.Typeface.quoteLarge).foregroundStyle(Theme.Palette.label)
                    Text(saidWhen(verdict, bought: thing.day)).font(Theme.Typeface.footnote)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                }
                .padding(.vertical, Theme.Space.tight)
            } header: {
                MoneySectionHeader("你怎么说它")
            }
        }
        if count > 0 {
            Section {
                ForEach(all ? uses : Array(uses.prefix(Self.firstUses)), id: \.entryId) { use in
                    useRow(day: use.day, text: use.text ?? use.label) { model.openEntry(use.entryId, day: use.day) }
                }
                if !all && count > Self.firstUses {
                    ThemeTextButton("全部 \(count) 次") { withAnimation(Theme.Motion.standard) { all = true } }
                }
            } header: {
                MoneySectionHeader(thing.durable ? "说到用它的每一次" : "之后说起的每一次", value: "\(count) 次")
            }
        }
        if let bought = thing.bought {
            Section {
                useRow(day: bought.day, text: bought.text) { model.openEntry(thing.entryId, day: thing.day) }
            } header: {
                MoneySectionHeader("买的那天")
            }
        }
    }

    /// 第一屏：名字和价钱；每次多少钱（大字）+ 一句 + 台阶线；出去玩的、还没用的各写各的
    private func hero(_ thing: API.MoneyThingPage, count: Int) -> some View {
        let forWhom =
            !thing.who.isEmpty && thing.who != "自己" ? (thing.who == "一家人" ? " · 一家人用" : " · 给\(thing.who)") : ""
        return VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text(Show.spaced(thing.name)).font(Theme.Typeface.section).foregroundStyle(Theme.Palette.label)
                .accessibilityAddTraits(.isHeader)
            Text("\(Show.yuan(thing.amount, hide: hide)) · \(Show.monthDay(thing.day))买的\(forWhom)")
                .font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
            if thing.durable, let perUse = thing.perUse, count > 1 {
                big("每次 \(Show.yuan(perUse, hide: hide))")
                Text("用了 \(count) 次。每用一次，它就更划算一点。").font(Theme.Typeface.body)
                    .foregroundStyle(Theme.Palette.label)
                chart(thing, perUse: perUse)
            } else if thing.durable {
                big(count > 0 ? "用了 \(count) 次" : "还没说到用它")
                Text("之后说到用它（「用空气炸锅烤了鸡翅」），这里就会算每次多少钱。").font(Theme.Typeface.subheadline)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
            } else {
                big(count > 0 ? "之后又说起 \(count) 次" : "之后还没再说起")
                Text("出去玩这类的钱不按次数除，只记你之后又说起几次。").font(Theme.Typeface.subheadline)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
            }
        }
        .padding(.vertical, Theme.Space.small)
    }

    /// 台阶线：左上买的时候、右上现在每次；下面买的那天、今天
    private func chart(_ thing: API.MoneyThingPage, perUse: Double) -> some View {
        let span = max(1, PourDate.diffDays(model.today, thing.day))
        let days = thing.uses.map { min(span, max(0, PourDate.diffDays($0.day, thing.day))) }.sorted()
        let bought = Show.yuan(thing.amount, hide: hide)
        let now = Show.yuan(perUse, hide: hide)
        return VStack(spacing: Theme.Space.tight) {
            HStack(alignment: .firstTextBaseline) {
                Text("**\(bought)** 买的时候")
                Spacer()
                Text("现在每次 **\(now)**")
            }
            .font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
            PerUseChart(total: thing.amount, uses: days, span: span)
            HStack {
                Text(Show.monthDay(thing.day))
                Spacer()
                Text("今天")
            }
            .font(Theme.Typeface.caption).monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
            Text("每个点是你说到用它的一天 · 每次 = \(bought) ÷ 用了几次 · 没说到的不算，实际可能更划算")
                .font(Theme.Typeface.caption).foregroundStyle(Theme.Palette.secondaryLabel)
        }
        .padding(.top, Theme.Space.small)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("每次多少钱：买的时候 \(bought)，用到第 \(thing.uses.count) 次是每次 \(now)"))
    }

    private func big(_ text: String) -> some View {
        Text(text).font(Theme.Typeface.bigNumber).monospacedDigit().foregroundStyle(Theme.Palette.label)
            .padding(.top, Theme.Space.small)
    }

    private func saidWhen(_ verdict: API.Verdict, bought: String) -> String {
        let said = verdict.said ?? bought
        if said != bought { return "\(Show.monthDay(said)) · 买了 \(PourDate.diffDays(said, bought)) 天以后说的" }
        return "\(Show.monthDay(said)) · 买的那天说的"
    }

    /// 一次：日子、你说的；点了看那条记录
    private func useRow(day: String, text: String, open: @escaping () -> Void) -> some View {
        Button(action: open) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.medium) {
                Text(Show.monthDay(day)).font(Theme.Typeface.footnote).monospacedDigit()
                    .foregroundStyle(Theme.Palette.secondaryLabel)
                    .frame(minWidth: Theme.Size.touch + Theme.Space.regular, alignment: .leading)
                // 没有行数上限：放不下就换行（canWrap：审计在大字号下量不准，见 AppAudit）
                Text(Show.spaced(text)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("canWrap")
            }
            .frame(minHeight: Theme.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        do throws(APIError) {
            page = try await model.client.moneyThing(id)
            problem = nil
        } catch {
            if page == nil { problem = error.message }
        }
    }
}
