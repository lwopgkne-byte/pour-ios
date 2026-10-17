public import SwiftUI

/// 颜色的语义令牌（docs/ios/设计规范/01-颜色.md 第 2、3 节）。界面只用这些，不用原始色板。
///
/// 一句话：黑白是骨架，青是懂你，荧光是追溯，颜色只给数据。
public enum PourColor {
    private typealias Palette = PourPalette
    private typealias Alpha = ColorToken.Appearance

    // MARK: 表面（2.1）

    /// 纸：页面底色
    public static let canvas = ColorToken(light: Palette.paper50, dark: Palette.paper1000)
    /// 卡：卡片、列表、面板（暗色卡片另加 1 点 `line` 描边，见 `PourCard`）
    public static let surface = ColorToken(light: Palette.paper0, dark: Palette.paper925)
    /// 浮：菜单、弹出层
    public static let surfaceRaised = ColorToken(light: Palette.paper0, dark: Palette.paper900)
    /// 凹：卡片里的输入框、分段控件底、骨架占位
    public static let surfaceSunken = ColorToken(light: Palette.paper100, dark: Palette.paper950)
    /// 遮罩：面板背后
    public static let scrim = ColorToken(light: Alpha(.black, opacity: 0.30), dark: Alpha(.black, opacity: 0.50))

    // MARK: 文字（2.2）

    /// 墨：正文、标题
    public static let ink = ColorToken(light: Palette.paper950, dark: Palette.paper50)
    /// 淡墨：次要信息（日期、说明、单位）；增强对比度时加深一档
    public static let inkSecondary = ColorToken(
        light: Palette.paper700, dark: Palette.paper300, lightHighContrast: Palette.paper800,
        darkHighContrast: Palette.paper150)
    /// 浅墨：只用于占位、装饰、禁用——不承载要读的信息
    public static let inkTertiary = ColorToken(light: Palette.paper500, dark: Palette.paper500)
    /// 禁用的控件文字
    public static let inkDisabled = ColorToken(light: Palette.paper400, dark: Palette.paper700)
    /// 反墨：墨色按钮上的字
    public static let onAction = ColorToken(light: .white, dark: Palette.paper950)

    // MARK: 操作（2.3）——按钮、链接、选中都是墨色

    public static let action = ColorToken(light: Palette.paper950, dark: Palette.paper50)
    public static let actionPressed = ColorToken(light: Palette.paper800, dark: Palette.paper200)
    /// 次要按钮的底、按下的行
    public static let actionSoft = ColorToken(
        light: Alpha(Palette.paper950, opacity: 0.06), dark: Alpha(.white, opacity: 0.10))

    // MARK: 懂你（2.4）——只在「懂你」清单里的场景用，一屏最多三处

    public static let qing = ColorToken(light: Palette.qing600, dark: Palette.qing300)
    public static let qingStrong = ColorToken(light: Palette.qing700, dark: Palette.qing200)
    public static let qingSoft = ColorToken(light: Palette.qing50, dark: Palette.qing900)

    // MARK: 追溯（2.5）——一屏只有一种用途

    public static let marker = ColorToken(light: Palette.markerLight, dark: Palette.markerDark)

    // MARK: 需要你、危险（2.6）——不用红色表示「坏」

    public static let attention = ColorToken(light: Palette.amber700, dark: Palette.amber300)
    public static let attentionSoft = ColorToken(
        light: Alpha(Palette.amber50), dark: Alpha(Palette.amber300, opacity: 0.15))
    /// 危险：只用于不可恢复的操作（删除所有数据）。规范原写「用系统红」，M1 实测系统红在白底上只有约 3.6:1，
    /// 不到要读的文字 4.5:1（宪法第十一条）——亮色用更深的红，暗色用系统暗色的红；PourColorTests 实算
    public static let critical = ColorToken(light: RGB(0xC0271D), dark: RGB(0xFF6B61))

    // MARK: 线和填充（2.7）——增强对比度时线加倍

    public static let line = ColorToken(
        light: Alpha(Palette.paper950, opacity: 0.08), dark: Alpha(.white, opacity: 0.10),
        lightHighContrast: Alpha(Palette.paper950, opacity: 0.16), darkHighContrast: Alpha(.white, opacity: 0.20))
    public static let lineStrong = ColorToken(
        light: Alpha(Palette.paper950, opacity: 0.16), dark: Alpha(.white, opacity: 0.18),
        lightHighContrast: Alpha(Palette.paper950, opacity: 0.32), darkHighContrast: Alpha(.white, opacity: 0.36))
    public static let fillPressed = ColorToken(
        light: Alpha(Palette.paper950, opacity: 0.06), dark: Alpha(.white, opacity: 0.08))
    public static let fillSelected = ColorToken(
        light: Alpha(Palette.paper950, opacity: 0.08), dark: Alpha(.white, opacity: 0.12))
    public static let focusRing = ColorToken(
        light: Alpha(Palette.paper950, opacity: 0.40), dark: Alpha(.white, opacity: 0.50))

    // MARK: 图表（3.3）——一张图最多两种颜色加灰

    public static let chartPrimary = qing
    public static let chartSecondary = ColorToken(light: Palette.paper400, dark: Palette.paper600)
    public static let chartGrid = ColorToken(
        light: Alpha(Palette.paper950, opacity: 0.06), dark: Alpha(.white, opacity: 0.08))
    public static let chartLabel = inkSecondary
    public static let chartSelected = ink

    // MARK: 心情五档（3.2）——心情越好颜色越深（暗色反过来越亮），不用红绿

    /// 1 很差 … 5 很好
    public static func mood(_ level: Int) -> ColorToken {
        switch min(max(level, 1), 5) {
        case 1: ColorToken(light: Palette.qing100, dark: Palette.qing900)
        case 2: ColorToken(light: Palette.qing200, dark: Palette.qing800)
        case 3: ColorToken(light: Palette.qing300, dark: Palette.qing700)
        case 4: ColorToken(light: Palette.qing500, dark: Palette.qing500)
        default: ColorToken(light: Palette.qing700, dark: Palette.qing300)
        }
    }
}

extension PourDomain {
    /// 实色：色点、方块、进度条（数据里才用）；增强对比度时加深一档
    public var solid: ColorToken {
        ColorToken(
            light: palette.solidLight, dark: palette.solidDark,
            lightHighContrast: palette.textLight, darkHighContrast: palette.textDark)
    }

    /// 浅底：方块图的块
    public var soft: ColorToken { ColorToken(light: palette.bgLight, dark: palette.bgDark) }

    /// 浅底上的文字
    public var text: ColorToken { ColorToken(light: palette.textLight, dark: palette.textDark) }

    /// 名字（石、陶、杏……）
    public var displayName: String { palette.name }
}
