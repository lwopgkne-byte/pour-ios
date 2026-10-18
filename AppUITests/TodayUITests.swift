import XCTest

/// 「今天」和说一句的流程（M2a）：用假网关（-uiTest，不连网、不花钱），亮色、暗色、最大字号都走一遍，
/// 跑系统的无障碍审计，截图留给自验收看
final class TodayUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        // 放回亮色。XCTest 在主线程上调用同步的 tearDown
        MainActor.assumeIsolated { XCUIDevice.shared.appearance = .light }
    }

    @MainActor func testEmptyTodayLight() throws { try emptyToday(.light, name: "今天-空-亮色") }
    @MainActor func testEmptyTodayDark() throws { try emptyToday(.dark, name: "今天-空-暗色") }

    @MainActor func testEmptyTodayLargestText() throws {
        try emptyToday(.light, name: "今天-空-最大字号", arguments: Self.largestText)
    }

    /// 打一句 → 原话马上出现、标「整理中」→ 凝结成两条记录，吃面那条待确认
    @MainActor func testSayOneSentence() throws {
        let app = launch()
        say("早上跑了五公里 中午和小王吃面三十二", in: app)
        XCTAssertTrue(app.staticTexts["早上跑了五公里 中午和小王吃面三十二"].waitForExistence(timeout: 1), "原话没有马上出现")
        attach(app, "说一句-整理中")
        XCTAssertTrue(text(app, startingWith: "跑步 5 公里").waitForExistence(timeout: 5), "没凝结出跑步")
        XCTAssertTrue(text(app, startingWith: "吃面 · 小王").exists, "没凝结出吃面")
        XCTAssertTrue(app.staticTexts["三十二是花了 32 块吗？"].exists, "没问拿不准的那条")
        RunLoop.current.run(until: Date().addingTimeInterval(2))  // 等「刚凝结」的青色淡完
        attach(app, "说一句-凝结好")
        try AppAudit.run(app, name: "说一句-凝结好")
    }

    /// 连不上：原话留着、标「等网络」
    @MainActor func testWaitsForNetwork() throws {
        let app = launch()
        say("断网了也要记下来", in: app)
        XCTAssertTrue(app.staticTexts["等网络，联网后自动整理"].waitForExistence(timeout: 5))
        attach(app, "说一句-等网络")
    }

    /// 要人处理的问题：说清楚，能再试一次
    @MainActor func testFailedCanRetry() throws {
        let app = launch()
        say("余额不足的时候", in: app)
        XCTAssertTrue(app.staticTexts["没整理成：大模型账户余额不足。"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["receipt.retry"].exists)
        attach(app, "说一句-没整理成")
    }

    /// 打了一半收起来，草稿还在
    @MainActor func testDraftSurvivesClosing() throws {
        let app = launch()
        app.buttons["pourbar"].tap()
        let input = app.descendants(matching: .any)["pourbar.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        input.typeText("还没想好")
        app.descendants(matching: .any)["收起"].firstMatch.tap()
        XCTAssertTrue(app.buttons["pourbar"].waitForExistence(timeout: 3))
        app.buttons["pourbar"].tap()
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        XCTAssertEqual(input.value as? String, "还没想好")
    }

    // MARK: -

    private static let largestText = [
        "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
    ]

    @MainActor
    private func launch(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"] + arguments
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["today.header"].waitForExistence(timeout: 5), "「今天」没打开")
        return app
    }

    @MainActor
    private func emptyToday(_ appearance: XCUIDevice.Appearance, name: String, arguments: [String] = []) throws {
        XCUIDevice.shared.appearance = appearance
        let app = launch(arguments: arguments)
        XCTAssertTrue(app.descendants(matching: .any)["today.empty"].waitForExistence(timeout: 3), "没有空状态")
        attach(app, name)
        try AppAudit.run(app, name: name)
    }

    @MainActor
    private func say(_ text: String, in app: XCUIApplication) {
        app.buttons["pourbar"].tap()
        let field = app.descendants(matching: .any)["pourbar.input"]
        XCTAssertTrue(field.waitForExistence(timeout: 3), "打字的栏没出来")
        field.typeText(text)
        app.buttons["pourbar.send"].tap()
    }

    /// 以某段字开头的那一行（收据的一行会把名字、人、数合成一句读出来）
    @MainActor
    private func text(_ app: XCUIApplication, startingWith prefix: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
