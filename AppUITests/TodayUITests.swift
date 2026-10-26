import XCTest

/// 生活画布和说一句的流程（2026-10-19）：用假网关（-uiTest，不连网、不花钱），
/// 跑系统的无障碍审计，截图留给自验收看
final class TodayUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testEmptyCanvas() throws {
        let app = launch()
        let empty = app.staticTexts["今天还是空白。说说你做了什么，这里会自己长出来。"]
        XCTAssertTrue(empty.waitForExistence(timeout: 3), "没有空状态")
        attach(app, "画布-空")
        try AppAudit.run(app, name: "画布-空")
    }

    /// 打一句 → 对话展开、原话马上出现 → 收据「已记录：…」；收起对话，卡片里有跑步、吃面，吃面那条在问
    @MainActor func testSayOneSentence() throws {
        let app = launch()
        say("早上跑了五公里 中午和小王吃面三十二", in: app)
        XCTAssertTrue(app.staticTexts["早上跑了五公里 中午和小王吃面三十二"].waitForExistence(timeout: 1), "原话没有马上出现")
        XCTAssertTrue(text(app, startingWith: "已记录：").waitForExistence(timeout: 5), "对话里没有收据")
        settle()
        attach(app, "说一句-对话")
        closeChat(app)
        XCTAssertTrue(text(app, startingWith: "跑步").waitForExistence(timeout: 3), "卡片里没有跑步")
        XCTAssertTrue(text(app, startingWith: "吃面").exists, "卡片里没有吃面")
        XCTAssertTrue(app.staticTexts["三十二是花了 32 块吗？"].exists, "没问拿不准的那条")
        attach(app, "说一句-画布")
        try AppAudit.run(app, name: "说一句-画布")
    }

    /// 卡片里点「对」：不再问
    @MainActor func testConfirm() throws {
        let app = launch()
        say("中午和小王吃面三十二", in: app)
        closeChat(app)
        XCTAssertTrue(app.staticTexts["三十二是花了 32 块吗？"].waitForExistence(timeout: 5))
        app.buttons["对"].firstMatch.tap()
        XCTAssertTrue(waitGone(app.staticTexts["三十二是花了 32 块吗？"]), "还在问")
    }

    /// 收据后面的「撤销」：记录没了，原话还在
    @MainActor func testUndoFromReceipt() throws {
        let app = launch()
        say("早上跑了五公里", in: app)
        XCTAssertTrue(text(app, startingWith: "已记录：").waitForExistence(timeout: 5))
        app.buttons["撤销"].firstMatch.tap()
        XCTAssertTrue(waitGone(app.buttons["撤销"].firstMatch), "还能撤销")
        XCTAssertTrue(app.staticTexts["早上跑了五公里"].exists, "原话没了")
        closeChat(app)
        XCTAssertTrue(app.staticTexts["说过的话里没有整理出记录。"].waitForExistence(timeout: 3), "撤销了卡片还在")
    }

    /// 点一行看详情：原话、删掉（轻提示上能放回来）
    @MainActor func testDetail() throws {
        let app = launch()
        say("中午和小王吃面三十二", in: app)
        closeChat(app)
        let row = text(app, startingWith: "吃面")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.staticTexts["来源"].waitForExistence(timeout: 3), "详情没打开")
        attach(app, "详情")
        app.buttons["detail.delete"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["undoToast"].waitForExistence(timeout: 3))
        app.descendants(matching: .any)["undoToast"].tap()
        XCTAssertTrue(text(app, startingWith: "吃面").waitForExistence(timeout: 3), "没放回来")
    }

    /// 日期默认收起（设计评审 2026-10-23）：点顶上的日子展开这一周，再点收起
    @MainActor func testWeekOpens() throws {
        let app = launch()
        let header = app.descendants(matching: .any)["today.header"]
        let today = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '今天，'")).firstMatch
        XCTAssertFalse(today.exists, "一周条应该默认收起")
        header.tap()
        XCTAssertTrue(today.waitForExistence(timeout: 3), "点了没展开这一周")
        settle()
        attach(app, "画布-展开一周")
        try AppAudit.run(app, name: "画布-展开一周")
        header.tap()
        XCTAssertTrue(waitGone(today), "再点没收起")
    }

    /// 往右滑看昨天，往左滑回来；看昨天时说的话补记到昨天，说完留在昨天（docs/模块/产品优化.md R1.1）
    @MainActor func testSwitchDays() throws {
        let app = launch()
        app.swipeRight()
        XCTAssertTrue(showing("昨天", in: app), "没换到昨天")
        XCTAssertTrue(app.staticTexts["这一天没有留下记录。"].exists)
        app.swipeLeft()
        XCTAssertTrue(showing("今天", in: app), "没回到今天")
        app.swipeRight()
        let input = app.descendants(matching: .any)["pourbar.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        XCTAssertTrue(input.label.hasPrefix("补记"), "看昨天时输入框没写补记：\(input.label)")
        say("晚上吃了火锅", in: app)
        XCTAssertTrue(text(app, startingWith: "补记到").waitForExistence(timeout: 3), "对话里没写补记到哪天")
        attach(app, "补记-对话")
        // 说完对话会打开（画布读屏不读）：收起来看画布的大标题
        closeChat(app)
        XCTAssertTrue(showing("昨天", in: app), "补记完跳走了")
    }

    /// 连不上：原话先存在手机上，标「没有保存上 · 重试」，连上了自动发
    @MainActor func testWaitsForNetwork() throws {
        let app = launch()
        say("断网了也要记下来", in: app)
        XCTAssertTrue(app.staticTexts["断网了也要记下来"].waitForExistence(timeout: 3), "原话没留着")
        XCTAssertTrue(text(app, startingWith: "没有保存上").waitForExistence(timeout: 5))
        attach(app, "说一句-等网络")
    }

    /// 要人处理的问题：说清楚，能重试
    @MainActor func testFailedCanRetry() throws {
        let app = launch()
        say("余额不足的时候", in: app)
        XCTAssertTrue(app.staticTexts["没整理成：大模型账户余额不足。"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["重试"].exists)
        attach(app, "说一句-没整理成")
    }

    /// 打了一半，收起展开对话，草稿还在
    @MainActor func testDraftSurvives() throws {
        let app = launch()
        let input = app.descendants(matching: .any)["pourbar.input"]
        input.tap()
        input.typeText("还没想好")
        app.buttons["pourbar.chat"].tap()
        app.buttons["pourbar.chat"].tap()
        // 键盘的联想可能在后面补几个字：前面的草稿在就行
        XCTAssertTrue((input.value as? String)?.hasPrefix("还没想好") == true, "草稿没了")
    }

    /// 对话里的系统消息：「昨天的回顾好了」只是一行，点了收起对话、去「回顾」
    @MainActor func testDailyReviewInChat() throws {
        let app = launch()
        app.buttons["pourbar.chat"].tap()
        let link = text(app, startingWith: "昨天的回顾好了")
        XCTAssertTrue(link.waitForExistence(timeout: 5), "对话里没有每日回顾")
        settle()
        attach(app, "对话-每日回顾")
        try AppAudit.run(app, name: "对话-每日回顾")
        link.tap()
        XCTAssertTrue(app.buttons["每日回顾"].waitForExistence(timeout: 5), "没打开那一天的回顾")
        XCTAssertEqual(app.buttons["pourbar.chat"].label, "展开对话", "对话没收起来")
    }

    /// 斜杠命令：输入「/」列出命令，点一个填进输入框；「/撤销」撤掉最近那一段整理出的记录（不发给 AI）
    @MainActor func testSlashCommands() throws {
        let app = launch()
        say("早上跑了五公里", in: app)
        XCTAssertTrue(text(app, startingWith: "已记录：").waitForExistence(timeout: 5))
        let field = app.descendants(matching: .any)["pourbar.input"]
        field.tap()
        field.typeText("/")
        let undo = app.buttons["/撤销，撤销上一段话"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3), "没列出斜杠命令")
        attach(app, "斜杠命令")
        undo.tap()
        let filled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value BEGINSWITH '/撤销'"), object: field)
        XCTAssertEqual(XCTWaiter().wait(for: [filled], timeout: 3), .completed, "命令没填进输入框")
        app.buttons["pourbar.send"].tap()
        XCTAssertTrue(text(app, startingWith: "已撤销「早上跑了五公里」").waitForExistence(timeout: 5), "没说撤销了")
        XCTAssertFalse(app.staticTexts["/撤销"].exists, "命令不该当成一段话发出去")
    }

    // MARK: -

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["today.header"].waitForExistence(timeout: 5), "画布没打开")
        return app
    }

    @MainActor
    private func say(_ text: String, in app: XCUIApplication) {
        let field = app.descendants(matching: .any)["pourbar.input"]
        XCTAssertTrue(field.waitForExistence(timeout: 3), "输入框没有")
        field.tap()
        field.typeText(text)
        app.buttons["pourbar.send"].tap()
    }

    /// 顶上的日子胶囊写的是这一天（「今天 · 10月21日」「昨天 · 10月20日」）
    @MainActor
    private func showing(_ day: String, in app: XCUIApplication) -> Bool {
        let header = app.descendants(matching: .any)["today.header"]
        let shown = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label BEGINSWITH %@", day), object: header)
        return XCTWaiter().wait(for: [shown], timeout: 3) == .completed
    }

    /// 收起对话，看画布
    @MainActor
    private func closeChat(_ app: XCUIApplication) {
        let toggle = app.buttons["pourbar.chat"]
        if toggle.label == "收起对话" { toggle.tap() }
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == '展开对话'"), object: toggle)
        XCTAssertEqual(XCTWaiter().wait(for: [closed], timeout: 3), .completed, "对话没收起来")
        settle()
    }

    /// 等动画走完再截图、审计
    @MainActor
    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(1))
    }

    @MainActor
    private func waitGone(_ element: XCUIElement) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: 3) == .completed
    }

    /// 以某段字开头的那一个元素
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
