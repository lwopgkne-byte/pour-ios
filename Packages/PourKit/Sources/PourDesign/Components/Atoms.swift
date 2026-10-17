public import SwiftUI

// 原子组件（docs/ios/设计规范/08-组件.md「原子」）。每个组件处理全部状态，数值只用令牌。

// MARK: - 按钮

/// 按钮的种类
public enum PourButtonKind: Sendable {
    /// 一个页面最多一个：发送、「说第一句话」、保存
    case primary
    /// 主要旁边的另一个选择、追问的选项
    case secondary
    /// 低调的操作：「看全部」「再试一次」「撤销」
    case text
    /// 不可恢复的操作（只出现在面板和菜单里）
    case destructive
}

/// 设计规范的按钮样式。`isLoading` 时文字换成转圈、宽度不变、不能再点。
public struct PourButtonStyle: ButtonStyle {
    let kind: PourButtonKind
    let large: Bool
    let isLoading: Bool
    @Environment(\.isEnabled) private var isEnabled

    public init(_ kind: PourButtonKind, large: Bool = false, isLoading: Bool = false) {
        self.kind = kind
        self.large = large
        self.isLoading = isLoading
    }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        // 按钮的字可以换行（字调大时不截断，和系统按钮一样）；加载时字不画、但留着位置，转圈自己说「正在处理」
        Group {
            if isLoading {
                configuration.label.pourText(.headline).multilineTextAlignment(.center).hidden()
                    .overlay { ProgressView().tint(foreground.color).accessibilityLabel(Text("正在处理")) }
            } else {
                configuration.label.pourText(.headline).multilineTextAlignment(.center)
            }
        }
        .foregroundStyle(foreground.color)
        .padding(.horizontal, kind == .text ? 0 : 20)
        .frame(minHeight: height)
        .frame(minWidth: PourSize.minTap)
        .background { background(pressed: pressed) }
        .contentShape(Rectangle())
        .scaleEffect(pressed && kind != .text ? PourMotion.pressedScale : 1)
        .animation(.snappy(duration: PourMotion.instant), value: pressed)
        .allowsHitTesting(!isLoading)
    }

    private var height: CGFloat {
        switch kind {
        case .primary: large ? PourSize.buttonLarge : PourSize.buttonRegular
        default: PourSize.buttonRegular
        }
    }

    private var foreground: ColorToken {
        // 不能点时字仍然读得清（淡墨，约 6.9:1）：看得出是什么按钮，只是现在不能点（M1 改，规范 08）
        if !isEnabled { return PourColor.inkSecondary }
        switch kind {
        case .primary: return PourColor.onAction
        case .secondary, .text: return PourColor.ink
        case .destructive: return PourColor.ink
        }
    }

    @ViewBuilder
    private func background(pressed: Bool) -> some View {
        switch kind {
        case .primary:
            Capsule().fill(
                (isEnabled ? (pressed ? PourColor.actionPressed : PourColor.action) : PourColor.fillPressed).color)
        case .secondary:
            Capsule().fill((pressed ? PourColor.fillSelected : PourColor.actionSoft).color)
        case .text, .destructive:
            Capsule().fill(pressed ? PourColor.fillPressed.color : .clear)
        }
    }
}

/// 危险按钮的文字用系统红（只给不可恢复的操作）
public struct PourDestructiveLabel: View {
    let title: String
    public init(_ title: String) { self.title = title }
    public var body: some View { Text(title).foregroundStyle(PourColor.critical.color) }
}

/// 图标按钮：工具栏、卡片角上的操作。可点 44×44，必须有旁白名字。
public struct PourIconButton: View {
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
            Image(systemName: systemImage)
                .font(.system(PourIconSize.large))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(PourColor.ink.color)
                .frame(minWidth: PourSize.minTap, minHeight: PourSize.minTap)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

// MARK: - 胶囊标签

/// 信息标签：领域色点 + 名字，不能点
public struct PourInfoChip: View {
    let title: String
    let domain: PourDomain?

    public init(_ title: String, domain: PourDomain? = nil) {
        self.title = title
        self.domain = domain
    }

    public var body: some View {
        HStack(spacing: PourSpace.inline) {
            if let domain { PourDomainDot(domain) }
            Text(title).pourText(.meta).foregroundStyle(PourColor.ink.color)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: PourSize.chipInfo)
        .background(Capsule().fill(PourColor.surfaceSunken.color))
        .accessibilityElement(children: .combine)
    }
}

/// 筛选标签：点一下切换。看起来 32 高，可点 44。
public struct PourFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    public init(_ title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button {
            PourHaptic.selection.play()
            action()
        } label: {
            Text(title)
                .pourText(.meta)
                .fontWeight(.medium)
                .foregroundStyle((isSelected ? PourColor.onAction : PourColor.ink).color)
                .padding(.horizontal, 14)
                .frame(minHeight: PourSize.chipVisual)
                .background(Capsule().fill((isSelected ? PourColor.action : PourColor.actionSoft).color))
                .frame(minHeight: PourSize.minTap)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// AI 标识：AI 写的句子末尾的小胶囊（合规，也是诚实）。旁白读「AI 生成」。
public struct PourAIBadge: View {
    public init() {}
    public var body: some View {
        Text(verbatim: "AI")
            .pourText(.caption)
            .foregroundStyle(PourColor.inkSecondary.color)
            .padding(.horizontal, 5)
            .frame(minHeight: PourSize.aiBadge)
            .overlay(Capsule().strokeBorder(PourColor.lineStrong.color, lineWidth: 1))
            .accessibilityLabel(Text("AI 生成"))
    }
}

/// AI 写的一句话 + 末尾的 AI 标识。标识画成小图嵌在文字里，换行时跟着句子最后一个字走（不会卡在行中间）
public struct PourAIText: View {
    let text: String
    let style: PourTextStyle
    let color: ColorToken
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(_ text: String, style: PourTextStyle, color: ColorToken = PourColor.ink) {
        self.text = text
        self.style = style
        self.color = color
    }

    public var body: some View {
        Text("\(text) \(badge)")
            .pourText(style)
            .foregroundStyle(color.color)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(text)，AI 生成"))
    }

    @MainActor private var badge: Text {
        let renderer = ImageRenderer(
            content: PourAIBadge()
                .environment(\.colorScheme, colorScheme)
                .environment(\.dynamicTypeSize, dynamicTypeSize))
        renderer.scale = displayScale
        #if canImport(UIKit)
            if let image = renderer.uiImage {
                return Text(Image(uiImage: image)).baselineOffset(-2)
            }
        #elseif canImport(AppKit)
            if let image = renderer.nsImage {
                return Text(Image(nsImage: image)).baselineOffset(-2)
            }
        #endif
        return Text(verbatim: "AI")
    }
}

// MARK: - 头像、色点、心情格、进度条

/// 人的头像：名字里的一个字；称呼（儿子、妈妈）用人形符号。不用随机色。
public struct PourAvatar: View {
    let name: String
    let size: CGFloat

    public init(_ name: String, size: CGFloat = PourSize.avatarList) {
        self.name = name
        self.size = size
    }

    /// 「小王」「老李」「阿芳」去掉前缀取后面的字；称呼类不取字
    static func initial(of name: String) -> String? {
        let titles = ["儿子", "女儿", "妈妈", "爸爸", "老婆", "老公", "爷爷", "奶奶", "外公", "外婆", "领导", "同事", "朋友"]
        if titles.contains(name) { return nil }
        var trimmed = Substring(name)
        if let first = trimmed.first, ["小", "老", "阿"].contains(first), trimmed.count > 1 {
            trimmed = trimmed.dropFirst()
        }
        return trimmed.first.map(String.init)
    }

    public var body: some View {
        ZStack {
            Circle().fill(PourColor.surfaceSunken.color)
            if let initial = Self.initial(of: name) {
                Text(initial).font(.system(size: size * 0.45, weight: .semibold))
            } else {
                Image(systemName: "person.fill").font(.system(size: size * 0.45))
            }
        }
        .foregroundStyle(PourColor.inkSecondary.color)
        .frame(width: size, height: size)
        .accessibilityLabel(Text(name))
    }
}

/// 领域色点（数据里才用）；旁边永远有名字，所以色点本身不读
public struct PourDomainDot: View {
    let domain: PourDomain
    let size: CGFloat

    public init(_ domain: PourDomain, size: CGFloat = PourSize.domainDot) {
        self.domain = domain
        self.size = size
    }

    public var body: some View {
        Circle().fill(domain.solid.color).frame(width: size, height: size).accessibilityHidden(true)
    }
}

/// 心情格：有心情填五档色；没记画虚线空格（两者一眼分开，不只靠颜色）
public struct PourMoodCell: View {
    let level: Int?
    let size: CGFloat

    public init(level: Int?, size: CGFloat = PourSize.moodPixel) {
        self.level = level
        self.size = size
    }

    public var body: some View {
        Group {
            if let level {
                RoundedRectangle.pour(PourRadius.xs).fill(PourColor.mood(level).color)
            } else {
                RoundedRectangle.pour(PourRadius.xs)
                    .strokeBorder(PourColor.lineStrong.color, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            }
        }
        .frame(width: size, height: size)
    }
}

/// 进度条：填充用目标所在领域的实色；落后时进度条不变色，右侧用琥珀色文字说
public struct PourProgressBar: View {
    let fraction: Double
    let domain: PourDomain

    public init(_ fraction: Double, domain: PourDomain) {
        self.fraction = min(max(fraction, 0), 1)
        self.domain = domain
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(PourColor.fillSelected.color)
                Capsule().fill(domain.solid.color).frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: PourSize.progressBar)
        .accessibilityElement()
        .accessibilityValue(Text("\(Int((fraction * 100).rounded()))%"))
    }
}

// MARK: - 卡片容器

/// 卡片：亮色白底无描边无阴影；暗色加 1 点 `line` 描边（暗色卡和底差得少）
public struct PourCard<Content: View>: View {
    let padding: CGFloat
    let background: ColorToken
    let content: Content
    @Environment(\.colorScheme) private var colorScheme

    public init(
        padding: CGFloat = PourSpace.card, background: ColorToken = PourColor.surface,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.background = background
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle.pour(PourRadius.lg).fill(background.color))
            .overlay {
                if colorScheme == .dark {
                    RoundedRectangle.pour(PourRadius.lg).strokeBorder(PourColor.line.color, lineWidth: 1)
                }
            }
    }
}

extension Text {
    /// 「事情 · 和儿子」拼成一段字（换行时一起走）：认出的人用青色（规范 01：青只表示「它懂你」）
    public init(_ base: String, person: String?, joiner: String = " · 和") {
        var text = AttributedString(base)
        if let person {
            var name = AttributedString(person)
            name.foregroundColor = PourColor.qing.color
            text += AttributedString(joiner) + name
        }
        self.init(text)
    }
}
