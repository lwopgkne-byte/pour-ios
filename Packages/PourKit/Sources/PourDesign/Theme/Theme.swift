public import SwiftUI

/// 生活画布 2.0 起的设计规范（docs/模块/生活画布2.0.md 第 8 节）：颜色、字、间距、圆角、阴影、玻璃、动效、触感。
/// 只有一种样子（亮色）：产品主人 2026-10-21「不要搞两个风格，把黑色的去掉」。
/// 改到哪一页，那一页就只用这里的值；还没改到的页面暂时用 `Web.*`，全部改完删掉 `Web.*`
public enum Theme {}

// MARK: - 颜色

extension Theme {
    /// 颜色的值：对比度测试量的是这些（ThemeColorTests），界面用 `Palette`。
    /// 字的颜色留了余量：字画出来比设定色浅一截（底色、色块画出来和设定的一样，只有字浅）——2026-10-21 截图实量：
    /// 主字色 #1D1C1A 画成 #262522，次要色 #67645C 画成 #7A776F，蓝 #2868D0 画成 #327ED9。测试按最浅的那档（85%）算
    public enum Tokens {
        /// 页面的底：暖一点的浅灰
        public static let background = one(0xF3F2EF)
        /// 卡片：白
        public static let card = one(0xFFFFFF)
        public static let label = one(0x1D1C1A)
        public static let secondaryLabel = one(0x58554F)
        /// 第三层字：只给不要紧的（刻度、角标），正文不用它；对比度和以前的辅助文字一样（约 3.7:1）
        public static let tertiaryLabel = one(0x807C75)
        /// 浅浅的一层墨：进度环的底、骨架灰块、选中的日子
        public static let fill = one(0x1D1C1A, opacity: 0.06)
        public static let separator = one(0x1D1C1A, opacity: 0.08)
        /// 能点的字、图标
        public static let accent = one(0x1B56B3)
        /// 填满的按钮、今天那个圆（上面是白字）
        public static let accentFill = one(0x2563C8)
        /// 你说的话的气泡
        public static let bubble = one(0xE6EEFB)
        /// 盖在心情底色上的一层白（回顾里「这一天的样子」的数字小块、小胶囊垫在下面）
        public static let statFill = one(0xFFFFFF, opacity: 0.62)
        public static let good = one(0x1A683D)
        public static let warn = one(0x7D5500)
        public static let bad = one(0xAA3831)

        /// 一个颜色（只有一种样子：亮、暗用同一个值）
        static func one(_ hex: UInt32, opacity: Double = 1) -> ColorToken {
            let value = ColorToken.Appearance(RGB(hex), opacity: opacity)
            return ColorToken(light: value, dark: value)
        }
    }

    /// 界面用的颜色
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

    /// 九种颜色名（服务器存的是名字）
    static let tagValues: [String: UInt32] = [
        "gray": 0x8E8C86, "brown": 0xA67A5E, "orange": 0xE8873A, "yellow": 0xC9962A, "green": 0x46A56E,
        "blue": 0x3D8BD9, "purple": 0x8F6FD0, "pink": 0xD7699A, "red": 0xE0605A,
    ]

    /// 以前按 iOS 规范存的颜色名（stone、moss……）也认
    static let legacyTags: [String: String] = [
        "stone": "gray", "clay": "brown", "apricot": "orange", "straw": "yellow", "moss": "green",
        "lake": "blue", "wisteria": "purple", "sakura": "pink", "brick": "red",
    ]

    /// 某个颜色名的类别色；认不出的用灰
    public static func tag(_ name: String) -> TagColor {
        let key = tagValues[name] != nil ? name : (legacyTags[name] ?? "gray")
        let value = tagValues[key] ?? 0x8E8C86
        return TagColor(solid: Tokens.one(value).color, tint: Tokens.one(value, opacity: 0.15).color)
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

    /// 底上那几团淡淡的颜色（从左上、右上、下面三处晕开）；ThemeColorTests 量最坏的情况：三团都叠在一处
    public static func moodWashTokens(_ tone: MoodTone) -> [ColorToken] {
        let wash = Tokens.one
        switch tone {
        case .good: return [wash(0xFFB78C, 0.50), wash(0xFFD4A8, 0.42), wash(0xFFE2C4, 0.50)]
        case .plain: return [wash(0xE8DCC8, 0.55), wash(0xFFD4A8, 0.42), wash(0xE8E0D2, 0.60)]
        case .low: return [wash(0xA9C2E8, 0.50), wash(0xBEAAFF, 0.42), wash(0xE8E0D2, 0.60)]
        case .mixed: return [wash(0xFFB78C, 0.50), wash(0xBEAAFF, 0.42), wash(0xFFE2C4, 0.50)]
        case .none: return [wash(0xE8E0D2, 0.60), wash(0xE8DCC8, 0.55), wash(0xE8E0D2, 0.60)]
        }
    }

    /// 界面用的心情底色
    public static func moodWash(_ tone: MoodTone) -> [Color] {
        moodWashTokens(tone).map(\.color)
    }
}
