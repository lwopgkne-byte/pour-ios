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

    /// 3.0 待办的时间胶囊：浅蓝底上的蓝字（到点提醒）、浅黄底上的琥珀字（过了时间、以前没做完的），小字都 ≥ 4.5
    @Test func timeCapsules() {
        #expect(contrast(Theme.Tokens.accent, on: Theme.Tokens.remindFill, ink: Self.smallText) >= 4.5, "提醒")
        #expect(contrast(Theme.Tokens.warnInk, on: Theme.Tokens.warnFill, ink: Self.smallText) >= 4.5, "过了")
        #expect(contrast(Theme.Tokens.warnInk, on: Theme.Tokens.background, ink: Self.smallText) >= 4.5, "页面底上")
    }

    /// 3.0 钱的种类标签：浅底上的小字都 ≥ 4.5（等报销蓝、借出去黄、收入绿、人情红、固定的灰）
    @Test func moneyTags() {
        #expect(contrast(Theme.Tokens.accent, on: Theme.Tokens.remindFill, ink: Self.smallText) >= 4.5, "等报销")
        #expect(contrast(Theme.Tokens.warnInk, on: Theme.Tokens.warnFill, ink: Self.smallText) >= 4.5, "借出去")
        #expect(contrast(Theme.Tokens.good, on: Theme.Tokens.goodFill, ink: Self.smallText) >= 4.5, "收入")
        #expect(contrast(Theme.Tokens.badInk, on: Theme.Tokens.badFill, ink: Self.smallText) >= 4.5, "人情")
    }

    /// 3.0 心情的五档表情：这一档的粉色圆上画的脸（图形 ≥ 3:1）；深的那档还当选中的圈、点亮的小点，在卡片上 ≥ 3
    @Test func moodBadges() {
        for level in 1...5 {
            let fill = Theme.Mood.fillToken(level).resolved(dark: false).rgb
            let ink = Theme.Mood.inkToken(level).resolved(dark: false).rgb
            #expect(ink.contrast(with: fill) >= 3, "第 \(level) 档的脸在底上不够")
        }
        #expect(contrast(Theme.Mood.fillToken(5), on: Theme.Tokens.card) >= 3, "点亮的小点")
    }

    /// 3.0 感悟：纸（正面、背面）上的字 ≥ 4.5；标签浅黄底上的字 ≥ 4.5；收藏了的星在卡片、纸上 ≥ 3
    @Test func insightPaper() {
        for paper in [Theme.Idea.paperToken, Theme.Idea.paperBackToken] {
            for (name, token) in [
                ("正文", Theme.Tokens.label), ("次要", Theme.Tokens.secondaryLabel),
                ("今天重温", Theme.Tokens.warnInk), ("能点的", Theme.Tokens.accent),
            ] {
                #expect(contrast(token, on: paper, ink: Self.smallText) >= 4.5, "\(name) 在纸上不够")
            }
            #expect(contrast(Theme.Idea.starToken, on: paper) >= 3, "星在纸上")
        }
        #expect(contrast(Theme.Idea.starToken, on: Theme.Tokens.card) >= 3, "星在卡片上")
        #expect(contrast(Theme.Tokens.warnInk, on: Theme.Tokens.warnFill, ink: Self.smallText) >= 4.5, "标签")
    }

    /// 3.0「我的」功能格子：彩色方块上的白色图标（图形 ≥ 3:1）
    @Test func hubTileIcons() {
        for token in Theme.Tile.tokens {
            let fill = token.resolved(dark: false).rgb
            #expect(RGB.white.contrast(with: fill) >= 3, "白色图标在 \(fill) 上不够")
        }
    }

    /// 弹层里的主按钮：钱、心情、感悟色的底上白字（17 号半粗）
    @Test func quickButtons() {
        for token in Theme.Quick.buttonTokens {
            let fill = token.resolved(dark: false).rgb
            #expect(RGB.white.contrast(with: fill) >= 4.5, "白字在 \(fill) 上不够")
        }
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
