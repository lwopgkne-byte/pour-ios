import XCTest

/// 接日历（docs/模块/产品优化.md R6）：画布最下面那张小卡点「接上」→ 今天的日程出现在待办卡里，
/// 全天的「小李生日」在最上面一行，15:00 看牙医写「日历」
final class CalendarUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testConnectShowsTodaysEvents() throws {
        let app = XCUIApplication()
        // 上班族的一天：有两件待办（19:00 送车去保养、做完了的交电费），看日程和待办排在一起
        app.launchArguments += ["-uiTest", "-canvasSample", "上班族"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["today.header"].waitForExistence(timeout: 5), "画布没打开")
        // 一次只出一张小卡：先点掉接健康的那张，才轮到日历
        XCTAssertFalse(app.buttons["calendar.connect"].exists, "两张小卡一起出来了")
        app.buttons["health.dismiss"].tap()
        let connect = app.buttons["calendar.connect"]
        XCTAssertTrue(connect.waitForExistence(timeout: 5), "画布上没有「接上日历」")
        // 先滚到它整个露出来：在最下面时点到的是浮在底部的「说一句」（2026-10-31）
        app.reveal(connect)
        connect.tap()
        let allDay = app.descendants(matching: .any)["agenda.allDay"]
        if !allDay.waitForExistence(timeout: 5) { keep(app, "日历-接上以后") }
        XCTAssertTrue(allDay.exists, "待办卡上没有全天的日程")
        XCTAssertTrue(allDay.label.contains("小李生日"), "全天的不对：\(allDay.label)")
        let event = app.descendants(matching: .any)["agenda.event"]
        XCTAssertTrue(event.waitForExistence(timeout: 3), "待办卡里没有日程")
        XCTAssertTrue(event.label.contains("看牙医") && event.label.contains("日历"), "日程不对：\(event.label)")
        XCTAssertFalse(app.buttons["calendar.connect"].exists, "接上了小卡还在")
        // 按时间排：15:00 看牙医在 19:00 送车去保养前面
        let todo = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "送车去保养")).firstMatch
        XCTAssertTrue(todo.exists, "待办不见了")
        XCTAssertLessThan(event.frame.minY, todo.frame.minY, "日程和待办没按时间排")
        // 待办卡在最上面：滚回去再截图
        for _ in 0..<6 where !allDay.isHittable { app.swipeDown() }
        attach(app, "接上日历-待办卡")
    }

    // MARK: -

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// 没对上时留一张截图（结果包里看）
    @MainActor private func keep(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
