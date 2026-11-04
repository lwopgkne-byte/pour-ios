import XCTest

/// 每一笔（01 需求文档 5.3、验收 5.8 第 2 条）：筛选胶囊带笔数、按天分组组头写那天花了多少、搜索（名目、人、领域、原话）、
/// 左滑「已报销」带撤销；长按「改金额」「改给谁」打开详情就在改那一样、固定的有「不算固定的」。
/// 用假服务器（-uiTest）：10 月的 9 笔（日常 6、固定 1、收入 1、等报销 1，其中人情 1）
final class MoneyEachUITests: XCTestCase, TodoTesting {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testEachPage() throws {
        let app = openEach()
        XCTAssertTrue(chip(app, "全部").label.contains("9"), "全部没写几笔：\(chip(app, "全部").label)")
        XCTAssertTrue(chip(app, "人情").label.contains("1"), "人情没写几笔")
        XCTAssertFalse(chip(app, "借出").exists, "没有借出去的也有「借出」")
        let summary = app.staticTexts["money.each.summary"]
        XCTAssertTrue(summary.label.hasPrefix("10月日常 51 笔"), "上面没写这个月日常几笔：\(summary.label)")
        let header = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH '10月18日'"))
            .firstMatch
        XCTAssertTrue(find(header, in: app), "没有 10月18日 这一组")
        XCTAssertTrue(header.label.contains("花了 ¥609"), "组头没写那天花了多少：\(header.label)")
        audit(app, "每一笔")
        app.swipeUp(velocity: .slow)
        pause()
        audit(app, "每一笔-往下翻")
        app.swipeDown(velocity: .fast)
        app.swipeDown(velocity: .fast)
        filterAndSettle(app)
        search(app)
    }

    /// 只看等报销：只剩打车回家，上面写这些一共多少；左滑「已报销」「删除」，点「已报销」轻提示能撤销
    @MainActor private func filterAndSettle(_ app: XCUIApplication) {
        chip(app, "等报销").tap()
        let taxi = moneyRow(app, "打车回家")
        XCTAssertTrue(taxi.waitForExistence(timeout: 3), "只看等报销没有打车回家")
        XCTAssertFalse(moneyRow(app, "食堂午饭").exists, "只看等报销还有别的")
        XCTAssertEqual(app.staticTexts["money.each.summary"].label, "这些 1 笔，一共 ¥56")
        pause()
        audit(app, "每一笔-等报销")
        taxi.swipeLeft()
        let done = app.buttons["已报销"]
        XCTAssertTrue(done.waitForExistence(timeout: 3), "左滑没有「已报销」")
        XCTAssertTrue(app.buttons["删除"].exists, "左滑没有「删除」")
        done.tap()
        XCTAssertTrue(app.staticTexts["报销了：打车回家"].waitForExistence(timeout: 3), "已报销没说")
        XCTAssertTrue(app.buttons["undoToast"].exists, "已报销没有撤销")
        chip(app, "全部").tap()
    }

    /// 搜「儿子」：给儿子买的、和儿子一起看的电影都在，别的不在
    @MainActor private func search(_ app: XCUIApplication) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3), "没有搜索框")
        field.tap()
        field.typeText("儿子")
        XCTAssertTrue(moneyRow(app, "给儿子买运动鞋").waitForExistence(timeout: 3), "搜儿子没搜到运动鞋")
        XCTAssertTrue(moneyRow(app, "电影票").exists, "搜儿子没搜到和儿子一起看的电影")
        XCTAssertFalse(moneyRow(app, "食堂午饭").exists, "搜儿子还有别的")
        XCTAssertEqual(app.staticTexts["money.each.summary"].label, "搜到 2 笔")
        let header = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH '10月18日'"))
            .firstMatch
        XCTAssertTrue(header.label.contains("花了 ¥609"), "搜的时候组头要写那天一共花的：\(header.label)")
        pause()
        audit(app, "每一笔-搜索")
    }

    /// 长按：看原话、改金额、改给谁、删除；「改金额」打开详情就在改金额，「改给谁」就在改给谁；固定的有「不算固定的」
    @MainActor func testLongPress() throws {
        let app = openEach()
        let shoes = moneyRow(app, "给儿子买运动鞋")
        XCTAssertTrue(find(shoes, in: app), "没有给儿子买运动鞋")
        shoes.press(forDuration: 1.2)
        for title in ["看原话", "改金额", "改给谁", "删除"] {
            XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 3), "长按没有「\(title)」")
        }
        XCTAssertFalse(app.buttons["不算固定的"].exists, "不是固定的也有「不算固定的」")
        app.buttons["改金额"].tap()
        let amount = app.textFields["moneyDetail.amountField"]
        XCTAssertTrue(amount.waitForExistence(timeout: 3), "改金额没直接进到金额")
        XCTAssertEqual(amount.value as? String, "259")
        XCTAssertTrue(focused(amount), "金额的输入框没在输入")
        // 从顶上的关闭按钮拉（按在滚动区里拉，会连内容一起往上滚）
        expandSheet(app, from: app.buttons["关闭"])
        audit(app, "一笔的详情-改金额")
        app.buttons["moneyDetail.amountSave"].tap()
        XCTAssertTrue(app.buttons["moneyDetail.amount"].waitForExistence(timeout: 3), "点「好」没改完")
        app.buttons["关闭"].tap()

        XCTAssertTrue(shoes.waitForExistence(timeout: 3))
        shoes.press(forDuration: 1.2)
        app.buttons["改给谁"].tap()
        let who = app.textFields["moneyDetail.edit"]
        XCTAssertTrue(who.waitForExistence(timeout: 3), "改给谁没直接进到给谁")
        XCTAssertEqual(who.value as? String, "儿子")
        app.buttons["关闭"].tap()

        let mortgage = moneyRow(app, "房贷")
        XCTAssertTrue(find(mortgage, in: app), "没有房贷")
        mortgage.press(forDuration: 1.2)
        let notFixed = app.buttons["不算固定的"]
        XCTAssertTrue(notFixed.waitForExistence(timeout: 3), "固定的长按没有「不算固定的」")
        notFixed.tap()
        XCTAssertTrue(app.staticTexts["不再算固定的了"].waitForExistence(timeout: 3), "不算固定的没说")
        XCTAssertTrue(app.buttons["undoToast"].exists, "不算固定的没有撤销")
    }

    /// 打开钱要面容 ID（01 需求文档 5.6；设置 → 隐私）：设置里打开，进钱先是锁着的；验不过（-moneyAuth fail）停在锁着的这一页
    @MainActor func testMoneyLock() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest", "-moneyAuth", "fail", "-open", "/settings#privacy"]
        app.launch()
        let toggle = app.switches["settings.moneyLock"]
        app.reveal(toggle)
        XCTAssertTrue(toggle.exists, "设置里没有「打开钱要面容 ID」")
        // 滚动停稳了再点：还在滑的时候点下去，开关不动（2026-11-03 全部检查里挂过一次，重跑过了）
        pause()
        toggle.tap()
        // 第一下偶尔被吞掉（2026-11-04 又挂过一次，重跑过了）：3 秒还是关着的就再点一下
        if !waitFor(toggle, value: "1") { toggle.tap() }
        XCTAssertTrue(waitFor(toggle, value: "1"), "开关没打开")
        app.openTile("money")
        XCTAssertTrue(app.staticTexts["钱锁上了"].waitForExistence(timeout: 5), "开了面容 ID，钱没锁")
        XCTAssertFalse(app.buttons["money.list"].exists, "锁着还看得见钱")
        pause()
        audit(app, "钱锁上了")
        app.buttons["moneyLock.open"].tap()
        pause()
        XCTAssertTrue(app.staticTexts["钱锁上了"].exists, "验不过也打开了")
    }

    /// 最大字号（xxxLarge，App 的上限）：主页、记一笔、每一笔、一笔的详情、留意的截图，核实不截字、不重叠
    @MainActor func testLargestTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"]
        app.launch()
        app.openTile("money")
        XCTAssertTrue(app.buttons["money.hide"].waitForExistence(timeout: 8), "钱没打开")
        pause()
        shot("大字-钱", of: app.screenshot())
        app.swipeUp(velocity: .slow)
        pause()
        shot("大字-钱-月历", of: app.screenshot())
        let record = app.buttons["money.record"]
        app.reveal(record)
        record.tap()
        XCTAssertTrue(app.staticTexts["keypad.amount"].waitForExistence(timeout: 3), "记一笔没打开")
        pause()
        shot("大字-记一笔", of: app.screenshot())
        app.buttons["sheet.close"].tap()
        let list = app.buttons["money.list"]
        app.reveal(list)
        list.tap()
        // 标题照原型写哪个月：「10月的每一笔」
        let page = app.navigationBars.matching(NSPredicate(format: "identifier ENDSWITH '的每一笔'")).firstMatch
        XCTAssertTrue(page.waitForExistence(timeout: 5), "每一笔没打开")
        pause()
        shot("大字-每一笔", of: app.screenshot())
        let shoes = moneyRow(app, "给儿子买运动鞋")
        XCTAssertTrue(find(shoes, in: app), "没有给儿子买运动鞋")
        shoes.tap()
        XCTAssertTrue(app.buttons["moneyDetail.amount"].waitForExistence(timeout: 3), "一笔的详情没打开")
        expandSheet(app, from: app.buttons["关闭"])
        shot("大字-一笔的详情", of: app.screenshot())
        app.buttons["关闭"].tap()
        app.goBack()
        let watch = app.buttons["money.watch"]
        app.reveal(watch)
        watch.tap()
        XCTAssertTrue(app.navigationBars["留意的"].waitForExistence(timeout: 5), "留意的没打开")
        pause()
        shot("大字-留意的", of: app.screenshot())
    }

    // MARK: - 共用

    /// 钱 → 每一笔
    @MainActor private func openEach() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        app.openTile("money")
        let list = app.buttons["money.list"]
        XCTAssertTrue(list.waitForExistence(timeout: 5), "钱没打开")
        list.tap()
        // 标题照原型写哪个月：「10月的每一笔」
        let page = app.navigationBars.matching(NSPredicate(format: "identifier ENDSWITH '的每一笔'")).firstMatch
        XCTAssertTrue(page.waitForExistence(timeout: 5), "每一笔没打开")
        pause()
        return app
    }

    /// 一个筛选胶囊（「全部 9」）
    @MainActor private func chip(_ app: XCUIApplication, _ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    /// 一行钱（点了打开一笔的详情的那一块）
    @MainActor private func moneyRow(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == 'money.item' AND label BEGINSWITH %@", name)).firstMatch
    }

    @MainActor private func focused(_ element: XCUIElement) -> Bool {
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            if element.value(forKey: "hasKeyboardFocus") as? Bool == true { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }

    @MainActor private func audit(_ app: XCUIApplication, _ name: String) {
        let screenshot = app.screenshot()
        shot(name, of: screenshot)
        if let folder = ProcessInfo.processInfo.environment["POUR_SHOT_DIR"] {
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: folder).appending(path: "\(name).png"))
        }
        XCTAssertNoThrow(try AppAudit.run(app, name: name))
    }
}
