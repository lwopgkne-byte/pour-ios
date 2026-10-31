public import SwiftUI

// 3.0 钱（docs/3.0/01-需求文档.md 3.2「钱的行」、06 交互细节 3.1–3.3）：种类标签、一行钱、圆按钮、预算条。
// 只管样子：金额由用的地方写好（遮住金额时是「¥•••」），点了做什么由用的地方接

/// 一笔钱是哪一种：等报销（蓝）、借出去（黄）、固定的（灰）、收入（绿）、人情（红）、回来的钱（绿）、整理中（灰，刚记的）
public enum MoneyKindTag: String, CaseIterable, Sendable {
    case reimburse, lend, fixed, income, renqing, returned, pending

    public var title: String {
        switch self {
        case .reimburse: "等报销"
        case .lend: "借出去"
        case .fixed: "固定的"
        case .income: "收入"
        case .renqing: "人情"
        case .returned: "回来的"
        case .pending: "整理中"
        }
    }

    var ink: Color {
        switch self {
        case .reimburse: Theme.Palette.accent
        case .lend: Theme.Palette.warnInk
        case .fixed, .pending: Theme.Palette.secondaryLabel
        case .income, .returned: Theme.Palette.good
        case .renqing: Theme.Palette.badInk
        }
    }

    var fill: Color {
        switch self {
        case .reimburse: Theme.Palette.remindFill
        case .lend: Theme.Palette.warnFill
        case .fixed, .pending: Theme.Palette.fill
        case .income, .returned: Theme.Palette.goodFill
        case .renqing: Theme.Palette.badFill
        }
    }
}

/// 种类的小标签
public struct MoneyKindTagView: View {
    let tag: MoneyKindTag

    public init(_ tag: MoneyKindTag) {
        self.tag = tag
    }

    public var body: some View {
        Text(tag.title).font(Theme.Typeface.caption).foregroundStyle(tag.ink)
            .padding(.horizontal, Theme.Space.snug)
            .padding(.vertical, Theme.Space.hairline)
            .background(tag.fill, in: Capsule())
            .fixedSize()
    }
}

/// 金额的颜色：平常的；等报销、借出去的灰（不算日常花的）；收入、回来的钱绿（写「+¥18,500」）
public enum AmountTone: Sendable {
    case normal, muted, income
}

/// 一行钱（06 交互细节 3.3）：左边领域图标，名字后面是种类标签，第二行时间 · 给谁，右边金额
public struct MoneyRowLabel<Icon: View>: View {
    let title: String
    let tags: [MoneyKindTag]
    let sub: String?
    let amount: String
    let tone: AmountTone
    let icon: Icon

    public init(
        _ title: String, tags: [MoneyKindTag] = [], sub: String? = nil, amount: String, tone: AmountTone = .normal,
        @ViewBuilder icon: () -> Icon
    ) {
        self.title = title
        self.tags = tags
        self.sub = sub
        self.amount = amount
        self.tone = tone
        self.icon = icon()
    }

    public var body: some View {
        HStack(spacing: Theme.Space.medium) {
            icon
            VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                HStack(spacing: Theme.Space.snug) {
                    Text(title).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label).lineLimit(2)
                    ForEach(tags, id: \.self) { MoneyKindTagView($0) }
                }
                if let sub {
                    Text(sub).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel).lineLimit(1)
                }
            }
            Spacer(minLength: Theme.Space.small)
            Text(amount).font(Theme.Typeface.dayNumber).monospacedDigit().foregroundStyle(color).fixedSize()
        }
        .padding(.vertical, Theme.Space.small)
        .frame(minHeight: Theme.Size.touch)
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch tone {
        case .normal: Theme.Palette.label
        case .muted: Theme.Palette.secondaryLabel
        case .income: Theme.Palette.good
        }
    }
}

/// 主页上的圆按钮（记一笔 · 每一笔 · 留意的 · 人情往来）：彩色的圆、白色图标、下面一行字；角上可以有一个数
public struct RoundAction: View {
    let title: String
    let symbol: String
    let color: Color
    let badge: Int?
    let action: () -> Void

    public init(_ title: String, symbol: String, color: Color, badge: Int? = nil, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.color = color
        self.badge = badge
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Space.snug) {
                Image(systemName: symbol).font(Theme.Typeface.quickIcon).foregroundStyle(Theme.Palette.onAccent)
                    .frame(width: Theme.Size.quickIcon, height: Theme.Size.quickIcon)
                    .background(color, in: Circle())
                    .overlay(alignment: .topTrailing) {
                        if let badge, badge > 0 {
                            Text("\(badge)").font(Theme.Typeface.caption).monospacedDigit()
                                .foregroundStyle(Theme.Palette.label)
                                .frame(minWidth: Theme.Size.badgeDot, minHeight: Theme.Size.badgeDot)
                                .padding(.horizontal, Theme.Space.tight)
                                .background(Theme.Palette.badgeFill, in: Capsule())
                                .offset(x: Theme.Space.tight, y: -Theme.Space.tight)
                        }
                    }
                Text(title).font(Theme.Typeface.footnoteMedium).foregroundStyle(Theme.Palette.label).lineLimit(1)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(Text(badge.map { $0 > 0 ? "\(title)，\($0) 件" : title } ?? title))
    }
}

/// 预算的一行（06 交互细节 3.1）：名字和「还能花 ¥64」，下面一根细条；超了写「超了 ¥36」用留意色（不用红）
public struct BudgetRow: View {
    let title: String
    let text: String
    let detail: String?
    let pct: Double
    let over: Bool

    public init(_ title: String, text: String, detail: String? = nil, pct: Double, over: Bool) {
        self.title = title
        self.text = text
        self.detail = detail
        self.pct = pct
        self.over = over
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.label).lineLimit(2)
                Spacer(minLength: Theme.Space.small)
                Text(text).font(Theme.Typeface.footnoteSemibold).monospacedDigit()
                    .foregroundStyle(over ? Theme.Palette.warnInk : Theme.Palette.label).fixedSize()
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.fill)
                    Capsule().fill(over ? Theme.Palette.warn : Theme.Palette.good)
                        .frame(width: max(Theme.Size.bar, proxy.size.width * min(1, max(0, pct))))
                }
            }
            .frame(height: Theme.Space.snug)
            .accessibilityHidden(true)
            if let detail {
                Text(detail).font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(
                    Theme.Palette.secondaryLabel)
            }
        }
        .padding(.vertical, Theme.Space.tight)
        .accessibilityElement(children: .combine)
    }
}

#Preview("钱的行、标签、圆按钮、预算") {
    VStack(alignment: .leading, spacing: Theme.Space.regular) {
        VStack(spacing: 0) {
            MoneyRowLabel("满月红包", tags: [.renqing], sub: "19:40 · 给老同学", amount: "¥800") {
                Circle().fill(Theme.Palette.fill).frame(width: Theme.Size.tile, height: Theme.Size.tile)
            }
            MoneyRowLabel("打车", tags: [.reimburse], sub: "22:40", amount: "¥58", tone: .muted) {
                Circle().fill(Theme.Palette.fill).frame(width: Theme.Size.tile, height: Theme.Size.tile)
            }
            MoneyRowLabel("工资", tags: [.income], sub: "10:00", amount: "+¥18,500", tone: .income) {
                Circle().fill(Theme.Palette.fill).frame(width: Theme.Size.tile, height: Theme.Size.tile)
            }
            MoneyRowLabel("午饭", tags: [.pending], amount: "¥25") {
                Circle().fill(Theme.Palette.fill).frame(width: Theme.Size.tile, height: Theme.Size.tile)
            }
        }
        .padding(.horizontal, Theme.Space.regular)
        .themeCard(padding: 0)
        HStack {
            ForEach(MoneyKindTag.allCases, id: \.self) { MoneyKindTagView($0) }
        }
        HStack {
            RoundAction("记一笔", symbol: "plus", color: Theme.Tile.amber) {}
            RoundAction("每一笔", symbol: "list.bullet", color: Theme.Tile.blue) {}
            RoundAction("留意的", symbol: "tray.full.fill", color: Theme.Tile.gold, badge: 3) {}
            RoundAction("人情往来", symbol: "gift.fill", color: Theme.Tile.red) {}
        }
        VStack {
            BudgetRow("每月外卖不超过 ¥300", text: "还能花 ¥64", detail: "已用 ¥236", pct: 0.79, over: false)
            BudgetRow("每周买咖啡不超过 ¥100", text: "超了 ¥36", pct: 1, over: true)
        }
        .themeCard()
    }
    .padding()
    .background(Theme.Palette.background)
}
