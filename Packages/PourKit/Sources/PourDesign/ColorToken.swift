import Foundation
public import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// 一个 sRGB 颜色值（8 位），带 WCAG 2.2 的对比度计算——对比度测试和以后的令牌检查都用它，不靠眼睛。
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

    public var description: String {
        let hex = (UInt32(red) << 16) | (UInt32(green) << 8) | UInt32(blue)
        let digits = String(hex, radix: 16, uppercase: true)
        return "#" + String(repeating: "0", count: 6 - digits.count) + digits
    }

    /// WCAG 2.2 的相对亮度
    public var relativeLuminance: Double {
        func linear(_ channel: UInt8) -> Double {
            let value = Double(channel) / 255
            return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055).pow(2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG 2.2 对比度（1–21）
    public func contrast(with other: RGB) -> Double {
        let (lighter, darker) =
            relativeLuminance > other.relativeLuminance
            ? (relativeLuminance, other.relativeLuminance) : (other.relativeLuminance, relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

extension Double {
    fileprivate func pow(_ exponent: Double) -> Double { Foundation.pow(self, exponent) }
}

/// 一个颜色令牌：亮色、暗色各一个值。界面代码只用令牌，不写色值（docs/ios/设计规范/01-颜色.md）。
public struct ColorToken: Sendable, Hashable {
    public let light: RGB
    public let dark: RGB

    public init(light: RGB, dark: RGB) {
        self.light = light
        self.dark = dark
    }

    /// 跟随系统亮暗自动切换的 SwiftUI 颜色
    public var color: Color {
        #if canImport(UIKit)
            Color(
                uiColor: UIColor { traits in
                    (traits.userInterfaceStyle == .dark ? dark : light).platformColor
                })
        #elseif canImport(AppKit)
            Color(
                nsColor: NSColor(name: nil) { appearance in
                    let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    return (isDark ? dark : light).platformColor
                })
        #endif
    }
}

extension RGB {
    #if canImport(UIKit)
        fileprivate var platformColor: UIColor {
            UIColor(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
        }
    #elseif canImport(AppKit)
        fileprivate var platformColor: NSColor {
            NSColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
        }
    #endif
}
