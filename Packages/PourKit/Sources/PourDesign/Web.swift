public import SwiftUI

/// 网页版的设计令牌（web/src/design/tokens.ts 原样，手机那一档）。
/// 产品主人 2026-10-19：UI 先只做生活画布，样式 1 比 1 照网页版，不另外设计——
/// 照网页版搬的界面只用这里的值（「纸·墨·青」那套令牌留给还没换的界面）
public enum Web {
    /// 主文字色的 RGB（暖调近黑）：次要文字、边框、悬停背景都从它派生
    private static func ink(_ alpha: Double) -> Color {
        Color(red: 55 / 255, green: 53 / 255, blue: 47 / 255).opacity(alpha)
    }

    private static func hex(_ value: UInt32) -> Color {
        Color(
            red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255)
    }

    // MARK: - 颜色

    /// 页面背景
    public static let bg = Color.white
    /// 次级表面：输入框底、对话面板底色
    public static let bgSubtle = hex(0xF7F6F3)
    public static let bgHover = ink(0.06)
    public static let bgPressed = ink(0.1)
    /// 主文字
    public static let fg = hex(0x37352F)
    public static let fgSecondary = ink(0.7)
    public static let fgTertiary = ink(0.6)
    /// 边框和分割线，永远 1 点
    public static let line = ink(0.09)
    /// 虚线边框（待确认）、引用的竖线
    public static let lineStrong = ink(0.2)
    /// 唯一的强调色：沉稳的蓝
    public static let accent = hex(0x1B6FC8)
    public static let accentPressed = hex(0x135093)
    public static let onAccent = Color.white
    /// 手机抽屉背后的遮罩
    public static let overlay = Color(red: 15 / 255, green: 15 / 255, blue: 15 / 255).opacity(0.2)
    public static let danger = hex(0xA23A36)
    /// 演示数据的横幅、原话里对应的那一段：黄色标签的底色和字色
    public static var notice: Tag { tag("yellow") }

    /// 类别标签的九种柔和色：bg 很浅的底色，fg 较深的文字色，solid 用于时间轴色块、圆点
    public struct Tag: Sendable {
        public let bg: Color
        public let fg: Color
        public let solid: Color
    }

    private static let tags: [String: Tag] = [
        "gray": Tag(bg: hex(0xF1F1EF), fg: hex(0x5A5955), solid: hex(0x908F8B)),
        "brown": Tag(bg: hex(0xF4EEEE), fg: hex(0x744B38), solid: hex(0xA27763)),
        "orange": Tag(bg: hex(0xFBECDD), fg: hex(0x8A4609), solid: hex(0xD27829)),
        "yellow": Tag(bg: hex(0xFBF3DB), fg: hex(0x735413), solid: hex(0xB3882D)),
        "green": Tag(bg: hex(0xEDF3EC), fg: hex(0x2F5F47), solid: hex(0x5C9474)),
        "blue": Tag(bg: hex(0xE7F3F8), fg: hex(0x22587F), solid: hex(0x4B8FBF)),
        "purple": Tag(bg: hex(0xF6F3F9), fg: hex(0x654285), solid: hex(0x9A79B8)),
        "pink": Tag(bg: hex(0xFAF1F5), fg: hex(0x8A3362), solid: hex(0xC26B99)),
        "red": Tag(bg: hex(0xFDEBEC), fg: hex(0x9E3834), solid: hex(0xD0605B)),
    ]

    /// 以前按 iOS 规范存的颜色名（stone、moss……）也认：换成网页版对应的那一种
    private static let legacy: [String: String] = [
        "stone": "gray", "clay": "brown", "apricot": "orange", "straw": "yellow", "moss": "green",
        "lake": "blue", "wisteria": "purple", "sakura": "pink", "brick": "red",
    ]

    /// 目标的状态色（只用于目标进度）：不落后、稍微落后、落后较多、已不可能完成 / 还没有状态
    public static func status(_ tone: String) -> Color {
        switch tone {
        case "good": hex(0x5E9C73)
        case "warn": hex(0xB58829)
        case "bad": hex(0xD0766C)
        default: hex(0x908F8A)
        }
    }

    /// 某个颜色名的标签色；认不出的用灰
    public static func tag(_ name: String) -> Tag {
        tags[name] ?? legacy[name].flatMap { tags[$0] } ?? tags["gray"].unsafelyUnwrappedTag
    }

    // MARK: - 字（手机那一档：标题 26、小节 18、正文 16、辅助 13）

    /// 网页版在 iPhone 上的中文字体是苹方；默认字号下和网页版一样大，在设置里调大字号时跟着变大（动态字体）
    private static func pingfang(_ size: CGFloat, _ style: Font.TextStyle, _ weight: Font.Weight = .regular) -> Font {
        Font.custom("PingFang SC", size: size, relativeTo: style).weight(weight)
    }

    public static let title = pingfang(26, .title, .bold)
    /// 回顾里的关键数字：一页唯一的焦点（网页版 text-display，手机 28）
    public static let displaySemibold = pingfang(28, .largeTitle, .semibold)
    /// 「钱」那个大数（网页版 money-big：text-display、粗体）
    public static let displayBold = pingfang(28, .largeTitle, .bold)
    /// 「花在哪」小方块里的钱
    public static let sectionBold = pingfang(18, .title3, .bold)
    /// 你说的原话（值不值、借钱时怎么说的）：宋体，和网页版 --font-serif 一样
    public static let quote = Font.custom("Songti SC", size: 16, relativeTo: .body)
    /// 「你怎么说它」那句原话：宋体、小节那么大
    public static let quoteSection = Font.custom("Songti SC", size: 18, relativeTo: .title3)
    /// 人情往来里你当时的原话：宋体、小一号
    public static let quoteCaption = Font.custom("Songti SC", size: 13, relativeTo: .footnote)
    public static let section = pingfang(18, .title3)
    /// 小节标题（设置页的「大模型」「类别」，详情的标题）
    public static let sectionSemibold = pingfang(18, .title3, .semibold)
    public static let body = pingfang(16, .body)
    public static let bodyMedium = pingfang(16, .body, .medium)
    public static let bodySemibold = pingfang(16, .body, .semibold)
    public static let caption = pingfang(13, .footnote)
    public static let captionMedium = pingfang(13, .footnote, .medium)
    /// 等宽字（处理日志里的原始内容）
    public static let mono = Font.system(.footnote, design: .monospaced)
    /// 正文行高 1.6 多出来的行距（苹方本身的行高约 1.4 倍）
    public static let bodyLineSpacing: CGFloat = 16 * 0.2
    /// 引用的原话行高 1.8
    public static let quoteLineSpacing: CGFloat = 16 * 0.4
    /// 回顾一页开头那句话：18 号、行高 1.7
    public static let overviewLineSpacing: CGFloat = 18 * 0.3
    /// 笔记库的随笔（感悟、好时刻）：18 号、行高 1.9
    public static let essayLineSpacing: CGFloat = 18 * 0.5
    /// 回顾的小标题、「每日回顾」：字距 0.08em
    public static let kickerTracking: CGFloat = 13 * 0.08

    // MARK: - 间距、尺寸、圆角、动效

    public static let space1: CGFloat = 4
    public static let space2: CGFloat = 8
    public static let space3: CGFloat = 12
    public static let space4: CGFloat = 16
    public static let space6: CGFloat = 24
    public static let space8: CGFloat = 32
    public static let space12: CGFloat = 48
    public static let space16: CGFloat = 64
    /// 手机上可点击区域的最小尺寸
    public static let touch: CGFloat = 44
    /// 按钮、小标签的高度
    public static let control: CGFloat = 32
    public static let icon: CGFloat = 20
    public static let header: CGFloat = 48
    /// 左侧导航的宽度
    public static let navWidth: CGFloat = 240
    /// 轻提示、输入 PIN 那一页最宽多少
    public static let toastWidth: CGFloat = 400
    public static let radiusControl: CGFloat = 6
    public static let radiusCard: CGFloat = 8
    public static let radiusPanel: CGFloat = 12
    /// 面板、抽屉展开收起：200 毫秒，平滑减速不弹跳
    public static let panel = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.2)
    public static let fast = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.1)
    /// 加载中的灰条慢慢明暗：一圈 1.6 秒
    public static let pulse = Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
    /// 浮在内容上方的东西的影子（开关上的圆点）：很淡
    public static let shadow = Color(red: 15 / 255, green: 15 / 255, blue: 15 / 255).opacity(0.08)
    /// 九种类别色的名字，按网页版的顺序（TAG_COLORS）
    public static let tagNames = ["gray", "brown", "orange", "yellow", "green", "blue", "purple", "pink", "red"]
}

extension Optional where Wrapped == Web.Tag {
    /// 灰色一定在表里
    fileprivate var unsafelyUnwrappedTag: Web.Tag {
        switch self {
        case .some(let tag): return tag
        case .none: return Web.Tag(bg: Web.bgSubtle, fg: Web.fgSecondary, solid: Web.fgTertiary)
        }
    }
}
