import XCTest

/// 生活画布 2.0 的样张（docs/模块/生活画布2.0.md 第 5 节）：假服务器里把今天换成几种人的一天（-canvasSample），
/// 一屏一屏截图留给验收看。上班族那天平常字号、最大的字号（封顶那一档）都一屏一屏审计；别的几种只截图（检查别太慢）
final class CanvasSampleUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testOfficeDay() throws {
        let app = launch("上班族")
        try walk(app, name: "画布2-上班族", pages: 4, audit: true)
        // 说到的：胶囊旁边写以前说到过多少（服务器数的；只说过一次又不是第一次的不写）
        XCTAssertTrue(app.buttons["小李，这周 3 天"].exists, "说到的没写这周几天")
        XCTAssertTrue(app.buttons["牛奶，第一次"].exists, "说到的没写第一次")
        XCTAssertTrue(app.buttons["老婆"].exists, "只说过一次的不该写")
    }

    /// App 的字号封顶在 xxxLarge（产品主人 2026-10-21：特别大的那几档不兼容）：开到封顶那一档看
    @MainActor func testOfficeDayBiggestText() throws {
        let app = launch("上班族", arguments: Self.biggestText)
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

    /// 画布样张（产品主人 2026-10-26：在手机的画布上看到所有功能）：不连服务器，这一周每天一种人的一天；
    /// 最上面的胶囊点一下回到服务器的数据
    @MainActor func testSampleWeek() throws {
        let app = XCUIApplication()
        // 不用 -uiTest：样张自己就用 App 里的假服务器。退出以后连一个不存在的地址，不碰电脑上真的服务器
        app.launchArguments += ["-canvasSamples", "on", "-serverURL", "http://127.0.0.1:9"]
        app.launch()
        let samples = app.buttons["canvas.samples"]
        XCTAssertTrue(samples.waitForExistence(timeout: 5), "没有样张的胶囊")
        XCTAssertTrue(todo("送车去保养", in: app).waitForExistence(timeout: 5), "今天不是上班族")
        attach(app, "样张-今天")
        app.swipeRight()
        XCTAssertTrue(todo("预约儿保", in: app).waitForExistence(timeout: 5), "昨天不是带孩子")
        attach(app, "样张-昨天")
        samples.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: samples)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed, "没退出样张")
    }

    // MARK: -

    /// 待办的勾选圆圈（做完以后那一行的字也叫这个名字，按编号找圆圈）
    @MainActor
    private func todo(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == 'todo.check' AND label == %@", name)).firstMatch
    }

    private static let biggestText = [
        "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL",
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
