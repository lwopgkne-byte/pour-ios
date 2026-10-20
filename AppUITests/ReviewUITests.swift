import XCTest

/// 回顾（2026-10-20）：列表、每日回顾、周报；跑系统的无障碍审计，截图留给自验收看。
/// 用假服务器（-uiTest）：演示数据里的回顾列表、10月18日的每日回顾、10月12日那一周的周报
final class ReviewUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testReviewPages() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        let menu = app.descendants(matching: .any)["today.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5), "画布没打开")
        menu.tap()
        app.buttons["回顾"].firstMatch.tap()
        // 标题里中文和数字之间有窄空格：按「周日」「周报」找
        let daily = app.buttons.matching(NSPredicate(format: "label CONTAINS '周日'")).firstMatch
        XCTAssertTrue(daily.waitForExistence(timeout: 5), "回顾列表没出来")
        settle()
        audit(app, "回顾列表")
        daily.tap()
        XCTAssertTrue(app.buttons["每日回顾"].waitForExistence(timeout: 5), "每日回顾没打开")
        settle()
        audit(app, "每日回顾")
        app.swipeUp(velocity: .slow)
        settle()
        audit(app, "每日回顾-下面")
        app.buttons["每日回顾"].firstMatch.tap()
        let weekly = app.buttons.matching(NSPredicate(format: "label CONTAINS '周报'")).firstMatch
        XCTAssertTrue(weekly.waitForExistence(timeout: 5), "回到列表了")
        weekly.tap()
        XCTAssertTrue(app.buttons["周报"].waitForExistence(timeout: 5), "周报没打开")
        settle()
        audit(app, "周报")
        app.swipeUp(velocity: .slow)
        settle()
        audit(app, "周报-下面")
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

    @MainActor
    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(2))
    }
}
