import XCTest

/// 笔记库（照网页版 1 比 1，2026-10-20）：原话、感悟、好时刻；跑系统的无障碍审计，截图留给自验收看。
/// 用假服务器（-uiTest）：网页版演示数据里最近几段原话、人物、感悟、好时刻
final class LibraryUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testLibraryViews() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        let menu = app.descendants(matching: .any)["today.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5), "画布没打开")
        menu.tap()
        app.buttons["笔记库"].firstMatch.tap()
        XCTAssertTrue(app.buttons["看这一天 →"].firstMatch.waitForExistence(timeout: 5), "原话没出来")
        settle()
        audit(app, "笔记库-原话")
        app.swipeUp(velocity: .slow)
        settle()
        audit(app, "笔记库-原话-下面")
        app.swipeDown(velocity: .fast)
        app.swipeDown(velocity: .fast)

        // 一段原话的「…」：修改、删除
        app.buttons["更多操作"].firstMatch.tap()
        XCTAssertTrue(app.buttons["删除"].waitForExistence(timeout: 3), "菜单没打开")
        app.buttons["删除"].tap()
        XCTAssertTrue(app.staticTexts["已删除这段话和它的记录"].waitForExistence(timeout: 3), "没删")

        app.buttons["感悟"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["2026年10月"].waitForExistence(timeout: 5), "感悟没出来")
        settle()
        audit(app, "笔记库-感悟")

        app.buttons["好时刻"].firstMatch.tap()
        XCTAssertTrue(
            app.staticTexts["你说过觉得好的那一刻。心情是 AI 听出来的，点开可以改。"].waitForExistence(timeout: 5), "好时刻没出来")
        settle()
        audit(app, "笔记库-好时刻")

        // 「原话」：回到原话那一栏，从那一段开始看
        app.buttons.matching(identifier: "原话").element(boundBy: 1).tap()
        XCTAssertTrue(app.buttons["看最新的"].waitForExistence(timeout: 5), "没跳到那段原话")
        settle()
        audit(app, "笔记库-来源原话")
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
