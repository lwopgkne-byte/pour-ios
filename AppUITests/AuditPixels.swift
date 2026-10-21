import CoreGraphics
import UIKit
import XCTest

/// 审计说「对比度不够」时，截下那一块实量：最深和最浅的像素按 WCAG 2.2 算对比度。
/// 为什么要实量：生活画布 2.0（2026-10-21）上审计把好些清清楚楚的字报成不够——截图实量 5.6–14.7 比 1，
/// 同一排同样颜色、字号的字有的报有的不报；换成固定写法的颜色照样报（对照实验）。实量够了才放过，并把量出来的数打出来
enum AuditPixels {
    /// 要读的字至少要这么多（宪法第十一条）
    static let readable = 4.5

    /// 这一块里最深和最浅的像素之间的对比度；截不到图是 nil
    @MainActor
    static func contrast(of element: XCUIElement) -> Double? {
        guard let image = element.screenshot().image.cgImage,
            let space = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let context = CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn, !pixels.isEmpty else { return nil }
        var darkest = 1.0
        var lightest = 0.0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let value = luminance(pixels[index], pixels[index + 1], pixels[index + 2])
            darkest = min(darkest, value)
            lightest = max(lightest, value)
        }
        return (lightest + 0.05) / (darkest + 0.05)
    }

    /// WCAG 2.2 的相对亮度
    private static func luminance(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> Double {
        func linear(_ channel: UInt8) -> Double {
            let value = Double(channel) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}
