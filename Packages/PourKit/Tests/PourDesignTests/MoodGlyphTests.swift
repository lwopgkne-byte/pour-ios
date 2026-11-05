import CoreGraphics
import PourDesign
import SwiftUI
import Testing

/// 心情的五个表情（Material Symbols Rounded 的字形，ADR A36）：读出来的形状和官方 SVG 一样大、脸上的眼睛是挖空的
@Suite("心情的表情")
struct MoodGlyphTests {
    /// 960 × 960 的格子里，五个脸都是一样大的圆（官方 SVG 的外框 71.9…888.1）
    @Test(arguments: 1...5)
    func faceFillsTheBox(level: Int) {
        let box = MoodGlyph(level: level).path(in: CGRect(x: 0, y: 0, width: 960, height: 960)).boundingRect
        #expect(abs(box.minX - 71.9) < 1 && abs(box.minY - 71.9) < 1, "第 \(level) 个从 \(box.origin) 开始")
        #expect(abs(box.width - 816.2) < 1 && abs(box.height - 816.2) < 1, "第 \(level) 个有 \(box.size) 大")
    }

    /// 实心的脸、挖空的眼睛：额头上是脸，右眼正中是空的（透出底色）
    @Test(arguments: 1...5)
    func eyesAreHoles(level: Int) {
        let path = MoodGlyph(level: level).path(in: CGRect(x: 0, y: 0, width: 960, height: 960))
        #expect(path.contains(CGPoint(x: 480, y: 160)), "第 \(level) 个额头上是空的")
        #expect(!path.contains(CGPoint(x: 618, y: 400)), "第 \(level) 个右眼没挖空")
    }

    /// 放进别的大小：缩放后还在正中
    @Test func scalesIntoAnyRect() {
        let box = MoodGlyph(level: 4).path(in: CGRect(x: 10, y: 20, width: 30, height: 30)).boundingRect
        #expect(abs(box.midX - 25) < 0.1 && abs(box.midY - 35) < 0.1)
        #expect(abs(box.width - 30 * 816.2 / 960) < 0.1)
    }
}
