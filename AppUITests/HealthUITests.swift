import XCTest

/// 接健康（docs/模块/产品优化.md R5）：画布最下面那张小卡点「接上」→ 运动卡上有步数、手表记的跑步和那一觉写「来自健康」；
/// 点开健康记的那条只能看
final class HealthUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testConnectShowsStepsAndWorkouts() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["today.header"].waitForExistence(timeout: 5), "画布没打开")
        let connect = app.buttons["health.connect"]
        XCTAssertTrue(connect.waitForExistence(timeout: 5), "画布上没有「接上健康」")
        attach(app, "接上健康-小卡")
        connect.tap()
        let steps = app.descendants(matching: .any)["canvas.steps"]
        XCTAssertTrue(steps.waitForExistence(timeout: 5), "运动卡上没有步数")
        XCTAssertTrue(steps.label.contains("8,234"), "步数不对：\(steps.label)")
        XCTAssertFalse(app.buttons["health.connect"].exists, "接上了小卡还在")
        // 一行记录读屏是合起来念的一个按钮：「跑步，来自健康，7:02–7:35 · 33 分钟 · 5.1 公里」
        let fromHealth = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "来自健康"))
        XCTAssertGreaterThanOrEqual(fromHealth.count, 2, "跑步、睡觉没写「来自健康」")
        attach(app, "接上健康-画布")
        fromHealth.matching(NSPredicate(format: "label CONTAINS %@", "跑步")).firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["detail.health"].waitForExistence(timeout: 5), "健康记的那条打开不是只能看的")
        XCTAssertFalse(app.buttons["detail.delete"].exists, "健康记的那条能删")
        attach(app, "接上健康-详情")
    }

    // MARK: -

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
