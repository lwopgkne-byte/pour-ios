public import SwiftUI

/// 3.0「我的」= 全部功能的样子（docs/3.0/01-需求文档.md 2.3、06 交互细节第 7 节、可交互原型「我的」）：
/// 功能格子（白色填充图标在彩色圆角方块里，和系统「设置」一样）、角上的灰色小胶囊、管理常用时的抖动和 −、+，
/// 四个快捷大按钮。颜色只在这里定，页面只用名字
extension Theme {
    /// 功能格子的颜色：一组一个色家族（记录、回看、了解自己、钱、目标），和原型一样
    public enum Tile {
        public static let blue = Tokens.one(0x2F6FD6).color
        public static let amber = Tokens.one(0xC27E12).color
        public static let pink = Tokens.one(0xBC4A7E).color
        public static let gold = Tokens.one(0xB07A0E).color
        public static let red = Tokens.one(0xD2453B).color
        public static let indigo = Tokens.one(0x4F5FD0).color
        public static let sky = Tokens.one(0x3E7FCC).color
        public static let violet = Tokens.one(0x6B5BC7).color
        public static let rose = Tokens.one(0xC9487F).color
        public static let green = Tokens.one(0x22895A).color
        public static let purple = Tokens.one(0x8253C9).color
        public static let berry = Tokens.one(0xC2557F).color
        public static let orange = Tokens.one(0xD4682A).color
        public static let bronze = Tokens.one(0xA8741A).color
        public static let brick = Tokens.one(0xC8463A).color

        /// 对比度测试量的值（白色图标在上面至少 3:1）
        public static let tokens: [ColorToken] = [
            Tokens.one(0x2F6FD6), Tokens.one(0xC27E12), Tokens.one(0xBC4A7E), Tokens.one(0xB07A0E),
            Tokens.one(0xD2453B), Tokens.one(0x4F5FD0), Tokens.one(0x3E7FCC), Tokens.one(0x6B5BC7),
            Tokens.one(0xC9487F), Tokens.one(0x22895A), Tokens.one(0x8253C9), Tokens.one(0xC2557F),
            Tokens.one(0xD4682A), Tokens.one(0xA8741A), Tokens.one(0xC8463A),
        ]
    }

    /// 四个快捷大按钮：图标的颜色和垫在下面的浅底（记一笔、记心情、记一句、加待办）
    public enum Quick {
        public static let money = Tokens.one(0xB8740C).color
        public static let mood = Tokens.one(0xBC4A7E).color
        public static let idea = Tokens.one(0x9E6E06).color
        public static let todo = Tokens.accent.color
        /// 浅底：同一个颜色淡成一层
        public static func soft(_ color: Color) -> Color { color.opacity(0.12) }
    }
}

/// 一个功能格子的图标：彩色圆角方块里一个白色填充的 SF Symbol（44×44，圆角 12）
public struct HubTileIcon: View {
    let symbol: String
    let color: Color

    public init(symbol: String, color: Color) {
        self.symbol = symbol
        self.color = color
    }

    public var body: some View {
        Image(systemName: symbol)
            .font(Theme.Typeface.section)
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(Theme.Palette.onAccent)
            .frame(width: Theme.Size.hubIcon, height: Theme.Size.hubIcon)
            .background(color, in: Theme.rounded(Theme.Corner.hubTile))
            .accessibilityHidden(true)
    }
}

/// 格子角上的字：安静的灰底小胶囊（「留意的 2」「回顾 新」），不用红色
public struct HubBadge: View {
    let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(Theme.Typeface.glyph)
            .monospacedDigit()
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .foregroundStyle(Theme.Palette.label)
            .padding(.horizontal, Theme.Space.snug)
            .frame(minWidth: Theme.Size.badgeDot, minHeight: Theme.Size.badgeDot)
            .background(Theme.Palette.badgeFill, in: Capsule())
    }
}

/// 管理常用时格子左上角的 −（拿出来）、+（放进去）
public struct HubMark: View {
    let adding: Bool

    public init(adding: Bool) {
        self.adding = adding
    }

    public var body: some View {
        Image(systemName: adding ? "plus" : "minus")
            .font(Theme.Typeface.glyph)
            .dynamicTypeSize(...DynamicTypeSize.large)
            .foregroundStyle(Theme.Palette.onAccent)
            .frame(width: Theme.Size.badge, height: Theme.Size.badge)
            .background(adding ? Theme.Palette.accentFill : Theme.Palette.tertiaryLabel, in: Circle())
            .shadow(color: Theme.Palette.label.opacity(0.2), radius: 1.5, y: 1)
            .accessibilityHidden(true)
    }
}

extension View {
    /// 管理常用时格子轻轻抖（和主屏幕编辑时一样）；「减弱动态效果」打开时不抖
    public func hubJiggle(_ active: Bool) -> some View {
        modifier(HubJiggle(active: active))
    }
}

private struct HubJiggle: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let active: Bool
    @State private var tilt = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(active && !reduceMotion ? (tilt ? 2.2 : -2.2) : 0))
            .onChange(of: active, initial: true) { _, active in
                guard active, !reduceMotion else {
                    tilt = false
                    return
                }
                withAnimation(Theme.Motion.jiggle) { tilt = true }
            }
    }
}

/// 快捷大按钮：浅底圆角方块里一个图标，下面两三个字（「记一笔」）
public struct QuickActionLabel: View {
    let title: String
    let symbol: String
    let color: Color

    public init(_ title: String, symbol: String, color: Color) {
        self.title = title
        self.symbol = symbol
        self.color = color
    }

    public var body: some View {
        VStack(spacing: Theme.Space.small) {
            Image(systemName: symbol)
                .font(Theme.Typeface.quickIcon)
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                .foregroundStyle(color)
                .frame(width: Theme.Size.quickIcon, height: Theme.Size.quickIcon)
                .background(Theme.Quick.soft(color), in: Theme.rounded(Theme.Corner.quick))
            Text(title).font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.label)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

#Preview("我的：格子和快捷") {
    VStack(spacing: Theme.Space.xLarge) {
        HStack(spacing: Theme.Space.xLarge) {
            HubTileIcon(symbol: "checklist", color: Theme.Tile.blue)
            HubTileIcon(symbol: "yensign.circle.fill", color: Theme.Tile.amber)
                .overlay(alignment: .topTrailing) { HubBadge("2").offset(x: 8, y: -6) }
            HubTileIcon(symbol: "book.fill", color: Theme.Tile.indigo).hubJiggle(true)
                .overlay(alignment: .topLeading) { HubMark(adding: false).offset(x: -8, y: -8) }
            HubTileIcon(symbol: "flag.fill", color: Theme.Tile.green)
                .overlay(alignment: .topLeading) { HubMark(adding: true).offset(x: -8, y: -8) }
        }
        HStack {
            QuickActionLabel("记一笔", symbol: "yensign", color: Theme.Quick.money)
            QuickActionLabel("记心情", symbol: "face.smiling", color: Theme.Quick.mood)
            QuickActionLabel("记一句", symbol: "lightbulb.fill", color: Theme.Quick.idea)
            QuickActionLabel("加待办", symbol: "plus", color: Theme.Quick.todo)
        }
    }
    .padding()
    .background(Theme.Palette.background)
}
