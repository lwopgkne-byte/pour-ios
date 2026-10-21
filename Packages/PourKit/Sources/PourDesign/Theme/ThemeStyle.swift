public import SwiftUI

// MARK: - 字

extension Theme {
    /// 字：系统字体（英文、数字是 SF，中文自动是苹方），都用系统的字号档，跟着「更大字体」变大。
    /// 数字用圆体；原话用宋体
    public enum Typeface {
        /// 日子大标题「今天」34
        public static let largeTitle = Font.largeTitle.weight(.bold)
        /// 今天的样子那句话（20）
        public static let summary = Font.title3
        /// 区块标题「今天推进的目标」（20 半粗）
        public static let section = Font.title3.weight(.semibold)
        /// 正文：记录、对话（17）
        public static let body = Font.body
        public static let bodyMedium = Font.body.weight(.medium)
        public static let bodySemibold = Font.body.weight(.semibold)
        /// 卡片标题、顶上的胶囊（15 半粗）
        public static let cardTitle = Font.subheadline.weight(.semibold)
        /// 次要的一行（15）
        public static let subheadline = Font.subheadline
        /// 大数后面的单位（15 中等）
        public static let unit = Font.subheadline.weight(.medium)
        /// 卡片的大数字（28 半粗圆体）
        public static let metric = Font.system(.title, design: .rounded, weight: .semibold)
        /// 今天的样子里的数字（22 半粗圆体）
        public static let heroMetric = Font.system(.title2, design: .rounded, weight: .semibold)
        /// 一行里的钱、次数（15 半粗圆体）
        public static let rowNumber = Font.system(.subheadline, design: .rounded, weight: .semibold)
        /// 一周条的日子（17 半粗圆体）
        public static let dayNumber = Font.system(.body, design: .rounded, weight: .semibold)
        /// 注释、时间（13）
        public static let footnote = Font.footnote
        public static let footnoteMedium = Font.footnote.weight(.medium)
        public static let footnoteSemibold = Font.footnote.weight(.semibold)
        /// 小标签（12 半粗）
        public static let caption = Font.caption.weight(.semibold)
        /// 刻度、角标（11 中等圆体）
        public static let tick = Font.system(.caption2, design: .rounded, weight: .medium)
        /// 图标小方块里的图标、色块上的小图标
        public static let glyph = Font.caption.weight(.semibold)
        /// 玻璃圆按钮里的图标（17 中等）
        public static let toolbarIcon = Font.body.weight(.medium)
        /// 你说的原话（宋体 17）
        public static let quote = Font.custom("Songti SC", size: 17, relativeTo: .body)
        /// 只写了一句感悟那天的大引用（宋体 21）
        public static let quoteLarge = Font.custom("Songti SC", size: 21, relativeTo: .title3)
    }

    /// 中文多给的行距
    public enum Leading {
        /// 正文
        public static let body: CGFloat = 3
        /// 今天的样子那句话
        public static let summary: CGFloat = 7
        /// 原话引用
        public static let quote: CGFloat = 8
    }
}

// MARK: - 间距、尺寸、圆角

extension Theme {
    /// 间距：4 点为单位
    public enum Space {
        public static let hairline: CGFloat = 2
        public static let tight: CGFloat = 4
        /// 小圆点和字之间
        public static let snug: CGFloat = 6
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 12
        /// 小卡、带子的内边距
        public static let inset: CGFloat = 14
        public static let regular: CGFloat = 16
        public static let large: CGFloat = 20
        public static let xLarge: CGFloat = 24
        public static let section: CGFloat = 32
        /// 屏幕两边
        public static let screen: CGFloat = 16
        /// 卡片之间
        public static let cardGap: CGFloat = 12
    }

    /// 尺寸
    public enum Size {
        /// 能点的地方至少这么大
        public static let touch: CGFloat = 44
        /// 类别图标的小方块
        public static let tile: CGFloat = 28
        /// 小圆点（没说时间的事、类别色）
        public static let dot: CGFloat = 8
        /// 小标签、胶囊的高
        public static let badge: CGFloat = 22
        public static let capsule: CGFloat = 32
        /// 勾选的圆圈
        public static let check: CGFloat = 24
        /// 卡片标题旁的小进度环
        public static let miniRing: CGFloat = 18
        /// 数量卡右边的进度环
        public static let smallRing: CGFloat = 34
        /// 输入框；右边发送的圆
        public static let composer: CGFloat = 56
        public static let sendButton: CGFloat = 36
        /// 一天的带子
        public static let ribbon: CGFloat = 36
        /// 细横条（睡眠、进食窗口、分段条）
        public static let bar: CGFloat = 8
        /// 一行小字（刻度、带子下面的名字）
        public static let tickRow: CGFloat = 16
        /// 一天里的小曲线、小圆点那一行
        public static let curve: CGFloat = 44
        public static let dotRow: CGFloat = 22
        /// 目标小卡的宽
        public static let goalCard: CGFloat = 160
        /// 进度环
        public static let ring: CGFloat = 46
        public static let ringLine: CGFloat = 6
        /// 一周条的日子圆
        public static let dayCircle: CGFloat = 38
        /// 骨架灰条：一行字、一张卡
        public static let skeletonLine: CGFloat = 20
        public static let skeletonWidth: CGFloat = 240
    }

    /// 圆角：都是连续圆角（苹果的那种）
    public enum Corner {
        public static let hero: CGFloat = 28
        public static let card: CGFloat = 22
        public static let smallCard: CGFloat = 20
        public static let composer: CGFloat = 28
        public static let bubble: CGFloat = 20
        public static let stat: CGFloat = 16
        public static let receipt: CGFloat = 18
        public static let chip: CGFloat = 12
        public static let ribbon: CGFloat = 11
        public static let tile: CGFloat = 8
        public static let bar: CGFloat = 4
    }

    /// 一个连续圆角的矩形
    public static func rounded(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

// MARK: - 卡片的样子

/// 卡片：白底（深色是亮一档的灰）、连续圆角；亮色两层很淡的影子，深色边上 0.5 点的光，不画线
public struct ThemeCard: ViewModifier {
    let radius: CGFloat
    let padding: CGFloat

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.card, in: Theme.rounded(radius))
            .modifier(ThemeEdge(radius: radius))
    }
}

/// 卡片的边：亮色两层很淡的影子，深色边上 0.5 点的光
public struct ThemeEdge: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let radius: CGFloat

    public func body(content: Content) -> some View {
        content
            .overlay {
                if scheme == .dark {
                    Theme.rounded(radius).strokeBorder(Theme.Palette.cardEdge, lineWidth: 0.5)
                }
            }
            .shadow(color: scheme == .dark ? .clear : Theme.Palette.shadowNear, radius: 1, y: 1)
            .shadow(color: scheme == .dark ? .clear : Theme.Palette.shadowFar, radius: 10, y: 6)
    }
}

extension View {
    /// 放在卡片上：默认 22 圆角、16 内边距
    public func themeCard(radius: CGFloat = Theme.Corner.card, padding: CGFloat = Theme.Space.regular) -> some View {
        modifier(ThemeCard(radius: radius, padding: padding))
    }

    /// 自己画了底的卡片（今天的样子）也要同样的影子和边
    public func themeEdge(radius: CGFloat) -> some View {
        modifier(ThemeEdge(radius: radius))
    }

    /// 浮在内容上的玻璃（顶上的按钮、输入框、浮条）；系统「降低透明度」时自己变实
    public func themeGlass(radius: CGFloat) -> some View {
        glassEffect(.regular.interactive(), in: Theme.rounded(radius))
    }

    /// 浮在内容上的玻璃胶囊
    public func themeGlassCapsule() -> some View {
        glassEffect(.regular.interactive(), in: Capsule())
    }
}

// MARK: - 动效和触感

extension Theme {
    /// 动效：都不超过 0.5 秒；「减弱动态效果」时用 `reduced`
    public enum Motion {
        /// 按下、按钮状态、图标替换
        public static let quick = Animation.snappy(duration: 0.2)
        /// 展开、收起、换一天、浮条出现
        public static let standard = Animation.smooth(duration: 0.35)
        /// 新卡片长出来、发出去
        public static let emphasized = Animation.spring(duration: 0.5, bounce: 0.2)
        /// 减弱动态效果时：只渐变，不缩放不位移
        public static let reduced = Animation.easeInOut(duration: 0.2)
        /// 骨架灰块慢慢明暗：一圈 1.6 秒
        public static let pulse = Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)

        /// 按系统设置挑：减弱动态效果时换成渐变
        public static func pick(_ animation: Animation, reduceMotion: Bool) -> Animation {
            reduceMotion ? reduced : animation
        }
    }

    #if os(iOS)
        /// 触感（docs/模块/生活画布2.0.md 8.6）
        public enum Haptics {
            public static let send = SensoryFeedback.impact(weight: .light)
            public static let done = SensoryFeedback.success
            public static let failed = SensoryFeedback.error
            public static let select = SensoryFeedback.selection
            public static let voice = SensoryFeedback.impact(weight: .medium)
            public static let check = SensoryFeedback.impact(flexibility: .soft)
            public static let warning = SensoryFeedback.warning
        }
    #endif
}
