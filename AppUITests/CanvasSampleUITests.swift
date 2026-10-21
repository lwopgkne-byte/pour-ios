import XCTest

/// 生活画布 2.0 的样张（docs/模块/生活画布2.0.md 第 5 节）：假服务器里把今天换成几种人的一天（-canvasSample），
/// 一屏一屏截图留给验收看。上班族那天平常字号、最大字号都一屏一屏审计；别的几种只截图（检查别太慢）
final class CanvasSampleUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testOfficeDay() throws {
        let app = launch("上班族")
        try walk(app, name: "画布2-上班族", pages: 4, audit: true)
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

    /// 待办和提醒在最前；勾掉一条，它留在原地（产品主人 2026-10-21：勾掉以后跑到下面去是毛病）
    @MainActor func testTodoStaysOnTop() throws {
        let app = launch("上班族")
        // 勾选的圆圈（做完以后那一行的字也叫「送车去保养」，按编号找圆圈）
        let check = app.buttons.matching(NSPredicate(format: "identifier == 'todo.check' AND label == '送车去保养'"))
            .firstMatch
        XCTAssertTrue(check.waitForExistence(timeout: 5), "没有待办")
        let goals = app.staticTexts["今天推进的目标"]
        XCTAssertLessThan(check.frame.minY, goals.frame.minY, "待办不在最前面")
        let before = check.frame.minY
        check.tap()
        let done = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '已完成'"), object: check)
        XCTAssertEqual(XCTWaiter().wait(for: [done], timeout: 5), .completed, "没勾上")
        settle()
        XCTAssertEqual(check.frame.minY, before, accuracy: 1, "勾掉以后挪了位置")
        attach(app, "画布2-勾掉待办")
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
