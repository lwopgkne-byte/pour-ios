public import SwiftUI

/// 网页版能点的一行、一张卡片（链接、列表行）：按下去底色变深一点（网页版 hover / active 的 bg-hover、bg-pressed）
public struct WebPressStyle: ButtonStyle {
    let radius: CGFloat

    public init(radius: CGFloat = Web.radiusCard) {
        self.radius = radius
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(RoundedRectangle(cornerRadius: radius).fill(configuration.isPressed ? Web.bgPressed : .clear))
            .contentShape(RoundedRectangle(cornerRadius: radius))
    }
}

/// 网页版的三个点（Dots）：正在整理、正在保存、加载中。三个小圆点轮流亮起，用文字的颜色；
/// 系统设了「减弱动态效果」就不动
public struct Dots: View {
    let label: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// label：读屏念的（旁边已经写了字就不用给，三个点读屏跳过）
    public init(label: String? = nil) {
        self.label = label
    }

    public var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: Web.space1) {
                ForEach(0..<3, id: \.self) { index in
                    Circle().frame(width: Web.space1, height: Web.space1)
                        .opacity(reduceMotion ? 1 : Self.opacity(time - Double(index) * Self.stagger))
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(label ?? ""))
        .accessibilityHidden(label == nil)
    }

    /// 一圈 1.2 秒，每个点晚 0.15 秒
    private static let period = 1.2
    private static let stagger = 0.15

    /// 网页版 @keyframes dot：0%、80%、100% 是 0.25，40% 是 1，中间缓入缓出
    static func opacity(_ time: Double) -> Double {
        let phase = (time / period).truncatingRemainder(dividingBy: 1)
        let step = phase < 0 ? phase + 1 : phase
        func ease(_ value: Double) -> Double { value * value * (3 - 2 * value) }
        if step < 0.4 { return 0.25 + 0.75 * ease(step / 0.4) }
        if step < 0.8 { return 1 - 0.75 * ease((step - 0.4) / 0.4) }
        return 0.25
    }
}

/// 网页版的文字按钮（btn-text：「撤销」「重试」「修改」「查看」）：看起来只是一段强调色的字，
/// 能点的范围撑到至少 44×44、不占地方（网页版在手机上用 ::after 撑开，样式表 pointer: coarse）
public struct WebTextButton: View {
    let title: String
    let font: Font
    let color: Color
    /// 读屏在按钮之后补充的一句（比如「确认」确认的是什么）
    let hint: String?
    let action: () -> Void

    public init(
        _ title: String, font: Font = Web.bodyMedium, color: Color = Web.accent, hint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.font = font
        self.color = color
        self.hint = hint
        self.action = action
    }

    public var body: some View {
        Text(title).font(font).foregroundStyle(color).fixedSize()
            .accessibilityHidden(true)
            .overlay {
                Button(action: action) {
                    Color.clear.frame(minWidth: Web.touch, minHeight: Web.touch).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(title))
                .accessibilityHint(Text(hint ?? ""))
            }
    }
}
