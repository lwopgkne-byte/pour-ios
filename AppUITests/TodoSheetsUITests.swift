import XCTest

/// 3.0 待办的弹层和提醒（docs/3.0/01-需求文档.md 4.3–4.5、4.8；06 交互细节 2.3、2.4、2.6）：
/// 加待办边打边认、详情里点选和原地改、最大字号、提醒真的排上了、通知上点「完成」
final class TodoSheetsUITests: XCTestCase, TodoTesting {
    override func setUp() {
        continueAfterFailure = false
    }

    /// 加待办：打字时下面就认出「明天 15:00」；加上以后关掉、出现在「明天」、说一句能撤销（验收 4.8 第 3 条）
    @MainActor func testAddWithLiveParse() throws {
        let app = openTodos()
        app.buttons["todos.add"].tap()
        let field = addField(app)
        XCTAssertTrue(field.waitForExistence(timeout: 3), "加待办没打开")
        XCTAssertTrue(app.buttons["明天下午三点取快递"].exists, "没输入时没有例子")
        shot("加待办-空", of: app.screenshot())
        try AppAudit.run(app, name: "加待办")
        field.typeText("明天下午三点取快递")
        let when = app.descendants(matching: .any)["todoAdd.when"]
        XCTAssertTrue(when.waitForExistence(timeout: 3), "打字时没认出时间")
        XCTAssertTrue(when.label.contains("明天") && when.label.contains("15:00"), "认出来的不对：\(when.label)")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '会记成：取快递'")).firstMatch.exists)
        shot("加待办-认出来", of: app.screenshot())
        app.buttons["todoAdd.add"].tap()
        XCTAssertTrue(app.staticTexts["加上了：明天 15:00 取快递"].waitForExistence(timeout: 3), "加上了没说")
        // 单子是懒加载的：在屏幕外的那几行还没生成，往下翻着找
        XCTAssertTrue(find(row(app, "取快递"), in: app), "没出现在单子里")
        XCTAssertGreaterThan(row(app, "取快递").frame.minY, app.staticTexts["明天"].frame.minY, "不在明天")
    }

    /// 详情：和谁原地改；点提醒、点重复、点日子，单子里马上变
    @MainActor func testDetail() throws {
        let app = openTodos()
        row(app, "回邮件").tap()
        let title = app.descendants(matching: .any).matching(identifier: "todoDetail.title").firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 3), "详情没打开")
        shot("待办详情", of: app.screenshot())
        expandSheet(app, from: app.staticTexts["日期"].firstMatch)
        try AppAudit.run(app, name: "待办详情")
        // 和谁：原地改（原来的记录详情里就能改）
        let people = app.buttons["改和谁"]
        app.reveal(people)
        people.tap()
        let words = app.textFields["todoDetail.edit.people"]
        XCTAssertTrue(words.waitForExistence(timeout: 3), "点「改」没出来输入框")
        words.typeText("王总")
        app.buttons["改好了"].tap()
        XCTAssertTrue(app.staticTexts["王总"].waitForExistence(timeout: 3), "和谁没改上")
        app.buttons["20:00"].tap()
        app.buttons["每天"].tap()
        XCTAssertTrue(app.buttons["每天"].isSelected, "重复没选上")
        app.buttons["明天"].firstMatch.tap()
        pause()
        app.buttons["关闭"].firstMatch.tap()
        let mail = row(app, "回邮件")
        XCTAssertTrue(find(mail, in: app), "改了以后单子里找不到")
        XCTAssertTrue(waitFor(mail, labelContains: "每天"), "单子里没写每天：\(mail.label)")
        XCTAssertGreaterThan(mail.frame.minY, app.staticTexts["明天"].frame.minY, "改了明天没挪过去")
    }

    /// 最大字号（xxxLarge，App 封顶的那一档）：待办页、详情、推迟到都截下来看——不截字、不重叠（04 验收 C）。
    /// 审计说弹层里按钮上的字「字号再大会被截」是按比封顶还大的字号量的，截图核实过（2026-10-31）
    @MainActor func testLargestTextSize() throws {
        let app = openTodos(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"])
        shot("大字-待办页", of: app.screenshot())
        app.reveal(row(app, "回邮件"))
        row(app, "回邮件").tap()
        pause()
        shot("大字-详情", of: app.screenshot())
        app.swipeUp()
        pause()
        shot("大字-详情-下面", of: app.screenshot())
        app.buttons["关闭"].firstMatch.tap()
        pause()
        app.reveal(row(app, "回邮件"))
        row(app, "回邮件").swipeLeft()
        app.buttons["推迟"].tap()
        pause()
        shot("大字-推迟", of: app.screenshot())
    }

    /// 提醒是红线（验收 4.8 第 1 条）：定了时间、没做完的都排上系统通知，不用先翻到那一天；
    /// 加一件「明天上午9点交报告」，排上的马上多一条。待办页底下写着排好了几个
    @MainActor func testRemindersScheduled() throws {
        allowNotifications()
        let app = openTodos(["-remindersCheck"])
        app.swipeUp(velocity: .slow)
        let status = app.descendants(matching: .any).matching(identifier: "todos.reminders").firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 10), "待办页底下没写排好了几个提醒")
        let before = count(status.label)
        XCTAssertGreaterThan(before, 0, "一个提醒都没排上：\(status.label)")
        app.buttons["todos.add"].tap()
        let field = addField(app)
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("明天上午9点交报告")
        app.buttons["todoAdd.add"].tap()
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline, count(status.label) <= before {
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTAssertEqual(count(status.label), before + 1, "加了一件明天 9 点的，排上的没多一条：\(status.label)")
        shot("提醒排好了", of: app.screenshot())
    }

    /// 通知上点「完成」（验收 4.8 第 2 条）：加一件「1分钟后测提醒」，等通知弹出来，按住通知点「完成」，
    /// App 里马上说「完成了」——通知、按钮、发到服务器这一整条都是真的（只有服务器是假的）
    @MainActor func testNotificationDone() throws {
        allowNotifications()
        let app = openTodos(["-remindersCheck"])
        app.buttons["todos.add"].tap()
        let field = addField(app)
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("1分钟后测提醒")
        app.buttons["todoAdd.add"].tap()
        let added = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '加上了'")).firstMatch
        XCTAssertTrue(added.waitForExistence(timeout: 5))
        // 到点：通知从顶上弹出来（App 开着也弹）
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let banner = springboard.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '测提醒'"))
            .firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 130), "到点没弹通知")
        shot("通知弹出来了", of: XCUIScreen.main.screenshot())
        // 按住通知：下面出来四个按钮
        banner.press(forDuration: 1.2)
        let done = springboard.buttons["完成"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "按住通知没有「完成」")
        for action in ["10 分钟后", "1 小时后", "明天早上"] {
            XCTAssertTrue(springboard.buttons[action].exists, "通知上没有「\(action)」")
        }
        shot("通知的按钮", of: XCUIScreen.main.screenshot())
        done.tap()
        XCTAssertTrue(app.staticTexts["完成了：测提醒"].waitForExistence(timeout: 8), "点了「完成」App 里没变")
    }

    /// 「手机上排好了 3 个提醒，到点就响」→ 3
    private func count(_ label: String) -> Int {
        Int(label.filter(\.isNumber)) ?? 0
    }
}
