import PourDesign
import Testing

@Suite("颜色令牌：色值和对比度与设计规范一致")
struct PourColorTests {
    @Test func valuesMatchSpec() {
        // docs/ios/设计规范/01-颜色.md 第 2 节的原值
        #expect(PourColor.canvas.light.description == "#F6F4F0")
        #expect(PourColor.canvas.dark.description == "#0C0B0A")
        #expect(PourColor.ink.light.description == "#161513")
        #expect(PourColor.ink.dark.description == "#F6F4F0")
        #expect(PourColor.inkSecondary.light.description == "#575552")
        #expect(PourColor.inkSecondary.dark.description == "#BCBAB6")
        #expect(PourColor.qing.light.description == "#067976")
        #expect(PourColor.qing.dark.description == "#7FCAC7")
    }

    @Test func contrastMatchesSpecTable() {
        // 规范里实测的「纸上」对比度：墨 16.6、淡墨 6.8、青 4.8（亮色）
        #expect(round1(PourColor.ink.light.contrast(with: PourColor.canvas.light)) == 16.6)
        #expect(round1(PourColor.inkSecondary.light.contrast(with: PourColor.canvas.light)) == 6.8)
        #expect(round1(PourColor.qing.light.contrast(with: PourColor.canvas.light)) == 4.8)
    }

    /// 要读的文字在亮、暗两种底色上都 ≥ 4.5:1（宪法第十一条）
    @Test(arguments: [PourColor.ink, PourColor.inkSecondary, PourColor.qing])
    func readableTextOnCanvas(token: ColorToken) {
        #expect(token.light.contrast(with: PourColor.canvas.light) >= 4.5)
        #expect(token.dark.contrast(with: PourColor.canvas.dark) >= 4.5)
    }

    @Test func contrastFormulaEndpoints() {
        #expect(RGB(0x000000).contrast(with: RGB(0xFFFFFF)) == 21)
        #expect(RGB(0x777777).contrast(with: RGB(0x777777)) == 1)
    }

    private func round1(_ value: Double) -> Double { (value * 10).rounded() / 10 }
}
