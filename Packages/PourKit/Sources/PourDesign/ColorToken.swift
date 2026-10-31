import Foundation
public import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// 一个 sRGB 颜色值（8 位），带 WCAG 2.2 的对比度计算——对比度测试和令牌检查都用它，不靠眼睛。
public struct RGB: Sendable, Hashable, CustomStringConvertible {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    /// `RGB(0xF6F4F0)`：和设计规范里写的十六进制一一对应
    public init(_ hex: UInt32) {
        red = UInt8((hex >> 16) & 0xFF)
        green = UInt8((hex >> 8) & 0xFF)
        blue = UInt8(hex & 0xFF)
    }

    init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let white = RGB(0xFFFFFF)
    public static let black = RGB(0x000000)

    public var description: String {
        let hex = (UInt32(red) << 16) | (UInt32(green) << 8) | UInt32(blue)
        let digits = String(hex, radix: 16, uppercase: true)
        return "#" + String(repeating: "0", count: 6 - digits.count) + digits
    }

    /// WCAG 2.2 的相对亮度
    public var relativeLuminance: Double {
        func linear(_ channel: UInt8) -> Double {
            let value = Double(channel) / 255
            return value <= 0.04045 ? value / 12.92 : Foundation.pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG 2.2 对比度（1–21）
    public func contrast(with other: RGB) -> Double {
        let mine = relativeLuminance
        let theirs = other.relativeLuminance
        return (max(mine, theirs) + 0.05) / (min(mine, theirs) + 0.05)
    }

    /// 半透明的这个颜色叠在 `background` 上，看起来是什么颜色（算半透明令牌的对比度用）
    public func composited(opacity: Double, over background: RGB) -> RGB {
        func mix(_ top: UInt8, _ bottom: UInt8) -> UInt8 {
            UInt8((Double(top) * opacity + Double(bottom) * (1 - opacity)).rounded())
        }
        return RGB(red: mix(red, background.red), green: mix(green, background.green), blue: mix(blue, background.blue))
    }
}

/// 一个颜色令牌：亮色、暗色各一个值，可以带透明度；「增强对比度」打开时可以换一个值。
/// 界面代码只用令牌，不写色值（docs/归档/设计规范/01-颜色.md）。
public struct ColorToken: Sendable, Hashable {
    public struct Appearance: Sendable, Hashable {
        public let rgb: RGB
        public let opacity: Double

        public init(_ rgb: RGB, opacity: Double = 1) {
            self.rgb = rgb
            self.opacity = opacity
        }
    }

    public let light: Appearance
    public let dark: Appearance
    /// 「增强对比度」打开时用的；没有就和平时一样
    public let lightHighContrast: Appearance?
    public let darkHighContrast: Appearance?

    public init(
        light: Appearance, dark: Appearance,
        lightHighContrast: Appearance? = nil, darkHighContrast: Appearance? = nil
    ) {
        self.light = light
        self.dark = dark
        self.lightHighContrast = lightHighContrast
        self.darkHighContrast = darkHighContrast
    }

    /// 不透明的令牌
    public init(light: RGB, dark: RGB, lightHighContrast: RGB? = nil, darkHighContrast: RGB? = nil) {
        self.init(
            light: Appearance(light), dark: Appearance(dark),
            lightHighContrast: lightHighContrast.map { Appearance($0) },
            darkHighContrast: darkHighContrast.map { Appearance($0) })
    }

    /// 在某种外观下实际用的值
    public func resolved(dark isDark: Bool, highContrast: Bool = false) -> Appearance {
        if isDark { return highContrast ? (darkHighContrast ?? dark) : dark }
        return highContrast ? (lightHighContrast ?? light) : light
    }

    /// 跟随系统亮暗和「增强对比度」自动切换的 SwiftUI 颜色
    public var color: Color {
        #if canImport(UIKit)
            Color(
                uiColor: UIColor { traits in
                    resolved(
                        dark: traits.userInterfaceStyle == .dark,
                        highContrast: traits.accessibilityContrast == .high
                    ).platformColor
                })
        #elseif canImport(AppKit)
            Color(
                nsColor: NSColor(name: nil) { appearance in
                    let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    return resolved(dark: isDark).platformColor
                })
        #endif
    }
}

extension ColorToken.Appearance {
    #if canImport(UIKit)
        fileprivate var platformColor: UIColor {
            UIColor(
                red: CGFloat(rgb.red) / 255, green: CGFloat(rgb.green) / 255, blue: CGFloat(rgb.blue) / 255,
                alpha: CGFloat(opacity))
        }
    #elseif canImport(AppKit)
        fileprivate var platformColor: NSColor {
            NSColor(
                srgbRed: CGFloat(rgb.red) / 255, green: CGFloat(rgb.green) / 255, blue: CGFloat(rgb.blue) / 255,
                alpha: CGFloat(opacity))
        }
    #endif
}
