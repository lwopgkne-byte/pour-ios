import PourAPI
import PourDesign
import SwiftUI

/// 值不值（可交互原型「值不值」；「我的 → 钱 → 值不值」进来）：只听你自己说的——你说值的在前、你说后悔的在后，
/// 一样一张卡（MoneyWorthCard）。数据和钱主页那一块一样（/api/money/overview 的 worth）
struct MoneyWorthPage: View {
    @Environment(AppModel.self) private var model
    @State private var worth: API.MoneyWorth?
    @State private var problem: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.small + Theme.Space.hairline) {
                Text("只听你自己说的。「用了几次」是你之后说到用它的次数，没说的不算。")
                    .font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.Space.tight).padding(.bottom, Theme.Space.tight)
                if let worth {
                    if worth.good.isEmpty, worth.regret.isEmpty {
                        Text("买东西的时候顺口说一句值不值（「这耳机买得值」「有点后悔」），这里就会有。")
                            .font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .themeCard(radius: Theme.Corner.smallCard)
                    }
                    ForEach(worth.good, id: \.entryId) { MoneyWorthCard(thing: $0, good: true) }
                    ForEach(worth.regret, id: \.entryId) { MoneyWorthCard(thing: $0, good: false) }
                } else if let problem {
                    ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Theme.Space.section)
                }
            }
            .padding(.horizontal, Theme.Space.screen)
            .padding(.bottom, Theme.Space.section)
        }
        .background(Theme.Palette.background)
        .refreshable { await load() }
        .task(id: model.dataVersion) { await load() }
    }

    private func load() async {
        // 先出上次存的（不出现整页转圈）
        if worth == nil, let saved: API.MoneyOverview = model.client.cached("/api/money/overview") {
            worth = saved.worth
        }
        do throws(APIError) {
            worth = try await model.client.moneyOverview().worth
            problem = nil
        } catch {
            if worth == nil { problem = error.message }
        }
    }
}

/// 值不值的一张卡（原型 .card.worth）：东西和价钱一行、你说的那句（宋体）、
/// 「你说值 · 用了 5 次 · 每次 ¥180」（值是绿字、后悔是琥珀字）；点了进那样东西。
/// 钱主页横着滑的那一排（固定 236 宽）和「值不值」页（铺满）都用它
struct MoneyWorthCard: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    let thing: API.MoneyThing
    let good: Bool
    /// 横着滑时的宽（nil 是铺满）
    var width: CGFloat?

    /// 原型 .worth 的宽
    static let stripWidth: CGFloat = 236

    var body: some View {
        Button {
            model.open("/money/thing/\(thing.entryId)")
        } label: {
            VStack(alignment: .leading, spacing: Theme.Space.small + Theme.Space.hairline) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.small) {
                    Text(Show.spaced(thing.name)).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(Show.yuan(thing.amount, hide: hide)).font(Theme.Typeface.rowNumber).monospacedDigit()
                        .foregroundStyle(Theme.Palette.label)
                }
                if let quote = thing.verdict?.quote, !quote.isEmpty {
                    Text("「\(quote)」").font(Theme.Typeface.quote).foregroundStyle(Theme.Palette.label)
                        .lineSpacing(Theme.Leading.body).lineLimit(width == nil ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(Show.maskYuan(Show.worthLine(thing, good: good), hide: hide)).font(Theme.Typeface.footnoteSemibold)
                    .foregroundStyle(good ? Theme.Palette.good : Theme.Palette.warnInk)
                    .lineLimit(width == nil ? nil : 1)
            }
            .frame(width: width.map { $0 - Theme.Space.regular * 2 }, alignment: .leading)
            // 横着一排时一样高（高的那张定）
            .frame(maxWidth: width == nil ? .infinity : nil, maxHeight: .infinity, alignment: .topLeading)
            .themeCard(radius: Theme.Corner.smallCard)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("看这样东西"))
    }
}
