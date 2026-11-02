import CoreGraphics
import SwiftUI
import Testing

@testable import PourDesign

/// 目标的图真的画出来了（2026-11-02 用真服务器走一遍时发现：每周的柱子在数的横轴上按比例算宽度，画出来是 0 宽，
/// 图上只剩目标的虚线）
@Suite("目标的图")
@MainActor
struct GoalChartsTests {
    @Test func weekBarsAreDrawn() throws {
        let bars = (0..<8).map { index in
            WeekBarsChart.Bar(label: "\(index + 1)", value: 6.8 + Double(index % 3) * 0.3, current: index == 7)
        }
        // 纯红当探针：数红的像素（不是界面上用的颜色）
        // swiftlint:disable:next no_hardcoded_color
        let chart = WeekBarsChart(bars: bars, line: 7.5, tint: Color(red: 1, green: 0, blue: 0)) { _ in "" }
            .frame(width: 320, height: 200)
        let renderer = ImageRenderer(content: chart)
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        // 八根柱子每根二十几点宽、一百多点高：红的像素少说也有几千个；没画出来时只有虚线（灰的）
        #expect(Self.reddish(image) > 3000)
    }

    /// 偏红的像素有几个（柱子是红的、半透明）
    private static func reddish(_ image: CGImage) -> Int {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return 0 }
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let context = CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return 0 }
        return stride(from: 0, to: pixels.count, by: 4).filter { offset in
            pixels[offset] > 80 && pixels[offset + 1] < 30 && pixels[offset + 2] < 30
        }
        .count
    }
}
