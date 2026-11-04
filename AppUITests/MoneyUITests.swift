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
        // 3.13a：那天的每一笔上面一行「那天和谁在一起 · 你说的感受」+「那天你还说了」
        let context = app.descendants(matching: .any)["money.dayContext"]
        XCTAssertTrue(context.waitForExistence(timeout: 3), "点一天上面没有那天的事")
        XCTAssertTrue(context.label.contains("那天和老婆、儿子在一起"), "那天和谁在一起不对：\(context.label)")
        XCTAssertTrue(context.label.contains("那天你还说了"), "没有那天你还说了")
        settle()
        audit(app, "钱-点了一天")
        scroll(app, to: picked)
        picked.tap()
        XCTAssertTrue(app.navigationBars["10月18日"].waitForExistence(timeout: 5), "一天的钱没打开")
        settle()
        audit(app, "一天的钱")
        // 右上角 › 到后一天有钱的日子（换掉这一页，返回还是回到钱）
        app.buttons["moneyDay.next"].tap()
        XCTAssertTrue(app.navigationBars["10月19日"].waitForExistence(timeout: 5), "没换到后一天")
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
        XCTAssertTrue(app.navigationBars["留意的"].waitForExistence(timeout: 5), "留意的没打开")
        XCTAssertTrue(app.buttons["watch.reimburseAll"].exists, "等报销没有「都报销了」")
        XCTAssertTrue(app.buttons["watch.repaid"].exists, "借出去的没有「已经还了」")
        settle()
        audit(app, "留意的")
        let ruler = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH '一个月里固定的钱'"))
            .firstMatch
        app.reveal(ruler)
        XCTAssertTrue(ruler.exists, "每个月固定的没有月尺")
        settle()
        audit(app, "留意的-下面")
        app.swipeUp(velocity: .slow)
        settle()
        audit(app, "留意的-最下面")
        app.navigationBars.buttons["钱"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '人情往来'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["人情往来"].waitForExistence(timeout: 5), "人情往来没打开")
        settle()
        audit(app, "人情往来")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '小李'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["和小李的来往"].waitForExistence(timeout: 5), "和小李的来往没打开")
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

    /// 一笔的详情（01 需求文档 5.5、验收 5.8 第 3 条）：只列有的、没有一行「没说」；缺的在「补充」里点了原地加；
    /// 这样东西用了几次；删除带撤销
    @MainActor func testMoneyDetail() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        app.openTile("money")
        XCTAssertTrue(app.buttons["遮住金额"].waitForExistence(timeout: 5), "钱没打开")
        let day = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '10月18日'")).firstMatch
        scroll(app, to: day)
        day.tap()
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '给儿子买运动鞋'")).firstMatch
        scroll(app, to: row)
        row.tap()
        let amount = app.buttons["moneyDetail.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 3), "一笔的详情没打开")
        XCTAssertEqual(amount.label, "¥259")
        // 旧的详情里没填的写「没说」：新的一行都不该有（后面钱主页页脚「没说的不算」那句不算）
        XCTAssertFalse(
            app.staticTexts.matching(NSPredicate(format: "label == '没说' OR label BEGINSWITH '没说'")).firstMatch.exists,
            "详情里有一行「没说」")
        XCTAssertTrue(app.staticTexts["儿子"].exists, "给谁、和谁没列出来")
        XCTAssertTrue(app.buttons["＋ 地方"].exists, "没说的地方不在「补充」里")
        XCTAssertTrue(app.buttons["moneyDetail.thing"].exists, "没有「用了几次、每次多少钱」")
        // 拉到全屏再审（半屏的系统画得略小一点，审计量字会以为被截了）
        amount.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)))
        settle()
        audit(app, "一笔的详情")
        app.buttons["＋ 地方"].tap()
        let field = app.textFields["moneyDetail.edit"]
        XCTAssertTrue(field.waitForExistence(timeout: 3), "补充地方没出来输入框")
        field.typeText("运动品牌店")
        app.buttons["好"].tap()
        let delete = app.buttons["moneyDetail.delete"]
        app.reveal(delete)
        delete.tap()
        XCTAssertTrue(app.staticTexts["已删除"].waitForExistence(timeout: 3), "删了没说")
        XCTAssertTrue(app.buttons["undoToast"].exists, "删除没有撤销")
    }

    @MainActor func testMoneyThing() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        app.openTile("money")
        XCTAssertTrue(app.buttons["遮住金额"].waitForExistence(timeout: 5), "钱没打开")
        let thing = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '空气炸锅'")).firstMatch
        // 值不值是横着滑的一排（照原型，一张 236 宽）：先滚到那一排的第一张（在屏幕里），再在那一排上往左拨到这张露出来
        let cards = app.buttons.matching(NSPredicate(format: "label CONTAINS '你说值' OR label CONTAINS '你说后悔'"))
        scroll(app, to: cards.firstMatch)
        let origin = app.coordinate(withNormalizedOffset: .zero)
        for _ in 0..<6 where thing.frame.maxX > app.frame.width - 8 {
            let row = cards.firstMatch.frame.midY
            origin.withOffset(CGVector(dx: app.frame.width * 0.85, dy: row)).press(
                forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: app.frame.width * 0.15, dy: row)),
                withVelocity: .slow, thenHoldForDuration: 0.3)
        }
        thing.tap()
        // 照原型：大标题是那样东西的名字
        XCTAssertTrue(app.navigationBars["空气炸锅"].waitForExistence(timeout: 5), "一样东西没打开")
        XCTAssertTrue(app.staticTexts["每次 ¥33"].waitForExistence(timeout: 3), "没写每次多少钱")
        settle()
        audit(app, "一样东西")
        app.swipeUp(velocity: .slow)
        settle()
        audit(app, "一样东西-下面")
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
