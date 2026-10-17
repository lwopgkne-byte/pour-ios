public import SwiftUI

/// 字的令牌（docs/ios/设计规范/02-字体与排版.md 第 2 节）。
///
/// 全部用苹果的默认字体（苹方 / SF，2026-10-17 产品主人决定），三种声音靠字号、字重、行距区分：
/// - 结构之声：界面文字
/// - 原话之声：你说的原话——行距更松（1.6 倍），配原话块左侧的细线
/// - 数字之声：统计页的主数字——SF 圆体
///
/// 全部跟着系统的动态字体缩放（按各自绑定的系统文字样式的曲线）。用法：`Text("今天").pourText(.titlePage)`
public enum PourTextStyle: String, CaseIterable, Sendable {
    case displayXL, display, titlePage, title1, titleSection, quoteLead
    case headline, body, quote, callout, meta, caption, micro

    /// 默认字号（系统「大」字号下）
    public var size: CGFloat {
        switch self {
        case .displayXL: 56
        case .display: 44
        case .titlePage: 34
        case .title1: 28
        case .titleSection, .quoteLead: 20
        case .headline, .body, .quote: 17
        case .callout: 16
        case .meta: 15
        case .caption: 13
        case .micro: 11
        }
    }

    /// 默认行高
    public var lineHeight: CGFloat {
        switch self {
        case .displayXL: 60
        case .display: 48
        case .titlePage: 41
        case .title1: 34
        case .titleSection: 25
        case .quoteLead: 30
        case .headline, .body: 22
        case .quote: 27
        case .callout: 21
        case .meta: 20
        case .caption: 18
        case .micro: 13
        }
    }

    /// 字重只用四种：常规、中（只给胶囊标签）、半粗、粗（只给页标题）
    public var weight: Font.Weight {
        switch self {
        case .displayXL, .display, .titleSection, .headline: .semibold
        case .titlePage, .title1: .bold
        default: .regular
        }
    }

    /// 跟着哪个系统文字样式缩放
    public var scalesWith: Font.TextStyle {
        switch self {
        case .displayXL, .display, .titlePage: .largeTitle
        case .title1: .title
        case .titleSection, .quoteLead: .title3
        case .headline: .headline
        case .body, .quote: .body
        case .callout: .callout
        case .meta: .subheadline
        case .caption: .footnote
        case .micro: .caption2
        }
    }

    /// 数字之声用圆体
    public var design: Font.Design { self == .display || self == .displayXL ? .rounded : .default }

    /// 是不是原话之声
    public var isQuoteVoice: Bool { self == .quote || self == .quoteLead }

    /// 比系统默认行高多出来的行距：只有原话之声有（正文 27 对系统的 22、大一号 30 对系统 title3 的 25）
    public var extraLeading: CGFloat {
        switch self {
        case .quote: lineHeight - 22
        case .quoteLead: lineHeight - 25
        default: 0
        }
    }
}

private struct PourTextModifier: ViewModifier {
    let style: PourTextStyle
    @ScaledMetric private var displaySize: CGFloat
    @ScaledMetric private var extraLeading: CGFloat

    init(style: PourTextStyle) {
        self.style = style
        _displaySize = ScaledMetric(wrappedValue: style.size, relativeTo: style.scalesWith)
        // 规范里结构之声的行高就是系统字体自带的行高（17/22、13/18……），不用再加；
        // 只有原话之声要更松，多出来的部分加在行与行之间
        _extraLeading = ScaledMetric(wrappedValue: style.extraLeading, relativeTo: style.scalesWith)
    }

    func body(content: Content) -> some View {
        content
            .font(font)
            .lineSpacing(extraLeading)
    }

    /// 规范里的字号就是系统文字样式的默认字号（17、16、15、13、11、20、28、34）：
    /// 直接绑系统样式，动态字体由系统负责，无障碍审计认得出来。只有统计的大数字（44、56）没有对应的系统样式
    private var font: Font {
        switch style {
        case .display, .displayXL: .system(size: displaySize, weight: style.weight, design: style.design)
        default: .system(style.scalesWith, design: style.design, weight: style.weight)
        }
    }
}

extension View {
    /// 用设计规范里的一种字
    public func pourText(_ style: PourTextStyle) -> some View {
        modifier(PourTextModifier(style: style))
    }
}
