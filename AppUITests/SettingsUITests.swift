import XCTest

/// 设置页（照网页版 1 比 1，2026-10-19）：菜单里点「设置」打开；一屏一屏跑系统的无障碍审计，截图留给自验收看。
/// 用假服务器（-uiTest）：什么都还没设置过的样子
final class SettingsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testSettingsPage() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        let menu = app.descendants(matching: .any)["today.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5), "画布没打开")
        menu.tap()
        app.buttons["设置"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["大模型"].waitForExistence(timeout: 5), "设置没打开")
        XCTAssertTrue(app.staticTexts["只能在电脑上填写"].waitForExistence(timeout: 5), "手机上不该能填密钥")
        for screen in 1...6 {
            // 等页面滚停（滚动条还在、页面还在减速时审计常常超时）
            RunLoop.current.run(until: Date().addingTimeInterval(2.5))
            attach(app, "设置-第\(screen)屏")
            try AppAudit.run(app, name: "设置-第\(screen)屏")
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(app.staticTexts["这台手机"].waitForExistence(timeout: 3), "没滚到最后「这台手机」")
    }

    /// 改提醒：关掉「预警」，开关跟着变
    @MainActor func testToggleReminder() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        app.descendants(matching: .any)["today.menu"].tap()
        app.buttons["设置"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["大模型"].waitForExistence(timeout: 5), "设置没打开")
        // 开关在读屏里是「开关」（switch）
        let warning = app.switches["预警"].firstMatch
        for _ in 0..<8 where !warning.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(warning.waitForExistence(timeout: 5), "找不到「预警」的开关")
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
