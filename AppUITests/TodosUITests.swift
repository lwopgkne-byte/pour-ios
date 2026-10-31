import XCTest

/// 3.0 待办页（docs/3.0/01-需求文档.md 4.2、4.6、4.8；06 交互细节第 2 节）：像真用户一样用手指——
/// 点圆圈、右滑完成、左滑推迟 / 删除 / 带到今天、按住出菜单、离开再回来进「已完成」、几条入口都通
final class TodosUITests: XCTestCase, TodoTesting {
    override func setUp() {
        continueAfterFailure = false
    }

    /// 分组、胶囊、底下的说明都在；读屏念得出每一行；审计
    @MainActor func testPage() throws {
        let app = openTodos()
        XCTAssertTrue(app.navigationBars["待办"].exists, "导航栏没写「待办」")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '今天 · '")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["明天"].exists, "没有「明天」")
        XCTAssertTrue(row(app, "交周报").label.contains("每周一"), "重复的没写每周一：\(row(app, "交周报").label)")
        XCTAssertTrue(row(app, "修自行车").label.contains("昨天 19:00"), "以前没做完的没写本来的日子")
        XCTAssertTrue(row(app, "给客户回电话").label.contains("王总"), "第二行没写和谁")
        shot("待办页", of: app.screenshot())
        try AppAudit.run(app, name: "待办页")
        app.swipeUp(velocity: .slow)
        pause()
        XCTAssertTrue(app.buttons["todos.done"].exists, "没有「已完成 N 件」")
        try AppAudit.run(app, name: "待办页-下面")
    }

    /// 点圆圈：勾上、划线留在原地，轻提示能撤销；离开再回来才收进「已完成」（验收 4.8 第 4 条）
    @MainActor func testDoneStaysUntilLeaving() throws {
        let app = openTodos()
        let check = circle(app, "回邮件")
        XCTAssertTrue(check.waitForExistence(timeout: 5))
        let before = row(app, "回邮件").frame.minY
        check.tap()
        XCTAssertTrue(app.staticTexts["完成了：回邮件"].waitForExistence(timeout: 3), "没说完成了")
        XCTAssertEqual(check.value as? String, "已完成")
        pause()
        XCTAssertEqual(row(app, "回邮件").frame.minY, before, accuracy: 2, "勾了以后跑走了")
        shot("勾了留在原地", of: app.screenshot())
        // 撤销：又变回没做完
        app.buttons["undoToast"].tap()
        XCTAssertTrue(waitFor(check, value: "未完成"), "撤销没变回来")
        check.tap()
        XCTAssertTrue(waitFor(check, value: "已完成"))
        // 离开再回来：收进「已完成」
        app.goBack()
        app.openTile("todos")
        XCTAssertTrue(app.staticTexts["以前没做完的"].waitForExistence(timeout: 5))
        pause()
        XCTAssertFalse(row(app, "回邮件").exists, "回来以后还在今天里")
        app.reveal(app.buttons["todos.done"])
        app.buttons["todos.done"].tap()
        XCTAssertTrue(row(app, "回邮件").waitForExistence(timeout: 3), "「已完成」里没有它")
    }

    /// 右滑完成；左滑「推迟」→ 推迟到明天早上，挪到「明天」；左滑「删除」能撤销
    @MainActor func testSwipes() throws {
        let app = openTodos()
        row(app, "给客户回电话").swipeRight()
        // 滑过一半露出绿色的「完成」，点一下（滑到底直接完成要更快的手，测试里不稳）
        let done = app.buttons["完成"]
        if done.waitForExistence(timeout: 2) { done.tap() }
        XCTAssertTrue(waitFor(circle(app, "给客户回电话"), value: "已完成"), "右滑没完成")
        row(app, "回邮件").swipeLeft()
        let later = app.buttons["推迟"]
        XCTAssertTrue(later.waitForExistence(timeout: 3), "左滑没露出「推迟」")
        XCTAssertTrue(app.buttons["删除"].exists, "左滑没露出「删除」")
        later.tap()
        let morning = app.buttons["snooze.tomorrow"]
        XCTAssertTrue(morning.waitForExistence(timeout: 3), "推迟的弹层没出来")
        XCTAssertTrue(morning.label.contains("09:00"), "选项后面没写时间：\(morning.label)")
        shot("推迟到", of: app.screenshot())
        expandSheet(app, from: app.staticTexts["推迟到"])
        try AppAudit.run(app, name: "推迟到")
        morning.tap()
        XCTAssertTrue(app.staticTexts["推迟到明天早上 09:00"].waitForExistence(timeout: 3), "没说推迟到哪")
        // 挪到了「明天」那一组（在「明天」的标题下面）
        pause()
        XCTAssertTrue(find(row(app, "回邮件"), in: app), "推迟以后找不到了")
        XCTAssertGreaterThan(row(app, "回邮件").frame.minY, app.staticTexts["明天"].frame.minY, "没挪到明天")
        // 删除：轻提示能撤销（回到最上面「以前没做完的」）
        app.swipeDown(velocity: .fast)
        app.swipeDown(velocity: .fast)
        let fee = row(app, "交水费")
        XCTAssertTrue(fee.waitForExistence(timeout: 3))
        fee.swipeLeft()
        app.buttons["删除"].tap()
        XCTAssertTrue(app.staticTexts["删了：交水费"].waitForExistence(timeout: 3), "删了没说")
        app.buttons["undoToast"].tap()
        XCTAssertTrue(row(app, "交水费").waitForExistence(timeout: 3), "撤销没放回来")
    }

    /// 以前没做完的：左滑「今天」、标题旁「全部带到今天」
    @MainActor func testCarryToToday() throws {
        let app = openTodos()
        row(app, "交水费").swipeLeft()
        let today = app.buttons["今天"]
        XCTAssertTrue(today.waitForExistence(timeout: 3), "以前没做完的左滑没有「今天」")
        today.tap()
        XCTAssertTrue(app.staticTexts["带到今天了"].waitForExistence(timeout: 3))
        app.buttons["todos.carryAll"].tap()
        XCTAssertTrue(app.staticTexts["以前没做完的"].waitForNonExistence(timeout: 3), "全部带到今天以后这一组还在")
        XCTAssertFalse(row(app, "修自行车").label.contains("昨天"), "带到今天了还写昨天")
    }

    /// 按住一行：菜单里完成、推迟到…、改时间、复制、看原话、删除；重复的删的时候问只删这一次还是以后都不要
    @MainActor func testLongPressAndRepeatDelete() throws {
        let app = openTodos()
        row(app, "吃降压药").press(forDuration: 1.0)
        for item in ["完成", "推迟到…", "改时间", "复制", "看原话", "删除"] {
            XCTAssertTrue(app.buttons[item].waitForExistence(timeout: 3), "菜单里没有「\(item)」")
        }
        shot("按住一行", of: app.screenshot())
        app.buttons["删除"].tap()
        let once = app.buttons["只删这一次"]
        XCTAssertTrue(once.waitForExistence(timeout: 3), "重复的没问只删这一次")
        XCTAssertTrue(app.buttons["以后都不要了"].exists)
        once.tap()
        XCTAssertTrue(app.staticTexts["删了这一次：吃降压药"].waitForExistence(timeout: 3), "没说删了这一次")
        // 下一次（明天）出来了
        pause()
        XCTAssertTrue(row(app, "吃降压药").exists, "下一次没出来")
    }

    /// 今天的时间线：分段换过去，有钟点的待办摆上去
    @MainActor func testTimeline() throws {
        let app = openTodos()
        app.segmentedControls["todos.mode"].buttons["今天的时间线"].tap()
        let block = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '给客户回电话'"))
            .firstMatch
        XCTAssertTrue(block.waitForExistence(timeout: 3), "时间线上没有带钟点的待办")
        shot("今天的时间线", of: app.screenshot())
        try AppAudit.run(app, name: "今天的时间线")
    }

    /// 几条路都通（01 需求文档 2.4、4.6）：画布待办卡的标题进待办页；卡片右上角「＋」、「我的」的「加待办」打开加待办；
    /// 画布上点一行打开和待办页同一个详情
    @MainActor func testEntryPoints() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest", "-todoSample"]
        app.launch()
        let title = app.buttons["card.title.todo"]
        XCTAssertTrue(title.waitForExistence(timeout: 8), "画布上没有待办卡")
        title.tap()
        XCTAssertTrue(app.navigationBars["待办"].waitForExistence(timeout: 5), "待办卡的标题没进待办页")
        app.goBack()
        let plus = app.buttons["card.quick.todo"]
        XCTAssertTrue(plus.waitForExistence(timeout: 5))
        plus.tap()
        let field = addField(app)
        XCTAssertTrue(field.waitForExistence(timeout: 3), "卡片右上角的「＋」没打开加待办")
        app.buttons["取消"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 3))
        // 画布上的一行：点了是同一个详情（不是左边的圆圈：圆圈也叫「回邮件」，点了是勾上）
        let line = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH '回邮件' AND identifier != 'todo.check'")
        ).firstMatch
        app.reveal(line)
        line.tap()
        let detail = app.descendants(matching: .any).matching(identifier: "todoDetail.title").firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 3), "画布上点一行没打开待办详情")
        app.buttons["关闭"].firstMatch.tap()
        // 「我的」的加待办
        app.buttons["today.me"].tap()
        let quick = app.buttons["hub.quick.加待办"]
        XCTAssertTrue(quick.waitForExistence(timeout: 5))
        quick.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 3), "「我的」的加待办没打开加待办")
    }
}
