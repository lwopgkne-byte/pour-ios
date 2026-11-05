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
        /// 页面上的大数（钱的主页「¥9,616」）：34 点圆体（01 需求文档 3.1）
        public static let bigNumber = Font.system(.largeTitle, design: .rounded, weight: .bold)
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
        /// 选中的那个表情下面的字（原型 700）
        public static let footnoteBold = Font.footnote.weight(.bold)
        /// 小标签（12 半粗）
        public static let caption = Font.caption.weight(.semibold)
        /// 刻度、角标（11 中等圆体）
        public static let tick = Font.system(.caption2, design: .rounded, weight: .medium)
        /// 图标小方块里的图标、色块上的小图标
        public static let glyph = Font.caption.weight(.semibold)
        /// 玻璃圆按钮里的图标（17 中等）
        public static let toolbarIcon = Font.body.weight(.medium)
        /// 「我的」快捷大按钮的图标
        public static let quickIcon = Font.title2.weight(.semibold)
        /// 你说的原话（宋体 17）
        public static let quote = Font.custom("Songti SC", size: 17, relativeTo: .body)
        /// 对话里的话（原型 16）
        public static let message = Font.callout
        /// 待办 2.0 编辑弹框的名字（设计稿 26 粗，系统字号里最近的是 28）
        public static let editTitle = Font.title.weight(.bold)
        /// 四象限小卡的名字（待办 2.0 第 7 步：格子窄，比一行待办小一号，长了折成两行）
        public static let cardItem = Font.callout
        /// 按住一行的菜单最上面四个格子的图标（待办 2.0 第 6 步）
        public static let quadrantIcon = Font.title3.weight(.medium)
        /// 点开一条记录的大标题「上班」（原型 24 粗，系统字号里最近的是 22）
        public static let recordTitle = Font.title2.weight(.bold)
        /// 弹层的标题「说一句」（原型 18 粗）
        public static let sheetTitle = Font.headline.weight(.bold)
        /// 一页里一块的标题，在卡片外面（原型 .sh h3：18 粗）
        public static let pageSection = Font.headline.weight(.bold)
        /// 说一句里的小胶囊（原型 13.5）；亮起来的（补记到别的日子）半粗
        public static let chip = Font.footnote
        public static let chipLit = Font.footnote.weight(.semibold)
        /// 蓝色圆按钮里的麦克风、发送（原型 22 / 20 的图标）
        public static let micIcon = Font.title3.weight(.medium)
        public static let sendIcon = Font.body.weight(.semibold)
        /// 处理日志：等宽，一行一行好对齐
        public static let mono = Font.system(.footnote, design: .monospaced)
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
        /// 说一句弹层里：蓝色圆按钮（麦克风、发送）、输入框、小胶囊的高（照原型 40 / 42 / 30）
        public static let micButton: CGFloat = 40
        public static let field: CGFloat = 42
        public static let smallChip: CGFloat = 30
        /// 收着时浮在页面底下的「说一句」条（原型 .say 50 高）；左边「对话」图标的方块（原型 38）
        public static let sayBar: CGFloat = 50
        public static let sayIcon: CGFloat = 38
        /// 说话时的声波
        public static let waveform: CGFloat = 32
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
        /// 3.0 目标（第 7 步）：一个目标页头上的大环、它的线；坚持那一行 14 天的小格子；30 天的格子；七天 × 早中晚的格子；图的高度
        public static let bigRing: CGFloat = 88
        /// 目标首页一行的环（比 ring 小一点：第一屏要放得下 5 个目标，01 需求文档 9.14 第 6 条）
        public static let rowRing: CGFloat = 38
        public static let bigRingLine: CGFloat = 10
        public static let dayCell: CGFloat = 11
        public static let monthCell: CGFloat = 36
        public static let whenCell: CGFloat = 30
        public static let goalChart: CGFloat = 176
        public static let weekBars: CGFloat = 120
        /// 3.0 关于我（第 8 步）：ⓘ 弹出来的说明有多宽；一行一个领域左边名字至少多宽；人的星图多高；2×2 小卡至少多高
        public static let popover: CGFloat = 300
        public static let label: CGFloat = 64
        public static let starMap: CGFloat = 340
        public static let angleCard: CGFloat = 116
        /// 一周条的日子圆
        public static let dayCircle: CGFloat = 38
        /// 骨架灰条：一行字、一张卡
        public static let skeletonLine: CGFloat = 20
        public static let skeletonWidth: CGFloat = 240
        /// 待办 2.0 三段的切换（清单 | 四象限 | 时间线）有多高；「放进哪一格」一块多高；编辑弹框的芯片多高
        public static let segment: CGFloat = 38
        public static let choiceBlock: CGFloat = 64
        public static let editChip: CGFloat = 36
        /// 记心情那一排表情的圆（原型 .face .c 50）；一行一刻心情前面的小表情（原型 faceDot 30）
        public static let moodFace: CGFloat = 50
        public static let moodDot: CGFloat = 30
        /// 「我的」页头的头像（3.0）
        public static let avatar: CGFloat = 58
        /// 「我的」里功能格子的彩色方块、快捷大按钮的圆（3.0，01 需求文档 2.3：44×44、圆角 12）
        public static let hubIcon: CGFloat = 44
        public static let quickIcon: CGFloat = 52
        /// 格子角上的小胶囊最小多大
        public static let badgeDot: CGFloat = 18
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
        /// 「我的」功能格子的彩色方块（3.0，01 需求文档 2.3）、快捷大按钮的浅底
        public static let hubTile: CGFloat = 12
        public static let quick: CGFloat = 17
        /// 待办 2.0 三段的切换；「放进哪一格」的一块
        public static let segment: CGFloat = 12
        public static let choice: CGFloat = 14
        /// 从下面拉上来的弹层上面两个角（照原型 .sheet 30）
        public static let sheet: CGFloat = 30
        /// 对话气泡贴着说话人那一角（原型 6）
        public static let tail: CGFloat = 6
    }

    /// 一个连续圆角的矩形
    public static func rounded(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

// MARK: - 卡片的样子

/// 卡片：白底、连续圆角、两层很淡的影子，不画线
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

/// 卡片的边：两层很淡的影子
public struct ThemeEdge: ViewModifier {
    let radius: CGFloat

    public func body(content: Content) -> some View {
        content
            .shadow(color: Theme.Palette.shadowNear, radius: 1, y: 1)
            .shadow(color: Theme.Palette.shadowFar, radius: 10, y: 6)
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

    /// 浮在内容上的玻璃（顶上的按钮、输入框、浮条）；系统「降低透明度」时自己变实。
    /// active 是 false 时没有玻璃，但还是同一个视图：里面的输入框不会因为玻璃有没有而重建（键盘的焦点不丢）
    public func themeGlass(radius: CGFloat, active: Bool = true) -> some View {
        glassEffect(active ? .regular.interactive() : .identity, in: Theme.rounded(radius))
    }

    /// 浮在内容上的玻璃胶囊
    public func themeGlassCapsule() -> some View {
        glassEffect(.regular.interactive(), in: Capsule())
    }

    /// 出现、消失的样子；「减弱动态效果」时只渐变，不缩放不位移（docs/模块/生活画布2.0.md 8.5）
    public func themeTransition(_ transition: AnyTransition) -> some View {
        modifier(ThemeTransition(transition: transition))
    }
}

private struct ThemeTransition: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let transition: AnyTransition

    func body(content: Content) -> some View {
        content.transition(reduceMotion ? .opacity : transition)
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
        /// 3.0 的弹簧（docs/3.0/06-交互细节.md 第 0 节「动效」）：推进来、展开、数字变化
        public static let spring = Animation.spring(response: 0.42, dampingFraction: 0.86)
        /// 弹层滑出 0.5 秒、收回 0.3 秒
        public static let sheetIn = Animation.smooth(duration: 0.5)
        public static let sheetOut = Animation.smooth(duration: 0.3)
        /// 3.0 感悟「换一句」：这张往左滑走（新的用 spring 进来）
        public static let swapOut = Animation.easeIn(duration: 0.25)
        /// 管理常用时格子轻轻抖
        public static let jiggle = Animation.easeInOut(duration: 0.32).repeatForever(autoreverses: true)

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
            /// 3.0（06 交互细节第 0 节「触感」）：滑过阈值、删除、数字键盘每一下
            public static let swipe = SensoryFeedback.impact(weight: .light)
            public static let delete = SensoryFeedback.warning
            public static let keypad = SensoryFeedback.impact(flexibility: .soft)
            /// 待办 2.0：四象限里把卡片放进别的格子、时间线上放到一个钟点（松手轻震）
            public static let drop = SensoryFeedback.impact(weight: .medium)
        }
    #endif
}

extension View {
    /// 选中一个（胶囊、心情）时轻轻一下（iPhone 上；Mac 上跑规则测试时什么也不做）
    @ViewBuilder
    public func themeSelectionFeedback<T: Equatable>(trigger: T) -> some View {
        #if os(iOS)
            sensoryFeedback(Theme.Haptics.select, trigger: trigger)
        #else
            self
        #endif
    }
}
