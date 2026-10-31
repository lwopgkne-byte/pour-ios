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
        firstScreen(app)
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

        pickADay(app)
        watchInline(app)
        otherPages(app)
    }

    /// 3.0 第一屏：大数、和上个月比、每天累计、预算写还能花多少、四个圆按钮
    @MainActor private func firstScreen(_ app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["钱"].exists, "导航栏没写「钱」")
        XCTAssertEqual(app.staticTexts["money.spent"].label, "¥5,924")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '少 ¥12,189'")).firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["每天累计"].exists, "没有每天累计的曲线")
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label CONTAINS '还能花 ¥64'")).firstMatch.exists, "预算没写还能花")
        for action in ["money.record", "money.list", "money.watch", "money.renqing"] {
            XCTAssertTrue(app.buttons[action].exists, "没有圆按钮 \(action)")
        }
    }

    /// 月历点一天：下面换成那天的每一笔（不跳页）；「那天 ›」进一天的钱
    @MainActor private func pickADay(_ app: XCUIApplication) {
        let day = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '10月18日'")).firstMatch
        scroll(app, to: day)
        day.tap()
        let picked = app.buttons["money.pickedDay"]
        XCTAssertTrue(picked.waitForExistence(timeout: 3), "点一天下面没出来那天的每一笔")
        XCTAssertTrue(picked.label.contains("花了 ¥609"), "那天花了多少不对：\(picked.label)")
        settle()
        audit(app, "钱-点了一天")
        scroll(app, to: picked)
        picked.tap()
        XCTAssertTrue(app.navigationBars.buttons["钱"].waitForExistence(timeout: 5), "一天的钱没打开")
        settle()
        audit(app, "一天的钱")
        app.navigationBars.buttons["钱"].tap()
    }

    /// 留意：一行一件 + 右边按钮；点「都报销了」这一行收起，轻提示能撤销
    @MainActor private func watchInline(_ app: XCUIApplication) {
        let reimburse = app.buttons["money.watch.reimburse"]
        scroll(app, to: reimburse)
        reimburse.tap()
        XCTAssertTrue(app.staticTexts["报销了：等报销"].waitForExistence(timeout: 3), "都报销了没说")
        XCTAssertTrue(app.buttons["undoToast"].exists, "没有撤销")
        settle()
        audit(app, "钱-留意")
    }

    /// 留意的、人情往来、和一个人的来往
    @MainActor private func otherPages(_ app: XCUIApplication) {
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
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '人情往来'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["和谁来往"].waitForExistence(timeout: 5), "人情往来没打开")
        settle()
        audit(app, "人情往来")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '小李'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars.buttons["人情往来"].waitForExistence(timeout: 5), "和小李的来往没打开")
        settle()
        audit(app, "和小李的来往")
    }

    /// 记一笔（01 需求文档 5.4、验收 5.8 第 1 条）：数字键盘、「你常买的」点一下连名字带价钱填好、记下；
    /// 键盘按 5、8，选「能报销」，原话就是「58 能报销」
    @MainActor func testRecordWithKeypad() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        app.openTile("money")
        let record = app.buttons["money.record"]
        XCTAssertTrue(record.waitForExistence(timeout: 5), "钱没打开")
        record.tap()
        let amount = app.staticTexts["keypad.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 3), "数字键盘没打开")
        app.buttons["午饭 25"].tap()
        XCTAssertEqual(amount.label, "¥25", "点「午饭 25」没填好价钱")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '「午饭 25」'")).firstMatch.exists)
        settle()
        audit(app, "记一笔")
        app.buttons["keypad.save"].tap()
        XCTAssertTrue(app.staticTexts["记下了：午饭 ¥25"].waitForExistence(timeout: 3), "记下了没说")
        XCTAssertTrue(app.buttons["undoToast"].exists, "没有撤销")
        // 再记一笔：键盘按 5、8，能报销
        record.tap()
        XCTAssertTrue(amount.waitForExistence(timeout: 3))
        app.buttons["keypad.5"].tap()
        app.buttons["keypad.8"].tap()
        XCTAssertEqual(amount.label, "¥58")
        app.buttons["能报销"].tap()
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '「58 能报销」'")).firstMatch.exists,
            "原话不是「58 能报销」")
        app.buttons["取消"].tap()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 3))
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
