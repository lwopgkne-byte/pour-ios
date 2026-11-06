import XCTest

/// 待办 2.0 的边界情况（产品主人 2026-11-06：马上做多于三件时四象限被撑变形，右边的数字被切、标题下面那一行少了字）：
/// 挤满了的一天（-todoCrowded：马上做 6 件、名字很长的、同一分钟两件、快到点的）——四象限、时间线都不出屏幕、不叠在一起
final class TodoCrowdedUITests: XCTestCase, TodoTesting {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest", "-todoCrowded"]
        app.launch()
        app.openTile("todos")
        XCTAssertTrue(app.buttons["四象限"].waitForExistence(timeout: 8), "待办页没打开")
        return app
    }

    @MainActor func testCrowdedMatrix() throws {
        let app = launch()
        app.buttons["四象限"].tap()
        let width = app.frame.width
        for lane in 1...4 {
            let cell = app.descendants(matching: .any)["matrix.cell.\(lane)"]
            XCTAssertTrue(cell.waitForExistence(timeout: 3), "少了第 \(lane) 格")
            XCTAssertGreaterThanOrEqual(cell.frame.minX, 0, "第 \(lane) 格出了屏幕左边：\(cell.frame)")
            XCTAssertLessThanOrEqual(cell.frame.maxX, width, "第 \(lane) 格出了屏幕右边：\(cell.frame)")
        }
        let summary = app.staticTexts["todos.summary"]
        XCTAssertGreaterThanOrEqual(summary.frame.minX, 0, "标题下面那一行被挤出了屏幕：\(summary.frame)")
        let header = app.descendants(matching: .any)["matrix.cell.1"].buttons.firstMatch
        XCTAssertTrue(header.label.contains("6 件，有点多"), "马上做的件数不对：\(header.label)")
        XCTAssertTrue(app.buttons["还有 2 件"].exists, "多于 4 件没有「还有 N 件」")
        shot("四象限-挤满了", of: app.screenshot())
        try AppAudit.run(app, name: "四象限-挤满了")
    }

    /// 首页待办卡、清单：挤满了也是 4 行 +「还有 N 件」，清单不出屏幕
    @MainActor func testCrowdedHomeAndList() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest", "-todoCrowded"]
        app.launch()
        XCTAssertTrue(app.buttons["canvas.todos.more"].waitForExistence(timeout: 8), "首页待办卡没有「还有 N 件」")
        shot("首页-挤满了", of: app.screenshot())
        app.openTile("todos")
        XCTAssertTrue(app.buttons["清单"].waitForExistence(timeout: 8), "待办页没打开")
        let summary = app.staticTexts["todos.summary"]
        XCTAssertGreaterThanOrEqual(summary.frame.minX, 0, "标题下面那一行被挤出了屏幕：\(summary.frame)")
        shot("清单-挤满了", of: app.screenshot())
        try AppAudit.run(app, name: "清单-挤满了")
    }

    @MainActor func testCrowdedTimeline() throws {
        let app = launch()
        app.buttons["时间线"].tap()
        let tags = app.descendants(matching: .any).matching(identifier: "timeline.tag")
        XCTAssertTrue(tags.firstMatch.waitForExistence(timeout: 3), "时间线上没有小标签")
        // 同一分钟的两件并排在一行，不上下叠着
        let ship = tags.matching(NSPredicate(format: "label BEGINSWITH '发内测版本'")).firstMatch
        let water = tags.matching(NSPredicate(format: "label BEGINSWITH '喝水'")).firstMatch
        XCTAssertEqual(ship.frame.midY, water.frame.midY, accuracy: 2, "同一时刻的两件没放在一行")
        XCTAssertFalse(ship.frame.intersects(water.frame), "同一时刻的两件叠在一起了")
        XCTAssertLessThanOrEqual(water.frame.maxX, app.frame.width, "小标签出了屏幕")
        shot("时间线-挤满了", of: app.screenshot())
        try AppAudit.run(app, name: "时间线-挤满了")
    }
}
