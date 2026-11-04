import XCTest

/// 设置页（2026-10-19）：菜单里点「设置」打开；一屏一屏跑系统的无障碍审计，截图留给自验收看。
/// 用假服务器（-uiTest）：什么都还没设置过的样子
final class SettingsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// 3.0（第 10 步）：系统设置那样的分组列表；3.0.1 首页照原型——提醒直接开关、每一行写着现在的值；
    /// 点一行推进那一页（大模型：手机上不能填密钥）
    @MainActor func testSettingsPage() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        XCTAssertTrue(app.buttons["today.me"].waitForExistence(timeout: 10), "画布没打开")
        app.buttons["today.me"].tap()
        app.buttons["hub.settings"].tap()
        let reminders = app.buttons["settings.row.reminders"]
        XCTAssertTrue(reminders.waitForExistence(timeout: 5), "设置没打开")
        RunLoop.current.run(until: Date().addingTimeInterval(2))
        attach(app, "设置-分组")
        for group in ["提醒和通知", "记录"] {
            XCTAssertTrue(app.staticTexts[group].exists, "第一屏没有「\(group)」")
        }
        // 照原型：常用的开关就在第一层
        for name in ["每日回顾", "晚上问一句", "预警", "周报和月报"] {
            XCTAssertTrue(app.switches[name].exists, "第一层没有「\(name)」的开关")
        }
        try AppAudit.run(app, name: "设置-分组")
        // 首页照原型变长了：下面几行先滚到再点（列表是懒加载的，不在屏幕上的还没有）
        let llm = app.buttons["settings.row.llm"]
        app.reveal(llm)
        llm.tap()
        // 密钥那一行：名称下面一句「在电脑上用「Pour 设置」填」（和名称一起念）
        let keyHint = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '在电脑上用「Pour 设置」填'")).firstMatch
        XCTAssertTrue(keyHint.waitForExistence(timeout: 5), "手机上不该能填密钥")
        RunLoop.current.run(until: Date().addingTimeInterval(2))
        attach(app, "设置-大模型和用量")
        try AppAudit.run(app, name: "设置-大模型和用量")
        app.navigationBars.buttons.firstMatch.tap()
        for row in ["reminders", "data", "widgets"] {
            let button = app.buttons["settings.row.\(row)"]
            app.reveal(button)
            button.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(2.5))
            attach(app, "设置-\(row)")
            try AppAudit.run(app, name: "设置-\(row)")
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5), "返回没回到分组列表")
        }
    }

    /// 3.0 收尾：设置里点进去的几页换成了 Theme（以前是网页那套）。上面没走到的几页一页一页看，
    /// 三个详情层（处理日志、没答对的句子、你改过的地方）打开看，每一屏跑审计
    @MainActor func testSettingsDetails() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        XCTAssertTrue(app.buttons["today.me"].waitForExistence(timeout: 10), "画布没打开")
        app.buttons["today.me"].tap()
        app.buttons["hub.settings"].tap()
        let reminders = app.buttons["settings.row.reminders"]
        XCTAssertTrue(reminders.waitForExistence(timeout: 5), "设置没打开")
        for row in ["categories", "health", "phone"] {
            open(row, in: app)
            attach(app, "设置-\(row)")
            try AppAudit.run(app, name: "设置-\(row)")
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5), "返回没回到分组列表")
        }
        open("llm", in: app)
        peek("settings.llm.log", title: "处理日志", in: app)
        app.navigationBars.buttons.firstMatch.tap()
        open("eval", in: app)
        attach(app, "设置-AI表现")
        try AppAudit.run(app, name: "设置-AI表现")
        peek("settings.eval.failures", title: "没答对的句子", in: app, showing: "下午三点到四点开了个会")
        peek("settings.eval.candidates", title: "你改过的地方", in: app)
    }

    @MainActor
    private func open(_ row: String, in app: XCUIApplication) {
        let button = app.buttons["settings.row.\(row)"]
        app.reveal(button)
        button.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(2.5))
    }

    /// 点「查看」打开详情层，审计，点右上角「关闭」收起（标题和设置页那一行同名，按「关闭」认开没开）
    @MainActor
    private func peek(_ identifier: String, title: String, in app: XCUIApplication, showing text: String? = nil) {
        let look = app.buttons[identifier]
        app.reveal(look)
        XCTAssertTrue(look.exists, "没有「\(title)」的查看")
        look.tap()
        let close = app.buttons["关闭"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5), "「\(title)」没打开")
        // 拉到整页再审（停在 60% 时审计按放大字号推算，会把标题当成被截掉；关于我的详情层也是这样审的）
        let header = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(
            CGVector(dx: 0, dy: close.frame.midY))
        header.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)))
        if let text {
            let shown = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text))
                .firstMatch
            XCTAssertTrue(shown.waitForExistence(timeout: 5), "「\(title)」里没有「\(text)」")
        }
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        attach(app, "设置-\(title)")
        XCTAssertNoThrow(try AppAudit.run(app, name: "设置-\(title)"))
        close.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: close)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed, "「\(title)」没收起来")
    }

    /// 反馈（3.0 第 10 步）：我的 → 反馈：一句话 + 截图（能去掉）+ 在哪一页；发出去有轻提示
    @MainActor func testFeedback() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        XCTAssertTrue(app.buttons["today.me"].waitForExistence(timeout: 10), "画布没打开")
        app.buttons["today.me"].tap()
        let row = app.buttons["hub.row.feedback"]
        app.reveal(row)
        row.tap()
        let field = app.textFields["feedback.text"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "反馈没打开")
        XCTAssertTrue(app.switches["feedback.attach"].exists, "没有带上截图的开关")
        field.typeText("笔记库左滑有点难点")
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        attach(app, "反馈")
        try AppAudit.run(app, name: "反馈")
        app.buttons["feedback.send"].tap()
        XCTAssertTrue(app.staticTexts["收到了，谢谢"].waitForExistence(timeout: 5), "发出去没有轻提示")
    }

    /// 改提醒：关掉「预警」，开关跟着变
    @MainActor func testToggleReminder() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest", "-open", "/settings#reminders"]
        app.launch()
        // 开关在读屏里是「开关」（switch）
        let warning = app.switches["预警"].firstMatch
        XCTAssertTrue(warning.waitForExistence(timeout: 8), "找不到「预警」的开关")
        for _ in 0..<8 where !warning.isHittable { app.swipeUp(velocity: .slow) }
        let before = warning.value as? String
        warning.tap()
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != %@", before ?? ""), object: warning)
        XCTAssertEqual(XCTWaiter().wait(for: [changed], timeout: 3), .completed, "开关没变（\(before ?? "")）")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let screenshot = app.screenshot()
        let shot = XCTAttachment(screenshot: screenshot)
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        if let folder = ProcessInfo.processInfo.environment["POUR_SHOT_DIR"] {
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: folder).appending(path: "\(name).png"))
        }
    }
}
