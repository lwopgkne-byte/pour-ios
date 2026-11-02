import XCTest

/// 回顾用手走一遍（04 验收标准 B「用手指试」在模拟器上能做的那部分）：连一台演示数据的真服务器（5288），
/// 回顾页三段、每日回顾的故事一页一页点过去（按住暂停、往下拉关掉）、周报月报的故事、「看整页」，每一步截图。
/// 平时的检查里不跑，只有给了服务器地址才跑：
/// `TEST_RUNNER_POUR_TOUR_SERVER=http://127.0.0.1:5288 xcodebuild test-without-building … -only-testing:PourUITests/ReviewJourneyUITests`
final class ReviewJourneyUITests: XCTestCase, TodoTesting {
    private let settings = ProcessInfo.processInfo.environment

    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor func testJourney() throws {
        guard let server = settings["POUR_TOUR_SERVER"], !server.isEmpty else {
            throw XCTSkip("只在连演示数据服务器时跑（TEST_RUNNER_POUR_TOUR_SERVER）")
        }
        let app = XCUIApplication()
        app.launchArguments += ["-serverURL", server, "-open", "/review"]
        app.launch()
        let tabs = app.segmentedControls["review.tabs"]
        XCTAssertTrue(tabs.waitForExistence(timeout: 15), "回顾没打开")
        // 回顾页记得上次看的是哪一段：先回到「每天」
        tabs.buttons["每天"].tap()
        pause()
        shot("回顾-1-每天", of: app.screenshot())
        story(
            app, name: "每日",
            first: app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'review.card.'")).firstMatch)
        tabs.buttons["每周"].tap()
        pause()
        shot("回顾-2-每周", of: app.screenshot())
        story(
            app, name: "周报",
            first: app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'review.card.'")).firstMatch)
        tabs.buttons["每月"].tap()
        pause()
        shot("回顾-3-每月", of: app.screenshot())
        story(
            app, name: "月报",
            first: app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'review.card.'")).firstMatch)
    }

    /// 打开一张卡的故事，点右边一页一页翻到最后（每页截图）；最后一页停着
    @MainActor private func story(_ app: XCUIApplication, name: String, first card: XCUIElement) {
        XCTAssertTrue(card.waitForExistence(timeout: 5), "\(name)没有卡片")
        card.tap()
        let close = app.buttons["story.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "\(name)的故事没打开")
        pause()
        for index in 1...8 {
            shot("故事-\(name)-\(index)", of: app.screenshot())
            if app.buttons["story.full"].exists { break }
            // 点右下角的空地方（页面上的按钮多在中间偏上）
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.88)).tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        }
        XCTAssertTrue(app.buttons["story.full"].exists, "\(name)翻不到最后一页")
        // 「看整页」：推进长页面，一屏一屏往下截；再回到回顾页
        app.buttons["story.full"].tap()
        XCTAssertFalse(close.waitForExistence(timeout: 2), "看整页没关掉故事")
        pause()
        for index in 1...6 {
            shot("整页-\(name)-\(index)", of: app.screenshot())
            app.swipeUp(velocity: .slow)
            RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        }
        app.goBack()
        XCTAssertTrue(app.segmentedControls["review.tabs"].waitForExistence(timeout: 5), "回不到回顾页")
    }
}
