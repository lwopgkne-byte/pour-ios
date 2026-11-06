import XCTest

/// 接日历（docs/模块/产品优化.md R6）：画布最下面那张小卡点「接上」→ 今天的日程出现在待办卡里，
/// 全天的「小李生日」、15:00 看牙医写「日历」（待办 2.0：过点了的待办在最前，日程排在其余的待办前面）
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
        // 全天的（待办 2.0）：写在顶上的日子后面「今天 · 11月5日 · 小李生日」，不占待办卡的一行
        let header = app.descendants(matching: .any)["today.header"]
        let event = app.descendants(matching: .any)["agenda.event"]
        if !event.waitForExistence(timeout: 5) { keep(app, "日历-接上以后") }
        XCTAssertTrue(header.label.contains("小李生日"), "全天的没写在日子后面：\(header.label)")
        XCTAssertFalse(app.descendants(matching: .any)["agenda.allDay"].exists, "全天的还占着待办卡的一行")
        XCTAssertTrue(event.waitForExistence(timeout: 3), "待办卡里没有日程")
        XCTAssertTrue(event.label.contains("看牙医") && event.label.contains("日历"), "日程不对：\(event.label)")
        XCTAssertFalse(app.buttons["calendar.connect"].exists, "接上了小卡还在")
        // 待办 2.0 第 9 步的排法：过点了的在最前，日程排在其余的待办前面——19:00 以前，15:00 看牙医在
        // 19:00 送车去保养前面；过了 19:00，送车去保养过点了，排到最前
        let todo = app.buttons.matching(NSPredicate(format: "identifier == 'todo.row' AND label CONTAINS %@", "送车去保养"))
            .firstMatch
        XCTAssertTrue(todo.exists, "待办不见了")
        // 过没过点看这一行自己写的（「19:00 过了」）：按 App 的日界线算，半夜里还算前一天
        if todo.label.contains("过了") {
            XCTAssertLessThan(todo.frame.minY, event.frame.minY, "过点了的待办没排在最前")
        } else {
            XCTAssertLessThan(event.frame.minY, todo.frame.minY, "日程没排在其余的待办前面")
        }
        // 待办卡在最上面：滚回去再截图
        for _ in 0..<6 where !event.isHittable { app.swipeDown() }
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
