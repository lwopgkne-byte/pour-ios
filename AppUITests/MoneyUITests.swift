import XCTest

/// 钱（2026-10-20）：主页、留意的、一天的钱、一样东西、人情往来；跑系统的无障碍审计，截图留给自验收看。
/// 用假服务器（-uiTest）：演示数据里的 10 月、留意的、10月18日的钱、空气炸锅、人情往来
final class MoneyUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testMoneyPages() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        app.openTile("money")
        let hide = app.buttons["遮住金额"]
        XCTAssertTrue(hide.waitForExistence(timeout: 5), "钱没打开")
        settle()
        audit(app, "钱")
        app.swipeUp(velocity: .slow)
        settle()
        audit(app, "钱-下面")
        app.swipeUp(velocity: .slow)
        settle()
        audit(app, "钱-最下面")

        // 遮住金额：大数变成 ¥•••
        app.swipeDown(velocity: .fast)
        app.swipeDown(velocity: .fast)
        hide.tap()
        XCTAssertTrue(app.buttons["显示金额"].waitForExistence(timeout: 3), "没遮住")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '¥•••'")).firstMatch.exists)
        app.buttons["显示金额"].tap()

        // 月历点一天：一天的钱
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '10月18日'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars.buttons["钱"].waitForExistence(timeout: 5), "一天的钱没打开")
        settle()
        audit(app, "一天的钱")
        app.navigationBars.buttons["钱"].tap()

        // 留意的
        let all = app.buttons["全部 ›"]
        scroll(app, to: all)
        all.tap()
        XCTAssertTrue(app.staticTexts["留意的"].waitForExistence(timeout: 5), "留意的没打开")
        settle()
        audit(app, "留意的")
        app.swipeUp(velocity: .slow)
        settle()
        audit(app, "留意的-下面")
        app.swipeDown(velocity: .fast)
        app.swipeDown(velocity: .fast)
        app.navigationBars.buttons["钱"].tap()

        // 人情往来、和一个人的来往
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '人情往来'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["和谁来往"].waitForExistence(timeout: 5), "人情往来没打开")
        settle()
        audit(app, "人情往来")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '小李'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars.buttons["人情往来"].waitForExistence(timeout: 5), "和小李的来往没打开")
        settle()
        audit(app, "和小李的来往")
    }

    @MainActor func testMoneyThing() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        app.openTile("money")
        XCTAssertTrue(app.buttons["遮住金额"].waitForExistence(timeout: 5), "钱没打开")
        let thing = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '空气炸锅'")).firstMatch
        scroll(app, to: thing)
        thing.tap()
        XCTAssertTrue(app.staticTexts["你怎么说它"].waitForExistence(timeout: 5), "一样东西没打开")
        settle()
        audit(app, "一样东西")
    }

    @MainActor
    private func audit(_ app: XCUIApplication, _ name: String) {
        let screenshot = app.screenshot()
        let shot = XCTAttachment(screenshot: screenshot)
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        if let folder = ProcessInfo.processInfo.environment["POUR_SHOT_DIR"] {
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: folder).appending(path: "\(name).png"))
        }
        XCTAssertNoThrow(try AppAudit.run(app, name: name))
    }

    /// 往下翻到它能点为止（最多翻 8 次）
    @MainActor
    private func scroll(_ app: XCUIApplication, to element: XCUIElement) {
        app.reveal(element)
    }

    @MainActor
    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(2))
    }
}
