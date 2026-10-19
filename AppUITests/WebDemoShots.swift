import XCTest

/// 和网页版对照的截图（开发用，平时跳过）：TEST_RUNNER_POUR_SHOTS=1 时打开网页版演示数据的那一天，从上往下一屏一屏截
final class WebDemoShots: XCTestCase {
    @MainActor
    func testWebDemoDay() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["POUR_SHOTS"] == "1", "对照截图：只在手动指定时跑")
        let app = XCUIApplication()
        // 这台 Mac 上开着的网页版（演示数据，端口 5199）：同一天和网页版的截图放在一起比
        app.launchArguments += ["-serverURL", "http://127.0.0.1:5199", "-day", "2026-10-15"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["today.header"].waitForExistence(timeout: 5))
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        for index in 1...5 {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "对照-\(index)"
            shot.lifetime = .keepAlways
            add(shot)
            app.swipeUp(velocity: .slow)
            RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        }
        // 详情：力量训练、心情
        for (prefix, name) in [("力量训练", "对照-详情-事件"), ("挺好", "对照-详情-心情")] {
            let row = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", prefix))
                .firstMatch
            if !row.isHittable { app.swipeDown(velocity: .slow) }
            row.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(1.2))
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = name
            shot.lifetime = .keepAlways
            add(shot)
            app.buttons["关闭"].tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        }
    }

    /// 设置页：从上往下一屏一屏截，和网页版的 /settings 放在一起比
    @MainActor
    func testWebDemoSettings() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["POUR_SHOTS"] == "1", "对照截图：只在手动指定时跑")
        let app = XCUIApplication()
        app.launchArguments += ["-serverURL", "http://127.0.0.1:5199"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["today.menu"].waitForExistence(timeout: 5))
        app.descendants(matching: .any)["today.menu"].tap()
        app.buttons["设置"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["大模型"].waitForExistence(timeout: 5))
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        for index in 1...9 {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "对照-设置-\(index)"
            shot.lifetime = .keepAlways
            add(shot)
            app.swipeUp(velocity: .slow)
            RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        }
    }
}
