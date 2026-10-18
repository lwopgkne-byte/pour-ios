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
        settle()
        attach(app, "说一句-凝结好")
        try AppAudit.run(app, name: "说一句-凝结好")
    }

    /// 收据留一会儿（测试里 3 秒）就回到时间轴：记录按钟点排在自己的位置上，带着时刻
    @MainActor func testReceiptSettlesIntoTheTimeline() throws {
        let app = launch(arguments: ["-shortReceipts"])
        say("早上跑了五公里", in: app)
        XCTAssertTrue(text(app, startingWith: "跑步 5 公里").waitForExistence(timeout: 5), "没凝结出跑步")
        XCTAssertTrue(app.staticTexts["07:10"].waitForExistence(timeout: 8), "收据没有回到时间轴")
        XCTAssertFalse(app.staticTexts["早上跑了五公里"].exists, "收据还在")
        attach(app, "说一句-回到时间轴")
        try AppAudit.run(app, name: "说一句-回到时间轴")
    }

    /// 点追问的「对」：当作说了一句「对」，那条就确认了，不再待确认（M2b）
    @MainActor func testAnswerTheQuestion() throws {
        let app = launch()
        say("中午和小王吃面三十二", in: app)
        XCTAssertTrue(app.staticTexts["三十二是花了 32 块吗？"].waitForExistence(timeout: 5))
        app.buttons["对"].firstMatch.tap()
        XCTAssertTrue(text(app, startingWith: "确认 吃面").waitForExistence(timeout: 5), "没确认")
        XCTAssertFalse(app.staticTexts["三十二是花了 32 块吗？"].exists, "还在问")
        settle()
        attach(app, "回答追问")
        try AppAudit.run(app, name: "回答追问")
    }

    /// 凝结以后 5 秒内能撤销：记录退回去，原话留着（M2b）
    @MainActor func testUndo() throws {
        let app = launch()
        say("早上跑了五公里", in: app)
        let undo = app.descendants(matching: .any)["undoToast"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "没有撤销条")
        XCTAssertTrue(undo.label.hasPrefix("已记下 1 件事"))
        app.buttons["撤销"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["已撤销 · 原话还在"].waitForExistence(timeout: 3))
        XCTAssertFalse(text(app, startingWith: "跑步 5 公里").exists)
        attach(app, "撤销")
    }

    /// 点一行看详情：原话、改动历史；点「对」确认；删除以后能撤销（M2b）
    @MainActor func testDetail() throws {
        let app = launch()
        say("中午和小王吃面三十二", in: app)
        let line = text(app, startingWith: "吃面 · 小王")
        XCTAssertTrue(line.waitForExistence(timeout: 5))
        line.tap()
        XCTAssertTrue(app.staticTexts["原话"].waitForExistence(timeout: 3), "详情没打开")
        XCTAssertTrue(app.staticTexts["中午和小王吃面三十二"].exists)
        XCTAssertTrue(text(app, startingWith: "记下").exists, "没有改动历史")
        attach(app, "详情")
        try AppAudit.run(app, name: "详情")
        app.buttons["对"].firstMatch.tap()
        XCTAssertTrue(text(app, startingWith: "确认 · 你在这里点的").waitForExistence(timeout: 3))
        app.buttons["detail.delete"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["undoToast"].waitForExistence(timeout: 3))
        XCTAssertFalse(line.exists, "删掉了还在")
        app.buttons["撤销"].firstMatch.tap()
        XCTAssertTrue(line.waitForExistence(timeout: 3), "撤销以后没回来")
    }

    /// 字调大（XXXL，还没到无障碍字号）：时间轴的时刻、收据的每一行都不被挤（截图核对）
    @MainActor func testLargeTextTimeline() throws {
        let app = launch(arguments: [
            "-shortReceipts", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL",
        ])
        say("早上跑了五公里 中午和小王吃面三十二", in: app)
        XCTAssertTrue(text(app, startingWith: "跑步 5 公里").waitForExistence(timeout: 5))
        attach(app, "特大字号-收据")
        XCTAssertTrue(app.staticTexts["07:10"].waitForExistence(timeout: 8), "收据没有回到时间轴")
        settle()
        attach(app, "特大字号-时间轴")
        try AppAudit.run(app, name: "特大字号-时间轴")
    }

    /// 换到前一天、再回来：日子头跟着变，前一天是空的（M2b）
    @MainActor func testSwitchDays() throws {
        let app = launch()
        app.buttons["前一天"].tap()
        XCTAssertTrue(app.staticTexts["昨天"].waitForExistence(timeout: 3), "没换到昨天")
        XCTAssertTrue(app.staticTexts["这一天没有记录"].exists)
        attach(app, "换日子-昨天")
        app.buttons["后一天"].tap()
        XCTAssertTrue(app.staticTexts["今天"].waitForExistence(timeout: 3), "没回到今天")
        XCTAssertFalse(app.buttons["后一天"].isEnabled, "还没到的日子不能看")
        // 在看昨天时说一句：回到今天看它凝结
        app.buttons["前一天"].tap()
        say("早上跑了五公里", in: app)
        XCTAssertTrue(text(app, startingWith: "跑步 5 公里").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["今天"].exists, "说完没回到今天")
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

    /// 等凝结的动画走完再截图、审计：逐张出现、青色浅底 1.5 秒内淡完（规范 07）；电脑忙时慢一点，留足 3 秒。
    /// 不等的话，审计量到的是正在变的颜色和位置，偶尔报出指不出元素的问题（M2b 实测）
    @MainActor
    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(3))
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
