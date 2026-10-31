public import SwiftUI

/// 类别图标：28 点圆角小方块，底是类别色的浅色；预置的类别用苹果的线条图标，AI 新长出来的类别用它自己的 emoji
public struct IconTile: View {
    @ScaledMetric(relativeTo: .subheadline) private var size = Theme.Size.tile
    let symbol: String?
    let emoji: String
    let color: Theme.TagColor

    public init(symbol: String?, emoji: String, color: Theme.TagColor) {
        self.symbol = symbol
        self.emoji = emoji
        self.color = color
    }

    public var body: some View {
        Group {
            if let symbol {
                Image(systemName: symbol).font(.system(size: size * 0.54, weight: .semibold))
                    .foregroundStyle(color.solid)
            } else {
                Text(emoji).font(.system(size: size * 0.58))
            }
        }
        .frame(width: size, height: size)
        .background(color.tint, in: Theme.rounded(Theme.Corner.tile * size / Theme.Size.tile))
        .accessibilityHidden(true)
    }
}

/// 一个数和它的单位：「6 小时 50 分」「¥383」「129/85」——数字用圆体大字，单位小一号、次要色
public struct FigureText: View {
    public typealias Part = (number: String, unit: String)

    let parts: [Part]
    let prefix: String?
    let numberFont: Font
    let unitFont: Font
    let unitColor: Color

    /// `unitColor`：放在心情底色上时（今天的样子）单位也用主字色，次要色在那里对比度不稳
    public init(
        _ parts: [Part], prefix: String? = nil,
        numberFont: Font = Theme.Typeface.metric, unitFont: Font = Theme.Typeface.unit,
        unitColor: Color = Theme.Palette.secondaryLabel
    ) {
        self.parts = parts
        self.prefix = prefix
        self.numberFont = numberFont
        self.unitFont = unitFont
        self.unitColor = unitColor
    }

    public var body: some View {
        text.monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            .contentTransition(.numericText())
            .animation(Theme.Motion.standard, value: parts.map { "\($0.number)\($0.unit)" })
    }

    private var text: Text {
        var out = Text(verbatim: "")
        if let prefix {
            out = Text("\(out)\(Text(verbatim: prefix).font(unitFont).foregroundStyle(unitColor))")
        }
        for (index, part) in parts.enumerated() {
            let number = Text(verbatim: part.number).font(numberFont).foregroundStyle(Theme.Palette.label)
            out = Text("\(out)\(number)")
            if !part.unit.isEmpty {
                let unit = index < parts.count - 1 ? " \(part.unit) " : " \(part.unit)"
                out = Text("\(out)\(Text(verbatim: unit).font(unitFont).foregroundStyle(unitColor))")
            }
        }
        return out
    }
}

/// 小标签：「等报销」「给宝宝」「确认一下」——胶囊、浅底
public struct ThemeBadge: View {
    let text: String
    let tone: Tone

    public enum Tone: Sendable {
        case neutral, accent, good, warn, bad
    }

    public init(_ text: String, tone: Tone = .neutral) {
        self.text = text
        self.tone = tone
    }

    public var body: some View {
        Text(text).font(Theme.Typeface.caption).foregroundStyle(foreground)
            .padding(.horizontal, Theme.Space.small).frame(minHeight: Theme.Size.badge)
            // 不能点的小标签用小圆角；胶囊留给能点的（设计评审 2026-10-23：不要什么都做成胶囊）
            .background(background, in: Theme.rounded(Theme.Corner.tile))
    }

    private var foreground: Color {
        switch tone {
        case .neutral: Theme.Palette.secondaryLabel
        case .accent: Theme.Palette.accent
        case .good: Theme.Palette.good
        case .warn: Theme.Palette.warn
        case .bad: Theme.Palette.bad
        }
    }

    private var background: Color {
        tone == .neutral ? Theme.Palette.fill : foreground.opacity(0.1)
    }
}

/// 浮在内容上的玻璃圆按钮（顶上的菜单、日历、搜索）：44 × 44
public struct GlassCircleButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    public init(_ systemImage: String, label: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            // 和系统的栏一样：按钮不随字号长大，图标封顶；字号很大的人长按看大图标
            Image(systemName: systemImage).font(Theme.Typeface.toolbarIcon)
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                .foregroundStyle(Theme.Palette.label)
                .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel(Text(label))
        .accessibilityShowsLargeContentViewer { Label(label, systemImage: systemImage) }
    }
}

/// 还在拿的时候：和最后的样子差不多大的灰块，慢慢明暗（减弱动态效果时不动）
public struct SkeletonBlock: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false
    let height: CGFloat
    let radius: CGFloat

    public init(height: CGFloat, radius: CGFloat = Theme.Corner.card) {
        self.height = height
        self.radius = radius
    }

    public var body: some View {
        Theme.rounded(radius).fill(Theme.Palette.fill)
            .frame(height: height)
            .opacity(dim ? 0.5 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(Theme.Motion.pulse) { dim = true }
            }
            .accessibilityLabel(Text("正在加载"))
    }
}

/// 按下去缩一点、松手弹回（卡片、能点的一块）；减弱动态效果时只变淡
public struct PressScale: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.7 : 1)
            .animation(Theme.Motion.quick, value: configuration.isPressed)
    }
}

/// 「我」的圆头像（3.0：画布左上角进全部功能、「我的」页头；docs/3.0/01-需求文档.md 2.1、2.3）：
/// 还没有头像时是蓝色圆里一个白色的「我」字。点的范围至少 44
public struct MeAvatar: View {
    let size: CGFloat

    public init(size: CGFloat = Theme.Size.touch) {
        self.size = size
    }

    public var body: some View {
        Text("我")
            .font(size > Theme.Size.touch ? Theme.Typeface.section : Theme.Typeface.bodySemibold)
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .foregroundStyle(Theme.Palette.onAccent)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [Theme.Palette.accentFill, Theme.Palette.accent], startPoint: .topLeading,
                    endPoint: .bottomTrailing),
                in: Circle()
            )
            .overlay(Circle().strokeBorder(Theme.Palette.card, lineWidth: Theme.Space.hairline))
            .accessibilityHidden(true)
    }
}

#Preview("我") {
    HStack(spacing: Theme.Space.regular) {
        MeAvatar()
        MeAvatar(size: Theme.Size.avatar)
    }
    .padding()
    .background(Theme.Palette.background)
}
