import PourDesign
import Testing

/// 生活画布 2.0 的颜色（Theme.Tokens，只有一种样子）：对比度全部实算（要读的字 ≥ 4.5:1，角标、刻度 ≥ 3:1）。
/// 要读的字按「画出来的样子」量：字画出来比设定色浅一截（截图实量：#67645C 画成 #7A776F、#2868D0 画成 #327ED9），
/// 审计量的、眼睛看到的都是画出来的像素。按最浅的那档 85% 算
@Suite("画布 2.0 的颜色")
struct ThemeColorTests {
    /// 要读的字 × 页面底、卡片底
    @Test(arguments: [
        ("正文", Theme.Tokens.label), ("次要的字", Theme.Tokens.secondaryLabel), ("能点的字", Theme.Tokens.accent),
    ])
    func readableText(name: String, token: ColorToken) {
        for background in [Theme.Tokens.background, Theme.Tokens.card] {
            let ratio = contrast(token, on: background, ink: Self.smallText)
            #expect(ratio >= 4.5, "\(name) 在 \(background.resolved(dark: false).rgb) 上画出来只有 \(ratio)")
        }
    }

    /// 第三层字只给刻度、角标：两种底上都 ≥ 3
    @Test func tertiaryIsForTicks() {
        for background in [Theme.Tokens.background, Theme.Tokens.card] {
            #expect(contrast(Theme.Tokens.tertiaryLabel, on: background) >= 3)
        }
    }

    /// 目标的状态色写在卡片上（进度、推进了多少）：卡片底上 ≥ 4.5，页面底上 ≥ 3
    @Test(arguments: [("不落后", Theme.Tokens.good), ("稍微落后", Theme.Tokens.warn), ("落后较多", Theme.Tokens.bad)])
    func statusText(name: String, token: ColorToken) {
        #expect(contrast(token, on: Theme.Tokens.card, ink: Self.smallText) >= 4.5, "\(name) 在卡片上不够")
        #expect(contrast(token, on: Theme.Tokens.background) >= 3, "\(name) 在页面底上不够")
    }

    /// 填满的蓝色上的白字（今天那个圆、发送按钮）；气泡里的字
    @Test func filledBackgrounds() {
        let fill = Theme.Tokens.accentFill.resolved(dark: false).rgb
        let white = RGB.white.composited(opacity: Self.smallText, over: fill)
        #expect(white.contrast(with: fill) >= 4.5, "蓝底白字")
        #expect(contrast(Theme.Tokens.label, on: Theme.Tokens.bubble, ink: Self.smallText) >= 4.5)
    }

    /// 心情底色（回顾里「这一天的样子」）：上面的字只用主字色。最坏的情况（三团都叠在一处）直接放、垫了 statFill 都 ≥ 4.5
    @Test(arguments: [Theme.MoodTone.good, .plain, .low, .mixed, .none])
    func moodWashText(tone: Theme.MoodTone) {
        var bottom = Theme.Tokens.card.resolved(dark: false).rgb
        for layer in Theme.moodWashTokens(tone) {
            let top = layer.resolved(dark: false)
            bottom = top.rgb.composited(opacity: top.opacity, over: bottom)
        }
        let label = Theme.Tokens.label.resolved(dark: false).rgb
        #expect(label.composited(opacity: Self.smallText, over: bottom).contrast(with: bottom) >= 4.5, "\(tone)")
        let fill = Theme.Tokens.statFill.resolved(dark: false)
        let under = fill.rgb.composited(opacity: fill.opacity, over: bottom)
        #expect(label.composited(opacity: Self.smallText, over: under).contrast(with: under) >= 4.5, "\(tone)")
    }

    /// 字画出来最深到设定色的多少（实量最浅的那档）
    static let smallText = 0.85

    /// 半透明的令牌按叠在底上的样子算；ink 是字画出来的深度（1 是设定色本身）
    private func contrast(_ text: ColorToken, on background: ColorToken, ink: Double = 1) -> Double {
        let bottom = background.resolved(dark: false).rgb
        let top = text.resolved(dark: false)
        return top.rgb.composited(opacity: top.opacity * ink, over: bottom).contrast(with: bottom)
    }
}
