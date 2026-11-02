import XCTest

/// 设置页（2026-10-19）：菜单里点「设置」打开；一屏一屏跑系统的无障碍审计，截图留给自验收看。
/// 用假服务器（-uiTest）：什么都还没设置过的样子
final class SettingsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// 3.0（第 10 步）：系统设置那样的分组列表，第一屏看得到全部分组；点一行推进那一页（大模型：手机上不能填密钥）
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
        for group in ["提醒和通知", "记录", "隐私和数据", "AI 和用量", "这台手机"] {
            XCTAssertTrue(app.staticTexts[group].exists, "第一屏没有「\(group)」")
        }
        try AppAudit.run(app, name: "设置-分组")
        app.buttons["settings.row.llm"].tap()
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
            XCTAssertTrue(reminders.waitForExistence(timeout: 5), "返回没回到分组列表")
        }
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
