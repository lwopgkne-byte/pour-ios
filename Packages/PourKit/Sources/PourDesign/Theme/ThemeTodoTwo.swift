public import SwiftUI

// 待办 2.0（pour-ios 的 docs/todo-2.0，设计稿 design/、颜色 tokens/）：四象限的颜色和圈、一行的样子（行高 52、圈 24、
// 点的范围 44、标题一行、右边只放时间或状态）、右边的几种时间状态、三段的切换、行下面的小按钮。只管样子，
// 点了做什么由用它的地方接（待办页、四象限、时间线、画布的待办卡）。象限用数字：0 还没分、1 马上做、2 排时间、3 快速办、4 放一放

extension Theme {
    /// 四象限的颜色（设计稿 tokens：圈和图标、底色、文字）。为了看得清和设计稿差一点点的（ThemeColorTests 量）：
    /// 象限的字都深一点点（小字按画出来的样子 ≥ 4.5）；放一放的圈 #8F8A82 → #8A857D（小云在浅灰底上到 3:1）
    public enum Quadrant {
        static let rings: [UInt32] = [0x77736B, 0xCF3D24, 0xC27C00, 0x1B93A9, 0x8A857D]
        static let tints: [UInt32] = [0xFFFFFF, 0xFCEBE7, 0xFBF1DB, 0xE1F1F4, 0xEFEEEA]
        static let texts: [UInt32] = [0x4F4B45, 0xAC2913, 0x7E4D00, 0x025F71, 0x58544D]
        static let symbols: [String?] = [nil, "flame.fill", "star.fill", "bolt.fill", "cloud.fill"]

        static func index(_ quadrant: Int) -> Int { min(4, max(0, quadrant)) }
        public static func ringToken(_ quadrant: Int) -> ColorToken { Tokens.one(rings[index(quadrant)]) }
        public static func tintToken(_ quadrant: Int) -> ColorToken { Tokens.one(tints[index(quadrant)]) }
        public static func textToken(_ quadrant: Int) -> ColorToken { Tokens.one(texts[index(quadrant)]) }
        /// 圈的描边、圈里的小图标
        public static func ring(_ quadrant: Int) -> Color { ringToken(quadrant).color }
        /// 圈里的底、四象限格子的底
        public static func tint(_ quadrant: Int) -> Color { tintToken(quadrant).color }
        /// 象限的名字（在底色上、白底上都 ≥ 4.5）
        public static func text(_ quadrant: Int) -> Color { textToken(quadrant).color }
        public static func symbol(_ quadrant: Int) -> String? { symbols[index(quadrant)] }
        /// 勾掉以后的圈：实心深灰 + 白色对勾
        public static let doneToken = Tokens.one(0x66625A)
        public static let done = doneToken.color
    }

    /// 日程（设计稿：日历图标、浅蓝底、字）：日历图标、时间线上的日程块
    public enum Agenda {
        public static let iconToken = Tokens.one(0x3C6BD8)
        public static let fillToken = Tokens.one(0xE7EDF9)
        public static let inkToken = Tokens.one(0x2C51A4)
        public static let icon = iconToken.color
        public static let fill = fillToken.color
        public static let ink = inkToken.color
    }
}

/// 看得见的象限圈（24）：马上做、排时间、快速办是 2pt 描边 + 底色 + 圈里一个实心小图标；放一放是虚线圈 + 小云；
/// 还没分是空心圈。四象限的小卡、长按菜单、结果卡上的小标签也用它（只看，不能点）
public struct QuadrantBadge: View {
    let quadrant: Int
    let size: CGFloat

    public init(quadrant: Int, size: CGFloat = Theme.Size.check) {
        self.quadrant = quadrant
        self.size = size
    }

    public var body: some View {
        let lane = Theme.Quadrant.index(quadrant)
        ZStack {
            switch lane {
            case 0:
                Circle().fill(Theme.Palette.card)
                    .overlay(Circle().strokeBorder(Theme.Quadrant.ring(0), lineWidth: 1.6))
            case 4:
                Circle().fill(Theme.Quadrant.tint(4))
                    .overlay(
                        Circle().strokeBorder(
                            Theme.Quadrant.ring(4), style: StrokeStyle(lineWidth: 1.6, dash: [2.6, 2.2])))
            default:
                Circle().fill(Theme.Quadrant.tint(lane))
                    .overlay(Circle().strokeBorder(Theme.Quadrant.ring(lane), lineWidth: 2))
            }
            if let symbol = Theme.Quadrant.symbol(lane) {
                Image(systemName: symbol).font(.system(size: size * 0.46, weight: .bold))
                    .foregroundStyle(Theme.Quadrant.ring(lane))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 待办的圈（点的范围 44×44，看得见的 24，照象限画）：点了勾上——深灰实心 + 白色对勾弹出来，轻轻一震；
/// 划线、变淡、留在原地由行管。「减少动态效果」时只渐变
public struct QuadrantRing: View {
    let quadrant: Int
    let done: Bool
    let label: String
    let toggle: () -> Void

    public init(quadrant: Int, done: Bool, label: String, toggle: @escaping () -> Void) {
        self.quadrant = quadrant
        self.done = done
        self.label = label
        self.toggle = toggle
    }

    public var body: some View {
        Button(action: toggle) {
            ZStack {
                if done {
                    Circle().fill(Theme.Quadrant.done)
                    Image(systemName: Theme.Symbol.done).font(Theme.Typeface.glyph).fontWeight(.bold)
                        .foregroundStyle(Theme.Palette.onAccent)
                        .themeTransition(.scale.combined(with: .opacity))
                } else {
                    QuadrantBadge(quadrant: quadrant)
                }
            }
            .frame(width: Theme.Size.check, height: Theme.Size.check)
            .frame(width: Theme.Size.touch, height: Theme.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(Theme.Motion.spring, value: done)
        .todoDoneFeedback(done)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(done ? "已完成" : "未完成"))
        .accessibilityHint(Text(done ? "改成没完成" : "完成"))
        .accessibilityIdentifier("todo.check")
    }
}

/// 一行右边的时间或状态（15 号）：铃铛 + 12:30（到点响）、「下午」（时间段）、半小时内变蓝「12:30 · 8 分钟后」、
/// 过了是沙色胶囊「11:12 过了」、和日程撞了是沙色胶囊「撞上面试」、只写日子「明天」「10月30日」；不定时右边留空（不用这个）
public struct TodoTrailing: View {
    public enum Kind: Hashable, Sendable {
        case clock(String)
        case window(String)
        case soon(String)
        case late(String)
        case clash(String)
        case day(String)

        /// 写着的字（读屏也念它）
        public var text: String {
            switch self {
            case .clock(let text), .window(let text), .soon(let text), .late(let text), .clash(let text),
                .day(let text):
                text
            }
        }
    }

    let kind: Kind
    /// 不带底色（四象限的小卡第二行：「⏱ 11:12 过了」沙色字）
    let plain: Bool
    /// 窄的地方（四象限的小卡、时间线的小标签）：快到了只写钟点（不写「· 3 分钟后」），放不下就省略，不撑宽
    let compact: Bool

    public init(_ kind: Kind, plain: Bool = false, compact: Bool = false) {
        self.kind = kind
        self.plain = plain
        self.compact = compact
    }

    public var body: some View {
        Group {
            switch kind {
            case .clock(let text):
                HStack(spacing: Theme.Space.hairline + 1) {
                    Image(systemName: "bell").font(Theme.Typeface.footnote)
                    Text(text)
                }
                .font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
            case .window(let text), .day(let text):
                Text(text).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
            case .soon(let text):
                HStack(spacing: Theme.Space.hairline + 1) {
                    Image(systemName: "bell.fill").font(Theme.Typeface.footnote)
                    Text(compact ? String(text.split(separator: " · ").first ?? Substring(text)) : text)
                }
                // 蓝色已经够显眼，字不再加粗（产品主人 2026-11-06：两行加粗的蓝字太吵）
                .font(Theme.Typeface.subheadline.weight(.medium)).foregroundStyle(Theme.Palette.accent)
            case .late(let text): sand(text, symbol: "clock")
            case .clash(let text): sand(text, symbol: "exclamationmark.triangle")
            }
        }
        .monospacedDigit().lineLimit(1).fixedSize(horizontal: !compact, vertical: false)
    }

    @ViewBuilder private func sand(_ text: String, symbol: String) -> some View {
        if plain {
            HStack(spacing: Theme.Space.hairline + 1) {
                Image(systemName: symbol).font(Theme.Typeface.caption)
                Text(text).font(Theme.Typeface.footnoteSemibold)
            }
            .foregroundStyle(Theme.Palette.warnInk)
        } else {
            SandPill(text, symbol: symbol)
        }
    }
}

/// 沙色胶囊（过点了、和日程撞了；不用红色）
public struct SandPill: View {
    let text: String
    let symbol: String

    public init(_ text: String, symbol: String) {
        self.text = text
        self.symbol = symbol
    }

    public var body: some View {
        HStack(spacing: Theme.Space.hairline + 1) {
            Image(systemName: symbol).font(Theme.Typeface.caption)
            Text(text).font(Theme.Typeface.footnoteSemibold)
        }
        .foregroundStyle(Theme.Palette.warnInk)
        .padding(.horizontal, Theme.Space.small).frame(minHeight: Theme.Size.badge + Theme.Space.tight)
        .background(Theme.Palette.warnFill, in: Capsule())
        .fixedSize()
    }
}

/// 一行待办（所有列表通用）：左边圈（看得见的左边距 16）、圈到标题 14、标题 17 号只占一行（长了省略）、右边时间或状态。
/// 行高 52；勾掉的划线、变淡；放一放的标题用次文字色；分割线从标题左边开始（List 里）。
/// 给了 open：圈以外整行是一个按钮（点了打开详情；读屏念 spoken、界面测试认 identifier）
public struct TodoLine<Ring: View, Trailing: View>: View {
    let title: String
    let done: Bool
    let dim: Bool
    let spoken: String?
    let identifier: String
    let open: (() -> Void)?
    let ring: Ring
    let trailing: Trailing

    public init(
        _ title: String, done: Bool, dim: Bool = false, spoken: String? = nil, identifier: String = "todo.row",
        open: (() -> Void)? = nil, @ViewBuilder ring: () -> Ring, @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.done = done
        self.dim = dim
        self.spoken = spoken
        self.identifier = identifier
        self.open = open
        self.ring = ring()
        self.trailing = trailing()
    }

    /// 圈的点按区比看得见的大 10：往左挪 10，看得见的圈离边 16
    static var ringInset: CGFloat { (Theme.Size.touch - Theme.Size.check) / 2 }
    public static var rowHeight: CGFloat { 52 }

    public var body: some View {
        HStack(spacing: Theme.Space.medium + Theme.Space.hairline - Self.ringInset) {
            ring
            if let open {
                Button(action: open) { words }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(spoken ?? title))
                    .accessibilityHint(Text("打开详情"))
                    .accessibilityIdentifier(identifier)
            } else {
                words
            }
        }
        .padding(.leading, Theme.Space.regular - Self.ringInset)
        .padding(.trailing, Theme.Space.regular)
        .frame(minHeight: Self.rowHeight)
        .animation(Theme.Motion.spring, value: done)
    }

    private var words: some View {
        HStack(spacing: Theme.Space.small) {
            Text(title).font(Theme.Typeface.body).lineLimit(1).truncationMode(.tail)
                .foregroundStyle(
                    done ? Theme.Palette.tertiaryLabel : dim ? Theme.Palette.secondaryLabel : Theme.Palette.label
                )
                .strikethrough(done, color: Theme.Palette.tertiaryLabel)
                .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
            Spacer(minLength: 0)
            if !done { trailing }
        }
        .frame(minHeight: Self.rowHeight)
        .contentShape(Rectangle())
    }
}

/// 三段的切换（清单 | 四象限 | 时间线）：高 38、圆角 12，选中的那段白底、轻阴影
public struct PillSegments<Value: Hashable>: View {
    @Binding var selection: Value
    let items: [(value: Value, title: String)]

    public init(selection: Binding<Value>, items: [(value: Value, title: String)]) {
        _selection = selection
        self.items = items
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.value) { item in
                let chosen = item.value == selection
                Button {
                    withAnimation(Theme.Motion.quick) { selection = item.value }
                } label: {
                    Text(item.title).font(chosen ? Theme.Typeface.bodySemibold : Theme.Typeface.body)
                        .foregroundStyle(chosen ? Theme.Palette.label : Theme.Palette.secondaryLabel)
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.segment - Theme.Space.tight)
                        .background {
                            if chosen {
                                Theme.rounded(Theme.Corner.segment - Theme.Space.hairline).fill(Theme.Palette.card)
                                    .shadow(color: Theme.Palette.shadowFar, radius: 2, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(chosen ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(Theme.Space.hairline)
        .frame(minHeight: Theme.Size.segment)
        .background(Theme.Palette.fill, in: Theme.rounded(Theme.Corner.segment))
        .themeSelectionFeedback(trigger: selection)
    }
}

/// 行下面的小按钮（「挪到下午」「明天再说」「不做了」）：灰底胶囊，看得见的 32 高，点的地方 44
public struct MiniChip: View {
    let title: String
    let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.label)
                .padding(.horizontal, Theme.Space.medium + Theme.Space.hairline)
                .frame(minHeight: Theme.Size.capsule)
                .background(Theme.Palette.fill, in: Capsule())
                .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
    }
}
