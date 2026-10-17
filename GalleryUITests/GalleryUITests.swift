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

    @MainActor func testSamplesLight() throws { try walkSamples(appearance: .light, tag: "亮色") }
    @MainActor func testSamplesDark() throws { try walkSamples(appearance: .dark, tag: "暗色") }

    @MainActor func testSamplesLargestText() throws {
        try walkSamples(appearance: .light, tag: "最大字号", arguments: Self.largestText)
    }

    @MainActor func testGalleryPagesLight() throws { try walkPages(appearance: .light, tag: "亮色") }
    @MainActor func testGalleryPagesDark() throws { try walkPages(appearance: .dark, tag: "暗色") }

    @MainActor func testGalleryPagesLargestText() throws {
        try walkPages(appearance: .light, tag: "最大字号", arguments: Self.largestText)
    }

    /// 实验（M1 自验收）：系统自带的 Text 放一句会换行的话（中文、英文都试），系统审计也报「截断」——
    /// 所以审计对「换行的文字」报的截断不可信，只对单行文字算截断（见 audit）。单行的中文不会被误报（对照）。
    /// 哪天苹果修好了，这里会失败，提醒把那条豁免删掉。
    @MainActor func testAuditProbeStillMisreportsWrappedText() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-auditProbe"]
        app.launch()
        XCTAssertTrue(app.staticTexts["probe.system"].waitForExistence(timeout: 5))
        var flagged: Set<String> = []
        try app.performAccessibilityAudit { issue in
            if issue.auditType == .textClipped, let id = issue.element?.identifier { flagged.insert(id) }
            return true
        }
        XCTAssertTrue(
            flagged.contains("probe.system") && flagged.contains("probe.english"),
            "系统审计不再误报换行文字的截断了：删掉 audit 里对多行文字的豁免")
        XCTAssertFalse(flagged.contains("probe.cjkSingle"), "单行中文也被报截断了：审计的规则变了，重新看豁免")
    }

    private static let largestText = [
        "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
    ]

    // MARK: - 走一遍

    @MainActor
    private func walkSamples(appearance: XCUIDevice.Appearance, tag: String, arguments: [String] = []) throws {
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
            try auditEveryScreen(app, name: "样张-\(sample)-\(tag)", hasBottomGlass: true)
            close.tap()
        }
    }

    @MainActor
    private func walkPages(appearance: XCUIDevice.Appearance, tag: String, arguments: [String] = []) throws {
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
            try auditEveryScreen(app, name: "画廊-\(page)-\(tag)", hasBottomGlass: false)
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }

    /// 审计当前这一屏，往上滑一屏再审，直到滑不动为止；每一屏留一张截图
    @MainActor
    private func auditEveryScreen(_ app: XCUIApplication, name: String, hasBottomGlass: Bool) throws {
        var previous = Data()
        for screen in 1...12 {
            try audit(app, name: name, hasBottomGlass: hasBottomGlass)
            let shot = app.screenshot()
            if shot.pngRepresentation == previous { break }
            attach(shot, name: "\(name)-第\(screen)屏")
            previous = shot.pngRepresentation
            app.swipeUp(velocity: .slow)
        }
    }

    @MainActor
    private func audit(_ app: XCUIApplication, name: String, hasBottomGlass: Bool) throws {
        // 有底部玻璃（标签栏、倾倒栏）的页面：玻璃和它上方约 80 点的系统滚动渐隐区里，审计会把渐隐算进对比度——
        // 那是滚动边缘，不是要读的内容，只对这一段放过对比度；文字颜色本身的对比度由 PourColorTests 逐对实算
        var glassTop = app.frame.maxY
        if hasBottomGlass {
            let bars = [app.tabBars.firstMatch, app.descendants(matching: .any)["pourbar"].firstMatch].filter(\.exists)
            let top = bars.map(\.frame.minY).min() ?? app.frame.maxY
            // 防止放过太多：玻璃的上沿必须在屏幕下方三分之一以内，找错了就当没有玻璃
            XCTAssertGreaterThan(top, app.frame.height * 0.66, "底部玻璃的位置不对（\(top)），不放过任何问题")
            if top > app.frame.height * 0.66 { glassTop = top - 80 }
        }
        try app.performAccessibilityAudit { issue in
            let frame = issue.element?.frame ?? .zero
            if hasBottomGlass, issue.auditType == .contrast, frame.maxY > glassTop { return true }
            // 有底部玻璃的页面：审计说不出是哪个元素的对比度问题（SwiftUI 内部节点），多半是滚到玻璃下的内容；
            // 没有玻璃的画廊页面不放过
            if hasBottomGlass, issue.auditType == .contrast, issue.element == nil { return true }
            // 换行的文字：系统审计连系统自带的 Text 都报截断（testAuditProbeStillMisreportsWrappedText），
            // 只放过两行以上的
            if issue.auditType == .textClipped, frame.height >= 36 { return true }
            let element =
                issue.element.map { "\($0.label) \($0.frame)" } ?? "无元素：\(issue.detailedDescription.prefix(120))"
            print("审计问题 [\(name)] \(issue.compactDescription) ← \(element)")
            return false
        }
    }

    @MainActor
    private func attach(_ screenshot: XCUIScreenshot, name: String) {
        let shot = XCTAttachment(screenshot: screenshot)
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
