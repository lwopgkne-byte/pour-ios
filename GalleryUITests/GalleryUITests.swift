import XCTest

/// 画廊和样张：每一屏在亮色、暗色、最大字号下都打开，**从上到下一屏一屏地**跑系统的无障碍审计
/// （审计只看屏幕上看得见的部分，不往下滑就只审了第一屏——M1 自验收发现的），留截图给自验收看。
final class GalleryUITests: XCTestCase {
    private let samples = ["today", "receipt", "about", "money", "review"]
    private let pages = ["颜色", "字", "组件", "图表", "动效和触感", "App 图标"]

    override func setUp() {
        continueAfterFailure = true
    }

    override func tearDown() {
        // 放回亮色。XCTest 在主线程上调用同步的 tearDown
        MainActor.assumeIsolated { XCUIDevice.shared.appearance = .light }
    }

    @MainActor func testSamplesLight() { walkSamples(appearance: .light, tag: "亮色") }
    @MainActor func testSamplesDark() { walkSamples(appearance: .dark, tag: "暗色") }

    @MainActor func testSamplesLargestText() {
        walkSamples(appearance: .light, tag: "最大字号", arguments: Self.largestText)
    }

    @MainActor func testGalleryPagesLight() { walkPages(appearance: .light, tag: "亮色") }
    @MainActor func testGalleryPagesDark() { walkPages(appearance: .dark, tag: "暗色") }

    @MainActor func testGalleryPagesLargestText() {
        walkPages(appearance: .light, tag: "最大字号", arguments: Self.largestText)
    }

    /// 实验（M1 自验收）：只用系统自带的 Text，看系统审计误报什么。哪天苹果修好了，这里会失败，提醒删掉对应的豁免：
    /// - 会换行的话（中文、英文都试，五种写法）一律被报「截断」——所以只对单行文字算截断（见 isProvenAuditBug）
    /// - 有的单行字明明完整显示也被报截断：「最常在一起 · 34 天」报，去掉空格、只有中文、只有英文的都不报——
    ///   所以单行字的截断，截图核实过的按原文放过（verifiedClippedMisreports），别的照样算
    /// - 系统最小的文字样式 caption2 本身被报「动态字体只支持一部分」
    @MainActor func testAuditProbeStillMisreportsWrappedText() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-auditProbe"]
        app.launch()
        XCTAssertTrue(app.staticTexts["probe.system"].waitForExistence(timeout: 5))
        var flagged: Set<String> = []
        var dynamicTypeFlagged: Set<String> = []
        var contrastFlagged: Set<String> = []
        try app.performAccessibilityAudit { issue in
            if issue.auditType == .textClipped, let id = issue.element?.identifier { flagged.insert(id) }
            if issue.auditType == .dynamicType, let id = issue.element?.identifier { dynamicTypeFlagged.insert(id) }
            if issue.auditType == .contrast, let id = issue.element?.identifier { contrastFlagged.insert(id) }
            return true
        }
        print("实验：审计报截断的是 \(flagged.sorted())；报对比度的是 \(contrastFlagged.sorted())")
        XCTAssertTrue(
            flagged.contains("probe.system") && flagged.contains("probe.english"),
            "系统审计不再误报换行文字的截断了：删掉 audit 里对多行文字的豁免")
        XCTAssertFalse(flagged.contains("probe.cjkSingle"), "单行中文也被报截断了：审计的规则变了，重新看豁免")
        XCTAssertTrue(flagged.contains("probe.single.spaceMixed"), "「最常在一起 · 34 天」不再被误报：重新看 verifiedClippedMisreports")
        XCTAssertTrue(
            flagged.isDisjoint(with: ["probe.single.noSpace", "probe.single.cjkSpace", "probe.single.latin"]),
            "更多的单行字被误报截断了：审计的规则变了，重新看豁免")
        XCTAssertTrue(dynamicTypeFlagged.contains("probe.caption2"), "系统 caption2 不再被误报：删掉 audit 里对最小字的豁免")
    }

    /// 实验（M1 自验收）：审计量对比度的两个毛病（颜色本身的对比度由 PourColorTests 逐对实算，都够）。
    /// 哪天苹果修好了，这里会失败，提醒删掉对应的豁免：
    /// - 一个字一个字的小标签：同色同号，「三」报不够、「一」和两个字的「三月」不报（最大字号时 38 点的「三」也报）
    ///   ——所以图表的星期（一到日）不算对比度（isProvenAuditBug）
    /// - 带荧光的原话块报不够；一模一样的原话块去掉荧光就不报——所以这段原话按原文放过（verifiedContrastMisreports）
    @MainActor func testAuditStillMismeasuresGlyphsAndHighlights() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-auditProbe2"]
        app.launch()
        XCTAssertTrue(app.staticTexts["probe.glyph.san"].waitForExistence(timeout: 5))
        var flagged: Set<String> = []
        try app.performAccessibilityAudit(for: .contrast) { issue in
            if let element = issue.element {
                flagged.insert(element.identifier.isEmpty ? element.label : element.identifier)
            }
            return true
        }
        print("实验：审计报对比度的是 \(flagged.sorted())")
        XCTAssertTrue(flagged.contains("probe.glyph.san"), "「三」不再被误报：删掉 isProvenAuditBug 里对星期的豁免")
        XCTAssertFalse(flagged.contains("probe.glyph.sanyue"), "两个字的标签也被报了：审计的规则变了，重新看豁免")
        XCTAssertTrue(flagged.contains(AuditProbe2Quote.highlighted), "带荧光的原话不再被误报：删掉 verifiedContrastMisreports 里的原话")
        XCTAssertFalse(flagged.contains(AuditProbe2Quote.plain), "去掉荧光的原话也被报了：重新看原话块的颜色")
    }

    /// 实验（M1 自验收）：「截断」「动态字体」两项检查只查屏幕上看得见的字（一个在页面顶上、一个在 3000 点以下，
    /// 页面在哪只报哪个）——所以要一屏一屏地审，不能一页只审一次；它们审完还会把页面挪走，所以单独审（见 auditEveryScreen）。
    /// 哪天苹果改成查整页，这里会失败，提醒改成一页只审一次
    @MainActor func testAuditOnlyChecksVisibleText() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-auditScrollProbe"]
        app.launch()
        XCTAssertTrue(app.staticTexts["probe.clippedTop"].waitForExistence(timeout: 5))
        for position in ["Top", "Bottom"] {
            for _ in 0..<12 where !app.staticTexts["probe.clipped\(position)"].isHittable { app.swipeUp() }
            for (type, expected) in [
                (XCUIAccessibilityAuditType.textClipped, "probe.clipped"), (.dynamicType, "probe.caption2"),
            ] {
                var flagged: Set<String> = []
                try app.performAccessibilityAudit(for: type) { issue in
                    if let id = issue.element?.identifier { flagged.insert(id) }
                    return true
                }
                print("实验：页面在 \(position) 时，审计报的是 \(flagged.sorted())")
                XCTAssertEqual(flagged, ["\(expected)\(position)"], "检查查的范围变了：重新看 auditEveryScreen 怎么审")
            }
        }
    }

    /// 图表的星期
    private static let weekdayGlyphs: Set<String> = ["一", "二", "三", "四", "五", "六", "日"]

    /// 系统审计报了、核实是正常的（M1 自验收报告第 4 节）：每条都写清是哪一屏、哪段字
    /// - 画廊·颜色「杏」：黑字白底，截图清楚；同一列别的领域名都不报
    /// - 画廊·字的原话块：带荧光的原话审计量不准（testAuditStillMismeasuresGlyphsAndHighlights）
    private static let verifiedContrastMisreports: Set<String> = ["杏", AuditProbe2Quote.highlighted]
    /// 画廊·颜色、画廊·组件（倾倒栏输入中）、样张·关于我（统计卡）：一行字完整显示，截图核实；
    /// 系统自带的 Text 放「最常在一起 · 34 天」也被报（testAuditProbeStillMisreportsWrappedText）
    private static let verifiedClippedMisreports: Set<String> = [
        "操作 · 按钮、链接、选中", "中午和小王吃面 三十二", "最常在一起 · 34 天",
    ]

    private static let largestText = [
        "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
    ]

    // MARK: - 走一遍

    @MainActor
    private func walkSamples(appearance: XCUIDevice.Appearance, tag: String, arguments: [String] = []) {
        XCUIDevice.shared.appearance = appearance
        let app = XCUIApplication()
        app.launchArguments += arguments
        app.launch()
        for sample in samples {
            let row = app.buttons["sample.\(sample)"].firstMatch
            for _ in 0..<4 where !row.isHittable { app.swipeUp() }  // 最大字号时下面的行在屏幕外
            XCTAssertTrue(row.waitForExistence(timeout: 5), "找不到样张 \(sample)")
            row.tap()
            let close = app.buttons["关闭样张"].firstMatch
            XCTAssertTrue(close.waitForExistence(timeout: 5), "样张 \(sample) 没打开")
            auditEveryScreen(app, name: "样张-\(sample)-\(tag)", hasBottomGlass: true)
            close.tap()
        }
    }

    @MainActor
    private func walkPages(appearance: XCUIDevice.Appearance, tag: String, arguments: [String] = []) {
        XCUIDevice.shared.appearance = appearance
        let app = XCUIApplication()
        app.launchArguments += arguments
        app.launch()
        for page in pages {
            let link = app.buttons[page].firstMatch
            for _ in 0..<4 where !link.isHittable { app.swipeUp() }
            XCTAssertTrue(link.waitForExistence(timeout: 5), "画廊里找不到「\(page)」")
            link.tap()
            XCTAssertTrue(app.navigationBars[page].waitForExistence(timeout: 5), "「\(page)」没打开")
            auditEveryScreen(app, name: "画廊-\(page)-\(tag)", hasBottomGlass: false)
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }

    /// 一屏一屏地审。每一屏三步：先截图、审不挪页面的几项（对比度等）；再单独审「截断」「动态字体」——
    /// 这两项只查屏幕上看得见的字、审完还会把页面挪走（testAuditOnlyChecksVisibleText），
    /// 所以各审各的，每一步之前 ScreenWalker 都把页面拖回这一屏。
    /// 走完以后，滚动区域里的每一段字都必须完整露出来审过一次
    @MainActor
    private func auditEveryScreen(_ app: XCUIApplication, name: String, hasBottomGlass: Bool) {
        let walker = ScreenWalker(app: app, hasBottomGlass: hasBottomGlass)
        let missing = walker.walk([
            { screen, scrolled in
                self.attach(app.screenshot(), name: "\(name)-第\(screen)屏")
                self.audit(app, name: name, scrolled: scrolled, hasBottomGlass: hasBottomGlass, types: Self.staysPut)
            },
            { _, scrolled in
                self.audit(app, name: name, scrolled: scrolled, hasBottomGlass: hasBottomGlass, types: .textClipped)
            },
            { _, scrolled in
                self.audit(app, name: name, scrolled: scrolled, hasBottomGlass: hasBottomGlass, types: .dynamicType)
            },
        ])
        XCTAssertTrue(missing.isEmpty, "「\(name)」有 \(missing.count) 段字没有完整露出来审过：\(missing.prefix(5))")
    }

    /// 审完不会挪动页面的几项
    private static let staysPut = XCUIAccessibilityAuditType.all.subtracting([.textClipped, .dynamicType])

    @MainActor
    private func auditContext(_ app: XCUIApplication, hasBottomGlass: Bool, scrolled: Bool) -> AuditContext {
        // 有底部玻璃（标签栏、倾倒栏）的页面：玻璃和它上方一小段系统滚动渐变里，审计会把渐变算进对比度——
        // 那是滚动边缘，不是要读的内容，只对这一段放过对比度；文字颜色本身的对比度由 PourColorTests 逐对实算
        var glassTop = app.frame.maxY
        if hasBottomGlass {
            let bars = [app.tabBars.firstMatch, app.descendants(matching: .any)["pourbar"].firstMatch].filter(\.exists)
            let top = bars.map(\.frame.minY).min() ?? app.frame.maxY
            // 防止放过太多：玻璃的上沿必须在屏幕下方三分之一以内，找错了就当没有玻璃
            XCTAssertGreaterThan(top, app.frame.height * 0.66, "底部玻璃的位置不对（\(top)），不放过任何问题")
            if top > app.frame.height * 0.66 { glassTop = top - ScreenWalker.bottomFade }
        }
        // 顶上的导航栏也是系统的玻璃：内容滚到它下面（和它下方一小段渐变），一样会被隔着渐变量对比度
        return AuditContext(
            hasBottomGlass: hasBottomGlass, glassTop: glassTop,
            topEdge: ScreenWalker.navigationBar(app).map { $0.frame.maxY + ScreenWalker.topFade } ?? 0,
            screenBottom: app.frame.maxY, scrolled: scrolled)
    }

    /// 跑一次审计。审计自己偶尔超时（「Audit failed to complete in time」）：等两秒重审一次，再超时就算没通过
    @MainActor
    private func audit(
        _ app: XCUIApplication, name: String, scrolled: Bool, hasBottomGlass: Bool, types: XCUIAccessibilityAuditType
    ) {
        let context = auditContext(app, hasBottomGlass: hasBottomGlass, scrolled: scrolled)
        for attempt in 1...2 {
            do {
                try app.performAccessibilityAudit(for: types) { issue in Self.judge(issue, name: name, context) }
                return
            } catch let error as NSError where error.code == -56 && attempt == 1 {
                print("审计超时，等两秒重审 [\(name)]")
                RunLoop.current.run(until: Date().addingTimeInterval(2))
            } catch {
                XCTFail("「\(name)」审计没跑完：\(error.localizedDescription)")
                return
            }
        }
    }

    /// 一条审计问题算不算数。放过的也打出来：自验收时数得清每一类放过了多少、是哪些
    @MainActor
    private static func judge(_ issue: XCUIAccessibilityAuditIssue, name: String, _ context: AuditContext) -> Bool {
        let finding = Finding(type: issue.auditType, frame: issue.element?.frame, label: issue.element?.label)
        let element =
            finding.frame.map { "\(finding.label ?? "") \($0)" } ?? "无元素：\(issue.detailedDescription.prefix(120))"
        if let reason = exemption(for: finding, context) {
            print("放过（\(reason)）[\(name)] \(issue.compactDescription) ← \(element)")
            return true
        }
        print("审计问题 [\(name)] \(issue.compactDescription) ← \(element)")
        return false
    }

    // MARK: - 哪些审计问题不算数（每一条都有证据，见 M1 自验收报告第 4 节）

    private struct AuditContext {
        let hasBottomGlass: Bool
        let glassTop: CGFloat
        let topEdge: CGFloat
        let screenBottom: CGFloat
        let scrolled: Bool
    }

    private struct Finding {
        let type: XCUIAccessibilityAuditType
        /// nil：审计说不出是哪个元素（SwiftUI 内部节点）
        let frame: CGRect?
        let label: String?
    }

    private static func exemption(for finding: Finding, _ context: AuditContext) -> String? {
        if isSystemEdge(finding, context) { return "系统边缘" }
        if isProvenAuditBug(finding) { return "审计自己的毛病" }
        if isVerifiedMisreport(finding) { return "截图核实" }
        return nil
    }

    /// 系统的玻璃和渐隐区、屏幕边缘：内容滚到那里时量出来的对比度不是要读的内容的对比度
    private static func isSystemEdge(_ finding: Finding, _ context: AuditContext) -> Bool {
        let isContrast = finding.type == .contrast
        guard let frame = finding.frame else { return false }
        if isContrast, context.hasBottomGlass, frame.maxY > context.glassTop { return true }  // 底部玻璃和它上方的渐隐
        // 顶上导航栏和它下方的渐隐：只有滑过以后内容才会在那里（第一屏那里的字照样算）
        if isContrast, context.scrolled, frame.minY < context.topEdge { return true }
        // 被屏幕下沿切掉一半的内容：只露出一部分，量出来的不算数，滑上来那一屏会再审
        return [.contrast, .textClipped].contains(finding.type) && frame.maxY > context.screenBottom
    }

    /// 系统审计自己的毛病，用实验证明过（testAuditProbeStillMisreportsWrappedText、testAuditStillMismeasuresGlyphsAndHighlights，
    /// 修好了它们会失败）
    private static func isProvenAuditBug(_ finding: Finding) -> Bool {
        guard let frame = finding.frame else { return false }
        // 图表的星期：一个字一个字的小标签，审计量不准（同色同号「三」报、「一」不报）；颜色由 PourColorTests 实算（7:1 以上）
        if finding.type == .contrast, let label = finding.label, weekdayGlyphs.contains(label) { return true }
        // 最小的字（caption2）：系统自带的 caption2 也被报「动态字体只支持一部分」——只放过一行高不超过 14 点的
        if finding.type == .dynamicType, frame.height <= 14 { return true }
        // 换行的文字：系统自带的 Text 怎么写都被报截断——只放过两行以上的（两行最小的字约 32 点高）。
        // 代价：28 点以上的大字单行被截断时审计查不出——这类标题都很短，靠截图检查
        return finding.type == .textClipped && frame.height >= 30
    }

    /// 截图核实过的误报：只按原文放过这三处，别的照样算
    private static func isVerifiedMisreport(_ finding: Finding) -> Bool {
        guard let label = finding.label else { return false }
        if finding.type == .contrast { return verifiedContrastMisreports.contains(label) }
        if finding.type == .textClipped { return verifiedClippedMisreports.contains(label) }
        return false
    }

    @MainActor
    private func attach(_ screenshot: XCUIScreenshot, name: String) {
        let shot = XCTAttachment(screenshot: screenshot)
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}

/// 实验页 2 和画廊里的原话（和 Gallery 里 AuditProbe2.quote 一样）
enum AuditProbe2Quote {
    static let highlighted = "在公司待了11个小时 有点累 太晚了打车回的 56 能报销"
    static let plain = highlighted + "。"
}
