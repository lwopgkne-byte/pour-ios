import XCTest

/// 目标页（照网页版 1 比 1，2026-10-20）：列表、目标详情、添加目标；跑系统的无障碍审计，截图留给自验收看。
/// 用假服务器（-uiTest）：从网页版演示数据里挑的三个目标
final class GoalsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testGoalsPageAndDetail() throws {
        let app = open()
        let run = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '今年跑 500 公里'")).firstMatch
        XCTAssertTrue(run.waitForExistence(timeout: 5), "目标没列出来")
        settle()
        attach(app, "目标")
        try AppAudit.run(app, name: "目标")
        run.tap()
        XCTAssertTrue(app.staticTexts["按最近的速度，到期末大约完成 62%"].waitForExistence(timeout: 5), "目标详情没打开")
        // 拉到全屏再审：半屏的那一层系统画得略小一点（约 96%），审计量字的大小会以为字被截了
        let title = app.staticTexts["今年跑 500 公里"].firstMatch
        title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)))
        settle()
        attach(app, "目标详情")
        try AppAudit.run(app, name: "目标详情")
        app.swipeUp(velocity: .slow)
        settle()
        XCTAssertTrue(app.staticTexts["每个月"].exists, "没有每个月")
        try AppAudit.run(app, name: "目标详情-每个月")
    }

    @MainActor func testAddGoalForm() throws {
        let app = open()
        app.buttons["添加目标"].tap()
        XCTAssertTrue(app.staticTexts["种类"].waitForExistence(timeout: 3), "添加目标没打开")
        app.buttons["添加"].tap()
        XCTAssertTrue(app.staticTexts["选一个类别"].waitForExistence(timeout: 3), "没说要选类别")
        settle()
        attach(app, "添加目标")
        try AppAudit.run(app, name: "添加目标")
    }

    @MainActor
    private func open() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        let menu = app.descendants(matching: .any)["today.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5), "画布没打开")
        menu.tap()
        app.buttons["目标"].firstMatch.tap()
        XCTAssertTrue(app.buttons["添加目标"].waitForExistence(timeout: 5), "目标页没打开")
        return app
    }

    @MainActor
    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(1))
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let screenshot = app.screenshot()
        let shot = XCTAttachment(screenshot: screenshot)
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        // 开发时：TEST_RUNNER_POUR_SHOT_DIR=某个文件夹，截图也直接存一份（结果包有时存不下来）
        if let folder = ProcessInfo.processInfo.environment["POUR_SHOT_DIR"] {
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: folder).appending(path: "\(name).png"))
        }
    }
}
