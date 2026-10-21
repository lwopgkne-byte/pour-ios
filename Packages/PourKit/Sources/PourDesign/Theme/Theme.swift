public import SwiftUI

/// 生活画布 2.0 起的设计规范（docs/模块/生活画布2.0.md 第 8 节）：颜色亮暗、字、间距、圆角、阴影、玻璃、动效、触感。
/// 改到哪一页，那一页就只用这里的值；还没改到的页面暂时用 `Web.*`，全部改完删掉 `Web.*`
public enum Theme {}

// MARK: - 颜色

extension Theme {
    /// 颜色的值（亮、暗两档）：对比度测试量的是这些（ThemeColorTests），界面用 `Palette`。
    /// 字的颜色留了余量：字画出来比设定色浅一截（底色、色块画出来和设定的一样，只有字浅）——2026-10-21 截图实量：
    /// 主字色 #1D1C1A 画成 #262522，次要色 #67645C 画成 #7A776F，蓝 #2868D0 画成 #327ED9。测试按最浅的那档（85%）算
    public enum Tokens {
        /// 页面的底：暖一点的浅灰（深色是近黑）
        public static let background = ColorToken(light: RGB(0xF3F2EF), dark: RGB(0x0D0D0C))
        /// 卡片：白（深色是亮一档的灰）
        public static let card = ColorToken(light: RGB(0xFFFFFF), dark: RGB(0x1B1B19))
        public static let label = ColorToken(light: RGB(0x1D1C1A), dark: RGB(0xF2F0EB))
        public static let secondaryLabel = ColorToken(light: RGB(0x58554F), dark: RGB(0xABA79F))
        /// 第三层字：只给不要紧的（刻度、角标），正文不用它；对比度和以前的辅助文字一样（约 3.7:1）
        public static let tertiaryLabel = ColorToken(light: RGB(0x807C75), dark: RGB(0x8C887F))
        /// 浅浅的一层墨：进度环的底、骨架灰块、选中的日子
        public static let fill = ColorToken(
            light: .init(RGB(0x1D1C1A), opacity: 0.06), dark: .init(.white, opacity: 0.08))
        public static let separator = ColorToken(
            light: .init(RGB(0x1D1C1A), opacity: 0.08), dark: .init(.white, opacity: 0.08))
        /// 能点的字、图标
        public static let accent = ColorToken(light: RGB(0x1B56B3), dark: RGB(0x64A0F4))
        /// 填满的按钮、今天那个圆（上面是白字）
        public static let accentFill = ColorToken(light: RGB(0x2563C8), dark: RGB(0x2563C8))
        /// 你说的话的气泡
        public static let bubble = ColorToken(light: RGB(0xE6EEFB), dark: RGB(0x1E3352))
        /// 今天的样子里垫在亮点、小胶囊下面的一层（盖在心情的底色上）：亮色是一层白，深色是压暗一点
        public static let statFill = ColorToken(
            light: .init(.white, opacity: 0.62), dark: .init(.black, opacity: 0.28))
        public static let good = ColorToken(light: RGB(0x1A683D), dark: RGB(0x5CC48B))
        public static let warn = ColorToken(light: RGB(0x7D5500), dark: RGB(0xE3AF4B))
        public static let bad = ColorToken(light: RGB(0xAA3831), dark: RGB(0xEE7A70))
        /// 深色里卡片边上那道 0.5 点的光
        public static let cardEdge = ColorToken(light: .init(.white, opacity: 0), dark: .init(.white, opacity: 0.06))
    }

    /// 界面用的颜色：跟着系统亮暗、「增强对比度」自动换
    public enum Palette {
        public static let background = Tokens.background.color
        public static let card = Tokens.card.color
        public static let label = Tokens.label.color
        public static let secondaryLabel = Tokens.secondaryLabel.color
        public static let tertiaryLabel = Tokens.tertiaryLabel.color
        public static let fill = Tokens.fill.color
        public static let separator = Tokens.separator.color
        public static let accent = Tokens.accent.color
        public static let accentFill = Tokens.accentFill.color
        public static let onAccent = Color.white
        public static let bubble = Tokens.bubble.color
        public static let statFill = Tokens.statFill.color
        public static let good = Tokens.good.color
        public static let warn = Tokens.warn.color
        public static let bad = Tokens.bad.color
        public static let cardEdge = Tokens.cardEdge.color
        /// 卡片的两层影子（只在亮色）
        public static let shadowNear = Color.black.opacity(0.04)
        public static let shadowFar = Color.black.opacity(0.05)
        /// 浮层后面压暗的那一层
        public static let dim = Color.black.opacity(0.18)

        /// 目标的状态色：不落后、稍微落后、落后较多；还没有状态的是第三层字的灰
        public static func status(_ tone: String) -> Color {
            switch tone {
            case "good": good
            case "warn": warn
            case "bad": bad
            default: tertiaryLabel
            }
        }
    }
}

// MARK: - 类别的颜色

extension Theme {
    /// 一个类别的颜色：实色画色块、图标、圆点；浅底（15%）垫在图标下面
    public struct TagColor: Sendable {
        public let solid: Color
        public let tint: Color
    }

    /// 九种颜色名（服务器存的是名字）各两档：亮色实一点，深色亮一点
    static let tagValues: [String: (light: UInt32, dark: UInt32)] = [
        "gray": (0x8E8C86, 0x9C9A94), "brown": (0xA67A5E, 0xC0957A), "orange": (0xE8873A, 0xF29A55),
        "yellow": (0xC9962A, 0xE0B04A), "green": (0x46A56E, 0x5CC48B), "blue": (0x3D8BD9, 0x5FA5EE),
        "purple": (0x8F6FD0, 0xA58BE6), "pink": (0xD7699A, 0xE883AE), "red": (0xE0605A, 0xF07A72),
    ]

    /// 以前按 iOS 规范存的颜色名（stone、moss……）也认
    static let legacyTags: [String: String] = [
        "stone": "gray", "clay": "brown", "apricot": "orange", "straw": "yellow", "moss": "green",
        "lake": "blue", "wisteria": "purple", "sakura": "pink", "brick": "red",
    ]

    /// 某个颜色名的类别色；认不出的用灰
    public static func tag(_ name: String) -> TagColor {
        let key = tagValues[name] != nil ? name : (legacyTags[name] ?? "gray")
        let value = tagValues[key] ?? (0x8E8C86, 0x9C9A94)
        let solid = ColorToken(light: RGB(value.light), dark: RGB(value.dark))
        let tint = ColorToken(
            light: .init(RGB(value.light), opacity: 0.15), dark: .init(RGB(value.dark), opacity: 0.18))
        return TagColor(solid: solid.color, tint: tint.color)
    }

    /// 九种颜色名，按原来的顺序
    public static let tagNames = ["gray", "brown", "orange", "yellow", "green", "blue", "purple", "pink", "red"]
}

// MARK: - 心情的颜色（今天的样子那张卡的底）

extension Theme {
    /// 这一天的心情：挺好、一般、不太好、有起有落，或者没说
    public enum MoodTone: Sendable {
        case good, plain, low, mixed, none
    }

    /// 底上那几团淡淡的颜色（从左上、右上、下面三处晕开）。深色里只是一点点色调：浅颜色叠在深底上很快就发灰发亮，
    /// 上面的字就压不住了（ThemeColorTests 量最坏的情况：三团都叠在一处）
    public static func moodWashTokens(_ tone: MoodTone) -> [ColorToken] {
        let wash = { (hex: UInt32, light: Double, dark: Double) in
            ColorToken(light: .init(RGB(hex), opacity: light), dark: .init(RGB(hex), opacity: dark))
        }
        switch tone {
        case .good: return [wash(0xFFB78C, 0.50, 0.10), wash(0xFFD4A8, 0.42, 0.07), wash(0xFFE2C4, 0.50, 0.05)]
        case .plain: return [wash(0xE8DCC8, 0.55, 0.06), wash(0xFFD4A8, 0.42, 0.07), wash(0xE8E0D2, 0.60, 0.04)]
        case .low: return [wash(0xA9C2E8, 0.50, 0.09), wash(0xBEAAFF, 0.42, 0.09), wash(0xE8E0D2, 0.60, 0.04)]
        case .mixed: return [wash(0xFFB78C, 0.50, 0.10), wash(0xBEAAFF, 0.42, 0.09), wash(0xFFE2C4, 0.50, 0.05)]
        case .none: return [wash(0xE8E0D2, 0.60, 0.04), wash(0xE8DCC8, 0.55, 0.06), wash(0xE8E0D2, 0.60, 0.04)]
        }
    }

    /// 界面用的心情底色
    public static func moodWash(_ tone: MoodTone) -> [Color] {
        moodWashTokens(tone).map(\.color)
    }
}
