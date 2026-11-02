import XCTest

/// 笔记库（2026-10-20）：原话、好时刻（感悟 3.0 第 5 步搬成了自己的一页，InsightsUITests）；跑系统的无障碍审计，截图留给自验收看。
/// 用假服务器（-uiTest）：演示数据里最近几段原话、人物、好时刻
final class LibraryUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// 3.0（第 9 步）：按天分组的卡片、组头「看这一天 ›」；点一段展开、删除带撤销；左滑重新整理；筛选弹层带条数；好时刻
    @MainActor func testLibraryViews() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        app.openTile("library")
        let day = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'library.day.'")).firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 5), "原话没出来")
        settle()
        audit(app, "笔记库-原话")
        app.swipeUp(velocity: .slow)
        settle()
        audit(app, "笔记库-原话-下面")
        app.swipeDown(velocity: .fast)
        app.swipeDown(velocity: .fast)

        // 点一段原话：展开全文和能做的；删除带撤销
        let note = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'library.note.'")
        )
        .firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 3), "没有原话")
        note.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["library.delete"].waitForExistence(timeout: 3), "没展开")
        settle()
        audit(app, "笔记库-展开")
        app.buttons["library.delete"].tap()
        XCTAssertTrue(app.staticTexts["已删除这段话和它的记录"].waitForExistence(timeout: 3), "没删")
        XCTAssertTrue(app.buttons["undoToast"].exists, "删除没有撤销")

        // 左滑：删除、重新整理
        app.cells.element(boundBy: 2).swipeLeft()
        XCTAssertTrue(app.buttons["重新整理"].waitForExistence(timeout: 3), "左滑没有重新整理")
        app.swipeDown(velocity: .slow)

        // 筛选：时间、类别、人、状态，带条数
        app.buttons["library.filter"].tap()
        XCTAssertTrue(app.buttons["filter.done"].waitForExistence(timeout: 5), "筛选没打开")
        settle()
        audit(app, "笔记库-筛选")
        app.buttons["filter.done"].tap()

        app.buttons["好时刻"].firstMatch.tap()
        XCTAssertTrue(
            app.staticTexts["你说过觉得好的那一刻。心情是 AI 听出来的，点开可以改。"].waitForExistence(timeout: 5), "好时刻没出来")
        settle()
        audit(app, "笔记库-好时刻")

        // 「原话」：回到原话那一栏，从那一段开始看
        app.buttons.matching(identifier: "原话").element(boundBy: 1).tap()
        XCTAssertTrue(app.buttons["library.latest"].waitForExistence(timeout: 5), "没跳到那段原话")
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
