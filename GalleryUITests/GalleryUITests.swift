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

    /// 实验（iPhone 15 · iOS 27.0 自验收）：一行放得下、带全角括号「（）」的字，不管什么字体都被报「截断」；
    /// 同一句换成逗号、英文的半角括号都不报——所以带全角括号的单行字不算截断（isProvenAuditBug）。
    /// 哪天苹果修好了，这里会失败，提醒删掉这条豁免
    @MainActor func testAuditProbeParentheses() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-auditProbe3"]
        app.launch()
        XCTAssertTrue(app.staticTexts["probe.paren.pour"].waitForExistence(timeout: 5))
        var flagged: Set<String> = []
        try app.performAccessibilityAudit(for: .textClipped) { issue in
            if let id = issue.element?.identifier { flagged.insert(id) }
            return true
        }
        print("实验：带括号的一行字，审计报截断的是 \(flagged.sorted())")
        XCTAssertTrue(
            flagged.isSuperset(of: [
                "probe.paren.pour", "probe.paren.footnote", "probe.paren.caption", "probe.paren.body",
            ]),
            "带全角括号的一行字不再被误报：删掉 isProvenAuditBug 里对全角括号的豁免")
        XCTAssertTrue(
            flagged.isDisjoint(with: ["probe.paren.free", "probe.paren.latin"]), "不带全角括号的也被报了：审计的规则变了，重新看豁免")
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
                self.audit(app, walker, name: name, scrolled: scrolled, types: Self.staysPut)
            },
            { _, scrolled in
                self.audit(app, walker, name: name, scrolled: scrolled, types: .textClipped)
            },
            { _, scrolled in
                self.audit(app, walker, name: name, scrolled: scrolled, types: .dynamicType)
            },
        ])
        XCTAssertTrue(missing.isEmpty, "「\(name)」有 \(missing.count) 段字没有完整露出来审过：\(missing.prefix(5))")
    }

    /// 审完不会挪动页面的几项
    private static let staysPut = XCUIAccessibilityAuditType.all.subtracting([.textClipped, .dynamicType])

    @MainActor
    private func auditContext(_ walker: ScreenWalker, scrolled: Bool) -> AuditRules.AuditContext {
        // 底部玻璃（标签栏、倾倒栏）和它往上的一段投影、导航栏和它下面的一段渐变：审计量出来的对比度不准——
        // 那是滚动边缘，不是要读的内容，只对这几段放过对比度；文字颜色本身的对比度由 PourColorTests 逐对实算
        let view = walker.viewport()
        let screenBottom = walker.screenBottom
        let hasBottomGlass = walker.hasBottomGlass
        var glassTop = screenBottom
        if hasBottomGlass {
            // 防止放过太多：玻璃的上沿必须在屏幕下方三分之一以内，找错了就当没有玻璃
            XCTAssertGreaterThan(view.upperBound, screenBottom * 0.66, "底部玻璃的位置不对（\(view.upperBound)），不放过任何问题")
            if view.upperBound > screenBottom * 0.66 { glassTop = view.upperBound - ScreenWalker.bottomFade }
        }
        return AuditRules.AuditContext(
            hasBottomGlass: hasBottomGlass, glassTop: glassTop,
            topEdge: view.lowerBound > 0 ? view.lowerBound + ScreenWalker.topFade : 0,
            screenBottom: screenBottom, scrolled: scrolled, barFrame: walker.pourBarFrame)
    }

    /// 跑一次审计。审计自己偶尔超时（「Audit failed to complete in time」，电脑同时在忙别的时更常见）：
    /// 等五秒再审，最多三次；三次都超时就算没通过
    @MainActor
    private func audit(
        _ app: XCUIApplication, _ walker: ScreenWalker, name: String, scrolled: Bool, types: XCUIAccessibilityAuditType
    ) {
        let context = auditContext(walker, scrolled: scrolled)
        for attempt in 1...3 {
            do {
                try app.performAccessibilityAudit(for: types) { issue in Self.judge(issue, name: name, context) }
                return
            } catch let error as NSError where error.code == -56 && attempt < 3 {
                print("审计超时，等五秒重审 [\(name)]")
                RunLoop.current.run(until: Date().addingTimeInterval(5))
            } catch {
                XCTFail("「\(name)」审计没跑完：\(error.localizedDescription)")
                return
            }
        }
    }

    /// 一条审计问题算不算数。放过的也打出来：自验收时数得清每一类放过了多少、是哪些
    @MainActor
    private static func judge(_ issue: XCUIAccessibilityAuditIssue, name: String, _ context: AuditRules.AuditContext)
        -> Bool
    {
        let finding = AuditRules.Finding(
            type: issue.auditType, frame: issue.element?.frame, label: issue.element?.label)
        let element =
            finding.frame.map { "\(finding.label ?? "") \($0)" } ?? "无元素：\(issue.detailedDescription.prefix(120))"
        if let reason = AuditRules.exemption(for: finding, context) {
            print("放过（\(reason)）[\(name)] \(issue.compactDescription) ← \(element)")
            return true
        }
        print("审计问题 [\(name)] \(issue.compactDescription) ← \(element)")
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
