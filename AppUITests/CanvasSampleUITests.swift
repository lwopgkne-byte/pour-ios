import XCTest

/// 生活画布 2.0 的样张（docs/模块/生活画布2.0.md 第 5 节）：假服务器里把今天换成几种人的一天（-canvasSample），
/// 一屏一屏截图留给验收看。上班族那天亮色、深色、最大字号都一屏一屏审计；别的几种只截图（检查别太慢）
final class CanvasSampleUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testOfficeDay() throws {
        let app = launch("上班族")
        try walk(app, name: "画布2-上班族", pages: 4, audit: true)
    }

    @MainActor func testOfficeDayDark() throws {
        let app = launch("上班族", arguments: ["-dark"])
        try walk(app, name: "画布2-上班族-深色", pages: 4, audit: true)
    }

    @MainActor func testOfficeDayLargestText() throws {
        let app = launch("上班族", arguments: Self.largestText)
        try walk(app, name: "画布2-上班族-最大字号", pages: 3, audit: true)
    }

    /// 别的几种人：长出来的卡片不一样（次数、身体数据、钱的收入、只有一句感悟）
    @MainActor func testOtherDays() throws {
        for name in ["带孩子", "大学生", "退休老人", "开店", "感悟"] {
            let app = launch(name)
            try walk(app, name: "画布2-\(name)", pages: name == "感悟" ? 1 : 3, audit: false)
            app.terminate()
        }
    }

    /// 点亮点滚到那张卡；点「要你确认」滚到第一条要确认的
    @MainActor func testHighlightScrolls() throws {
        let app = launch("上班族")
        // 今天的样子里的「看书 33 页」（学习那张卡里也有一行「看书」，按编号找亮点）
        let study = app.descendants(matching: .any)["today.highlight.study"]
        XCTAssertTrue(study.waitForExistence(timeout: 5), "没有「看书」这个亮点")
        study.tap()
        settle()
        attach(app, "画布2-点亮点")
        // 学习那张卡的标题滚到了顶上的玻璃按钮下面、屏幕里面
        let header = app.descendants(matching: .any).matching(NSPredicate(format: "label == '学习'")).firstMatch
        let menu = app.descendants(matching: .any)["today.menu"]
        XCTAssertTrue(header.exists, "没有学习那张卡")
        XCTAssertGreaterThanOrEqual(header.frame.minY, menu.frame.maxY - 1, "学习那张卡被顶上的按钮盖住了")
        XCTAssertLessThan(header.frame.maxY, app.frame.maxY / 2, "没滚到学习那张卡")
    }

    // MARK: -

    private static let largestText = [
        "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
    ]

    @MainActor
    private func launch(_ sample: String, arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest", "-canvasSample", sample] + arguments
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["today.header"].waitForExistence(timeout: 5), "画布没打开")
        XCTAssertTrue(app.descendants(matching: .any)["today.hero"].waitForExistence(timeout: 5), "没有今天的样子")
        return app
    }

    /// 一屏一屏往下：截图，要审计的审一次
    @MainActor
    private func walk(_ app: XCUIApplication, name: String, pages: Int, audit: Bool) throws {
        for page in 1...pages {
            settle()
            attach(app, "\(name)-第\(page)屏")
            if audit { try AppAudit.run(app, name: "\(name)-第\(page)屏") }
            if page < pages { app.swipeUp(velocity: .slow) }
        }
    }

    /// 等动画、滚动停下来
    @MainActor
    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
