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

    /// 目标页和「今年跑 500 公里」的详情，和网页版的 /goals、/goals?goal=1 放在一起比
    @MainActor
    func testWebDemoGoals() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["POUR_SHOTS"] == "1", "对照截图：只在手动指定时跑")
        let app = XCUIApplication()
        app.launchArguments += ["-serverURL", "http://127.0.0.1:5199"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["today.menu"].waitForExistence(timeout: 5))
        app.descendants(matching: .any)["today.menu"].tap()
        app.buttons["目标"].firstMatch.tap()
        XCTAssertTrue(app.buttons["添加目标"].waitForExistence(timeout: 5))
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        for index in 1...3 {
            shot(app, "对照-目标-\(index)")
            app.swipeUp(velocity: .slow)
            RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        }
        app.swipeDown(velocity: .fast)
        app.swipeDown(velocity: .fast)
        let run = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '今年跑 500 公里'")).firstMatch
        XCTAssertTrue(run.waitForExistence(timeout: 3))
        run.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        shot(app, "对照-目标详情-1")
        app.swipeUp(velocity: .slow)
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        shot(app, "对照-目标详情-2")
    }

    /// 回顾：列表、10月18日的每日回顾、10月12日那一周的周报，和网页版的 /review、/review/2026-10-18、/review/week/2026-10-12 比
    @MainActor
    func testWebDemoReview() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["POUR_SHOTS"] == "1", "对照截图：只在手动指定时跑")
        let app = XCUIApplication()
        app.launchArguments += ["-serverURL", "http://127.0.0.1:5199"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["today.menu"].waitForExistence(timeout: 5))
        app.descendants(matching: .any)["today.menu"].tap()
        app.buttons["回顾"].firstMatch.tap()
        // 标题里中文和数字之间有网页版那种窄空格：按「周日」找
        let daily = app.buttons.matching(NSPredicate(format: "label CONTAINS '周日'")).firstMatch
        XCTAssertTrue(daily.waitForExistence(timeout: 5))
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        shot(app, "对照-回顾列表")
        daily.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        for index in 1...4 {
            shot(app, "对照-每日回顾-\(index)")
            app.swipeUp(velocity: .slow)
            RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        }
        app.buttons["每日回顾"].firstMatch.tap()
        let weekly = app.buttons.matching(NSPredicate(format: "label CONTAINS '周报'")).firstMatch
        XCTAssertTrue(weekly.waitForExistence(timeout: 5))
        weekly.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        for index in 1...5 {
            shot(app, "对照-周报-\(index)")
            app.swipeUp(velocity: .slow)
            RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        }
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
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
