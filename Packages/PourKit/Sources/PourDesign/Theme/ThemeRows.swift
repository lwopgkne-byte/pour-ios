public import SwiftUI

// 3.0 组件库（docs/3.0/01-需求文档.md 3.2、07 开发任务清单 1.2）：先做进组件库、每个状态都有预览，再用到页面。
// 待办行、钱的行、发现卡、图表卡跟着第 2、3、4、8 步那一块一起做（要看真的数据长什么样）

/// 分组列表行（设置、留意的、每一笔）：左边彩色小图标、标题、下面一句、右边的值、箭头或开关；
/// 状态：默认、按下（PressScale）、不能点、正在做、有角标
public struct ThemeListRow<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let symbol: String?
    let color: Color
    let value: String?
    let badge: String?
    let chevron: Bool
    let loading: Bool
    @ViewBuilder let trailing: () -> Trailing

    public init(
        _ title: String, subtitle: String? = nil, symbol: String? = nil, color: Color = Theme.Palette.accentFill,
        value: String? = nil, badge: String? = nil, chevron: Bool = true, loading: Bool = false,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.color = color
        self.value = value
        self.badge = badge
        self.chevron = chevron
        self.loading = loading
        self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: Theme.Space.medium) {
            if let symbol {
                Image(systemName: symbol).font(Theme.Typeface.footnoteSemibold)
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
                    .foregroundStyle(Theme.Palette.onAccent)
                    .frame(width: Theme.Size.tile, height: Theme.Size.tile)
                    .background(color, in: Theme.rounded(Theme.Corner.tile))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                Text(title).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                if let subtitle {
                    Text(subtitle).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                }
            }
            Spacer(minLength: Theme.Space.small)
            if let badge { HubBadge(badge) }
            if loading {
                ProgressView().controlSize(.small)
            } else if let value {
                Text(value).font(Theme.Typeface.subheadline).monospacedDigit()
                    .foregroundStyle(Theme.Palette.secondaryLabel)
            }
            trailing()
            if chevron {
                Image(systemName: "chevron.right").font(Theme.Typeface.glyph)
                    .foregroundStyle(Theme.Palette.tertiaryLabel).accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Theme.Space.regular)
        .padding(.vertical, Theme.Space.small)
        .frame(minHeight: Theme.Size.touch + Theme.Space.small)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// 一两个字的按钮（「重试」「撤销」「回到今天」）：字小，能点的范围撑到 44 点。
/// 撑在按钮里面才算数——在按钮外面加 frame 只是占了地方，点得到的还是那几个字（2026-10-31 审计查出来的）
public struct ThemeTextButton: View {
    let title: String
    let font: Font
    let action: () -> Void

    public init(_ title: String, font: Font = Theme.Typeface.footnoteSemibold, action: @escaping () -> Void) {
        self.title = title
        self.font = font
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title).font(font).foregroundStyle(Theme.Palette.accent)
                .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 原话块：宋体、左边一条细线（只有原话、语录用宋体）；能高亮其中一段，太长时收起、点了展开
public struct QuoteBlock: View {
    let text: String
    let highlight: String?
    let lineLimit: Int?
    @State private var expanded = false

    public init(_ text: String, highlight: String? = nil, lineLimit: Int? = 3) {
        self.text = text
        self.highlight = highlight
        self.lineLimit = lineLimit
    }

    public var body: some View {
        Button {
            withAnimation(Theme.Motion.standard) { expanded.toggle() }
        } label: {
            Text(attributed)
                .font(Theme.Typeface.quote).foregroundStyle(Theme.Palette.label)
                .lineSpacing(Theme.Leading.quote)
                .lineLimit(expanded ? nil : lineLimit)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, Theme.Space.medium)
                .overlay(alignment: .leading) {
                    Capsule().fill(Theme.Palette.separator).frame(width: Theme.Space.hairline)
                }
        }
        .buttonStyle(.plain)
        .disabled(lineLimit == nil)
        .accessibilityHint(Text(lineLimit == nil ? "" : expanded ? "收起" : "展开全文"))
    }

    private var attributed: AttributedString {
        var value = AttributedString(text)
        if let highlight, !highlight.isEmpty, let range = value.range(of: highlight) {
            value[range].backgroundColor = Theme.Palette.bubble
        }
        return value
    }
}

/// 指标块：大数 + 名称 + 和上次比（「比上周多 3」）；没有数时不出现（调用的地方不画）；遮住金额时写 •••
public struct MetricBlock: View {
    let value: String
    let unit: String?
    let name: String
    let change: String?
    let masked: Bool

    public init(_ value: String, unit: String? = nil, name: String, change: String? = nil, masked: Bool = false) {
        self.value = value
        self.unit = unit
        self.name = name
        self.change = change
        self.masked = masked
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.hairline) {
                Text(masked ? "•••" : value).font(Theme.Typeface.metric).foregroundStyle(Theme.Palette.label)
                    .contentTransition(.numericText())
                if let unit, !masked {
                    Text(unit).font(Theme.Typeface.unit).foregroundStyle(Theme.Palette.secondaryLabel)
                }
            }
            Text(name).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            if let change, !masked {
                Text(change).font(Theme.Typeface.footnoteMedium).foregroundStyle(Theme.Palette.secondaryLabel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// 筛选胶囊（每一笔、笔记库、感悟）：选中是蓝底白字，没选是浅灰底；可以带一个数
public struct FilterChip: View {
    let title: String
    let count: Int?
    let selected: Bool
    let action: () -> Void

    public init(_ title: String, count: Int? = nil, selected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.count = count
        self.selected = selected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.tight) {
                Text(title).font(Theme.Typeface.footnoteSemibold)
                if let count { Text("\(count)").font(Theme.Typeface.footnote).monospacedDigit().opacity(0.8) }
            }
            .foregroundStyle(selected ? Theme.Palette.onAccent : Theme.Palette.label)
            .padding(.horizontal, Theme.Space.medium)
            .frame(minHeight: Theme.Size.capsule)
            .background(selected ? Theme.Palette.accentFill : Theme.Palette.fill, in: Capsule())
            .frame(minHeight: Theme.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .themeSelectionFeedback(trigger: selected)
    }
}

/// 空状态：一句话 + 一个示例按钮（「试试说：午饭 25」）
public struct EmptyState: View {
    let message: String
    let example: String?
    let action: (() -> Void)?

    public init(_ message: String, example: String? = nil, action: (() -> Void)? = nil) {
        self.message = message
        self.example = example
        self.action = action
    }

    public var body: some View {
        VStack(spacing: Theme.Space.medium) {
            Text(message).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel)
                .multilineTextAlignment(.center)
            if let example, let action {
                Button(example, action: action)
                    .font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.accent)
                    .buttonStyle(.plain).frame(minHeight: Theme.Size.touch)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.section)
    }
}

/// 出错：大白话 +「再试一次」。不出现「服务器的回复」「数据丢失」这类词（01 需求文档 3.3）
public struct ErrorState: View {
    public enum Kind: Sendable {
        /// 没网、电脑上的 Pour 没开、App 太旧要更新、别的
        case offline, serverOff, tooOld, other
    }

    let kind: Kind
    let retry: () -> Void

    public init(_ kind: Kind, retry: @escaping () -> Void) {
        self.kind = kind
        self.retry = retry
    }

    public var body: some View {
        VStack(spacing: Theme.Space.medium) {
            Image(systemName: symbol).font(Theme.Typeface.section).foregroundStyle(Theme.Palette.tertiaryLabel)
                .accessibilityHidden(true)
            Text(message).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                .multilineTextAlignment(.center)
            if kind != .tooOld {
                Button("再试一次", action: retry)
                    .font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.accent)
                    .buttonStyle(.plain).frame(minHeight: Theme.Size.touch)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.section)
    }

    private var symbol: String {
        switch kind {
        case .offline: "wifi.slash"
        case .serverOff: "desktopcomputer"
        case .tooOld: "arrow.down.app"
        case .other: "exclamationmark.circle"
        }
    }

    private var message: String {
        switch kind {
        case .offline: "没连上网。连上了会自动刷新。"
        case .serverOff: "没连上电脑上的 Pour。家里的 WiFi 连着吗？电脑开着吗？"
        case .tooOld: "这个 App 太旧了，装一下新的再看。"
        case .other: "这一页暂时打不开，已经记下了，我们会修。"
        }
    }
}

/// 轻提示：一句话，右边可以有一个操作（「撤销」），4 秒后自己消失（AppModel 管时间）
public struct ThemeToast: View {
    let message: String
    let action: String?
    let perform: () -> Void

    public init(_ message: String, action: String? = nil, perform: @escaping () -> Void = {}) {
        self.message = message
        self.action = action
        self.perform = perform
    }

    public var body: some View {
        HStack(spacing: Theme.Space.medium) {
            Text(message).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.label)
            if let action {
                Button(action, action: perform).font(Theme.Typeface.cardTitle).foregroundStyle(Theme.Palette.accent)
                    .buttonStyle(.plain).frame(minHeight: Theme.Size.touch)
                    .accessibilityIdentifier("undoToast")
            }
        }
        .padding(.horizontal, Theme.Space.regular)
        .frame(minHeight: Theme.Size.touch)
        .themeGlass(radius: Theme.Corner.composer)
    }
}

/// 弹层头部：中间的名字，右边关闭（拖动条用系统的 presentationDragIndicator）
public struct SheetHeader: View {
    let title: String
    let close: () -> Void

    public init(_ title: String, close: @escaping () -> Void) {
        self.title = title
        self.close = close
    }

    public var body: some View {
        ZStack {
            Text(title).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark").font(Theme.Typeface.footnoteSemibold)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                        .frame(width: Theme.Size.capsule, height: Theme.Size.capsule)
                        .background(Theme.Palette.fill, in: Circle())
                        .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("关闭"))
            }
        }
        .padding(.horizontal, Theme.Space.small)
        .padding(.top, Theme.Space.small)
    }
}

#Preview("列表行、原话、指标") {
    ScrollView {
        VStack(spacing: Theme.Space.cardGap) {
            VStack(spacing: 0) {
                ThemeListRow("提醒和通知", subtitle: "早上 8 点 · 晚上 10 点", symbol: Theme.Symbol.notifications)
                ThemeListRow("留意的", symbol: Theme.Symbol.watch, color: Theme.Tile.orange, badge: "2")
                ThemeListRow("大模型", symbol: Theme.Symbol.model, value: "DeepSeek")
                ThemeListRow("正在导出", symbol: Theme.Symbol.data, chevron: false, loading: true)
                ThemeListRow("预警", symbol: Theme.Symbol.remind, chevron: false) { Toggle("", isOn: .constant(true)) }
            }
            .themeCard(padding: 0)
            QuoteBlock("中午和小王吃了碗牛肉面，二十六，聊了下周的方案，他说要先把会员改版的 PRD 定下来再说。", highlight: "牛肉面，二十六")
                .themeCard()
            HStack {
                MetricBlock("4,066", unit: "元", name: "这个月日常", change: "比上个月同期少 ¥312")
                MetricBlock("8,412", unit: "步", name: "平均每天", change: "比上周多 1,200")
                MetricBlock("4,066", name: "遮住了", masked: true)
            }
            .themeCard()
        }
        .padding()
    }
    .background(Theme.Palette.background)
}

#Preview("胶囊、空、出错、轻提示、弹层头") {
    VStack(spacing: Theme.Space.cardGap) {
        HStack {
            FilterChip("全部", count: 48, selected: true) {}
            FilterChip("饮食", count: 21, selected: false) {}
            FilterChip("固定的", selected: false) {}
        }
        EmptyState("这个月还没记钱。", example: "试试说：午饭 25") {}.themeCard()
        ErrorState(.serverOff) {}.themeCard()
        ThemeToast("已删除", action: "撤销")
        SheetHeader("记一笔") {}.themeCard(padding: 0)
    }
    .padding()
    .background(Theme.Palette.background)
}
