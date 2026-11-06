import XCTest

/// 时间线：作息和缩放（产品主人 2026-11-06：「上班的时间和睡觉的是固定的」「能够自适应放大和缩小，类似苹果日历」）。
/// 设好了作息（-routineSet：睡觉 23:30–07:00、上班 09:30–18:30、午饭 12:00–13:00）：底色、上面那一行「作息」；
/// 双指放大、缩小，时间线跟着变高变矮；作息弹框加一段「通勤」存了，那一行跟着变
final class TodoTimelineZoomUITests: XCTestCase, TodoTesting {
    override func setUp() {
        continueAfterFailure = false
    }

    private func openTimeline(_ extra: [String] = []) -> XCUIApplication {
        let app = openTodos(["-routineSet"] + extra)
        app.buttons["时间线"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["timeline.canvas"].waitForExistence(timeout: 5), "时间线没出来")
        return app
    }

    @MainActor func testPinchZoom() throws {
        let app = openTimeline()
        let canvas = app.descendants(matching: .any)["timeline.canvas"]
        let routine = app.buttons["timeline.routine"]
        XCTAssertTrue(routine.label.contains("上班 09:30–18:30"), "作息那一行不对：\(routine.label)")
        let regular = canvas.frame.height
        shot("时间线-作息", of: app.screenshot())
        try AppAudit.run(app, name: "时间线-作息")
        canvas.pinch(withScale: 2.6, velocity: 1.5)
        sleep(1)
        XCTAssertGreaterThan(canvas.frame.height, regular * 1.6, "放大了时间线没变高")
        shot("时间线-放大", of: app.screenshot())
        canvas.pinch(withScale: 0.15, velocity: -3)
        sleep(1)
        XCTAssertLessThan(canvas.frame.height, regular * 0.8, "缩小了时间线没变矮")
        shot("时间线-缩小", of: app.screenshot())
        try AppAudit.run(app, name: "时间线-缩小")
    }

    @MainActor func testRoutineSheet() throws {
        let app = openTimeline()
        app.buttons["timeline.routine"].tap()
        let save = app.buttons["routine.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 3), "作息弹框没打开")
        XCTAssertEqual(app.buttons.matching(identifier: "routine.row").count, 3, "设好的三段不对")
        app.buttons["通勤"].tap()
        XCTAssertTrue(app.textFields["routine.title"].waitForExistence(timeout: 3), "加了一段没点开")
        XCTAssertEqual(app.textFields["routine.title"].value as? String, "通勤")
        shot("作息弹框", of: app.screenshot())
        try AppAudit.run(app, name: "作息弹框")
        app.reveal(save)
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 3), "保存了弹框没关")
        XCTAssertTrue(
            waitFor(app.buttons["timeline.routine"], labelContains: "通勤 08:00–09:00"),
            "存了以后作息那一行没变：\(app.buttons["timeline.routine"].label)")
    }

    /// 没设过作息：那一行写「还没设，睡觉先按 23:30–07:00 算」，点了能设
    @MainActor func testRoutineNotSetYet() throws {
        let app = openTodos()
        app.buttons["时间线"].firstMatch.tap()
        let routine = app.buttons["timeline.routine"]
        XCTAssertTrue(routine.waitForExistence(timeout: 5), "时间线上没有作息那一行")
        XCTAssertTrue(routine.label.contains("还没设"), "没设过的写法不对：\(routine.label)")
    }
}
