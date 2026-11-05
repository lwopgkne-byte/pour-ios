import XCTest

/// 待办 2.0 第 7 步：四象限（docs/todo-2.0 design/after-03-matrix）——四格、按住拖到别的格子换一格、
/// 「还没分」托盘里点一下选一格、点格头看这一格的全部
final class TodoMatrixUITests: XCTestCase, TodoTesting {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testMatrix() throws {
        let app = openTodos()
        app.buttons["四象限"].tap()
        for lane in 1...4 {
            XCTAssertTrue(
                app.descendants(matching: .any)["matrix.cell.\(lane)"].waitForExistence(timeout: 3), "少了第 \(lane) 格")
        }
        let tray = app.descendants(matching: .any)["matrix.tray"]
        XCTAssertTrue(tray.exists, "没有「还没分」托盘")
        shot("四象限", of: app.screenshot())
        try AppAudit.run(app, name: "四象限")
        // 按住「回邮件」（快速办）拖到马上做
        // 能拖的卡片读出来不一定是按钮（draggable 包了一层），按名字和编号找
        let mail = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'matrix.card' AND label BEGINSWITH '回邮件'")).firstMatch
        XCTAssertTrue(mail.exists, "快速办里没有回邮件")
        let doNow = app.descendants(matching: .any)["matrix.cell.1"]
        mail.press(forDuration: 1.2, thenDragTo: doNow, withVelocity: .slow, thenHoldForDuration: 0.5)
        XCTAssertTrue(app.staticTexts["「回邮件」放进马上做"].waitForExistence(timeout: 3), "拖过去没换格子")
        // 托盘里点一下：选一格
        let fee = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'matrix.tray.chip' AND label CONTAINS '交水费'")).firstMatch
        XCTAssertTrue(fee.exists, "托盘里没有交水费")
        fee.tap()
        app.buttons["放进放一放"].tap()
        XCTAssertTrue(app.staticTexts["「交水费」放进放一放"].waitForExistence(timeout: 3), "托盘里选了没放进去")
        // 点格头：看马上做的全部，「‹ 四格」回去
        doNow.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["matrix.back"].waitForExistence(timeout: 3), "点格头没进这一格")
        XCTAssertTrue(row(app, "回邮件").exists, "马上做里没有拖进来的回邮件")
        app.buttons["matrix.back"].tap()
        XCTAssertTrue(doNow.waitForExistence(timeout: 3), "回不到四格")
    }
}
