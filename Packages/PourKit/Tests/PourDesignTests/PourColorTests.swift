import PourDesign
import Testing

/// 颜色令牌：色值和规范一致；对比度全部实算（宪法第十一条：要读的文字 ≥ 4.5:1，必要图形 ≥ 3:1）
@Suite("颜色令牌")
struct PourColorTests {
    /// 规范 01 第 2 节写着的原值，抽查生成的色板和令牌对得上
    @Test func valuesMatchSpec() {
        #expect(PourColor.canvas.light.rgb.description == "#F6F4F0")
        #expect(PourColor.canvas.dark.rgb.description == "#0C0B0A")
        #expect(PourColor.surface.dark.rgb.description == "#1A1917")
        #expect(PourColor.ink.light.rgb.description == "#161513")
        #expect(PourColor.inkSecondary.light.rgb.description == "#575552")
        #expect(PourColor.qing.light.rgb.description == "#067976")
        #expect(PourColor.qing.dark.rgb.description == "#7FCAC7")
        #expect(PourColor.marker.light.rgb.description == "#F6EBB1")
        #expect(PourColor.attention.light.rgb.description == "#7F5314")
        #expect(PourDomain.moss.palette.solidLight.description == "#63926D")
        #expect(PourDomain.brick.palette.textDark.description == "#F3C4BC")
    }

    @Test func contrastMatchesSpecTable() {
        // 规范里实测的数：墨 纸上 16.6、淡墨 纸上 6.8、青 纸上 4.8（亮色）
        #expect(round1(PourColor.ink.light.rgb.contrast(with: PourColor.canvas.light.rgb)) == 16.6)
        #expect(round1(PourColor.inkSecondary.light.rgb.contrast(with: PourColor.canvas.light.rgb)) == 6.8)
        #expect(round1(PourColor.qing.light.rgb.contrast(with: PourColor.canvas.light.rgb)) == 4.8)
    }

    /// 要读的文字 × 它可能落在的底色 × 亮暗 × 增强对比度：全部 ≥ 4.5
    @Test(arguments: [
        ("墨", PourColor.ink), ("淡墨", PourColor.inkSecondary), ("青", PourColor.qing),
        ("深青", PourColor.qingStrong), ("琥珀", PourColor.attention), ("危险红", PourColor.critical),
    ])
    func readableTextOnSurfaces(name: String, token: ColorToken) {
        for background in [PourColor.canvas, PourColor.surface, PourColor.surfaceRaised] {
            for isDark in [false, true] {
                for highContrast in [false, true] {
                    let text = token.resolved(dark: isDark, highContrast: highContrast).rgb
                    let bottom = background.resolved(dark: isDark, highContrast: highContrast).rgb
                    let ratio = text.contrast(with: bottom)
                    #expect(ratio >= 4.5, "\(name) \(text) 在 \(bottom) 上只有 \(ratio)（\(isDark ? "暗" : "亮")）")
                }
            }
        }
    }

    /// 带底色的地方：按钮上的字、荧光上的字、青浅底上的字、凹底上的字
    @Test func textOnFilledBackgrounds() {
        struct Pair {
            let name: String
            let text: ColorToken
            let background: ColorToken
        }
        let pairs = [
            Pair(name: "墨色按钮上的字", text: PourColor.onAction, background: PourColor.action),
            Pair(name: "荧光上的墨字", text: PourColor.ink, background: PourColor.marker),
            Pair(name: "青浅底上的墨字", text: PourColor.ink, background: PourColor.qingSoft),
            Pair(name: "凹底上的墨字", text: PourColor.ink, background: PourColor.surfaceSunken),
            Pair(name: "凹底上的淡墨", text: PourColor.inkSecondary, background: PourColor.surfaceSunken),
            Pair(name: "不能点的按钮（淡墨在按下色上）", text: PourColor.inkSecondary, background: PourColor.fillPressed),
        ]
        for pair in pairs {
            let (name, text, background) = (pair.name, pair.text, pair.background)
            for isDark in [false, true] {
                // 半透明的底（比如按下色）先叠在卡片上，算真正看到的颜色
                let bottom = background.resolved(dark: isDark)
                let shown =
                    bottom.opacity < 1
                    ? bottom.rgb.composited(opacity: bottom.opacity, over: PourColor.surface.resolved(dark: isDark).rgb)
                    : bottom.rgb
                let ratio = text.resolved(dark: isDark).rgb.contrast(with: shown)
                #expect(ratio >= 4.5, "\(name)（\(isDark ? "暗" : "亮")）只有 \(ratio)")
            }
        }
    }

    /// 领域色：实色是图形（≥ 3），浅底上的文字是文字（≥ 4.5）
    @Test(arguments: PourDomain.allCases)
    func domainColors(domain: PourDomain) {
        let palette = domain.palette
        for background in [PourColor.surface.light.rgb, PourColor.canvas.light.rgb] {
            #expect(palette.solidLight.contrast(with: background) >= 3, "\(palette.name) 实色（亮）")
        }
        #expect(palette.solidDark.contrast(with: PourColor.surface.dark.rgb) >= 3, "\(palette.name) 实色（暗）")
        #expect(palette.textLight.contrast(with: palette.bgLight) >= 4.5, "\(palette.name) 文字（亮）")
        #expect(palette.textDark.contrast(with: palette.bgDark) >= 4.5, "\(palette.name) 文字（暗）")
    }

    /// 半透明令牌：叠在底色上的结果算得对
    @Test func compositing() {
        let line = PourColor.line.light
        let shown = line.rgb.composited(opacity: line.opacity, over: PourColor.surface.light.rgb)
        #expect(shown.contrast(with: PourColor.surface.light.rgb) > 1.05)
        #expect(RGB(0x000000).composited(opacity: 0.5, over: RGB(0xFFFFFF)).description == "#808080")
    }

    /// 必要图形（图表的系列、选中、领域色点）在卡和纸上 ≥ 3:1（宪法第十一条；M1 之前只测了文字，漏了图形）
    @Test(arguments: [
        ("主系列（青）", PourColor.chartPrimary), ("对比系列（灰）", PourColor.chartSecondary),
        ("选中（墨）", PourColor.chartSelected),
    ])
    func chartGraphicsOnSurfaces(name: String, token: ColorToken) {
        for background in [PourColor.canvas, PourColor.surface] {
            for isDark in [false, true] {
                let ratio = token.resolved(dark: isDark).rgb.contrast(with: background.resolved(dark: isDark).rgb)
                #expect(ratio >= 3, "\(name) 只有 \(ratio)（\(isDark ? "暗" : "亮")）")
            }
        }
    }

    /// 钱的月历：最深的那档底色上，淡墨的日期和墨色的金额都 ≥ 4.5（亮暗）
    @Test func moneyCalendarTintKeepsTextReadable() {
        for isDark in [false, true] {
            let canvas = PourColor.canvas.resolved(dark: isDark).rgb
            let ink = PourColor.ink.resolved(dark: isDark).rgb
            let darkest = ink.composited(opacity: PourMoneyCalendar.tintRange.upperBound, over: canvas)
            for text in [PourColor.inkSecondary, PourColor.ink] {
                let ratio = text.resolved(dark: isDark).rgb.contrast(with: darkest)
                #expect(ratio >= 4.5, "月历最深的格子上只有 \(ratio)（\(isDark ? "暗" : "亮")）")
            }
        }
        #expect(PourMoneyCalendar.tint(for: 0, top: 100) == PourMoneyCalendar.tintRange.lowerBound)
        #expect(PourMoneyCalendar.tint(for: 100, top: 100) == PourMoneyCalendar.tintRange.upperBound)
    }

    @Test func moodLevelsDarkenWithBetterMood() {
        let canvas = PourColor.canvas.light.rgb
        let ratios = (1...5).map { PourColor.mood($0).light.rgb.contrast(with: canvas) }
        #expect(ratios == ratios.sorted(), "心情越好颜色越深（亮色）：\(ratios)")
    }

    @Test func contrastFormulaEndpoints() {
        #expect(RGB(0x000000).contrast(with: RGB(0xFFFFFF)) == 21)
        #expect(RGB(0x777777).contrast(with: RGB(0x777777)) == 1)
    }

    private func round1(_ value: Double) -> Double { (value * 10).rounded() / 10 }
}
