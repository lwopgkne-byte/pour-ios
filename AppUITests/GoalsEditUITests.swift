import XCTest

/// 3.0 收尾补上的目标操作（06 交互细节第 12 节）：一项一项填定目标、一个目标的设置里改类别、只算、周期、从哪天算。
/// 用假服务器（-uiTest）：10月27日的演示数据，跑步那个目标（4）带上能改的（服务器 2.19.0 的样子）
final class GoalsEditUITests: XCTestCase, GoalTesting {
    override func setUp() {
        continueAfterFailure = false
    }

    /// 定目标的「或者一项一项填 ›」：表单（3.0 收尾换成 Theme、系统分段）打得开、能填，每一屏审计；
    /// 种类换成「做完就算」，周期、类别这些数字的项收起来；点「取消」收起
    @MainActor func testDefineByForm() throws {
        let app = openGoals()
        app.buttons["goals.add"].tap()
        let byForm = app.buttons["define.form"]
        XCTAssertTrue(byForm.waitForExistence(timeout: 5), "定目标没有「一项一项填」")
        byForm.tap()
        XCTAssertTrue(app.staticTexts["添加目标"].waitForExistence(timeout: 5), "表单没打开")
        let period = app.staticTexts["周期"]
        XCTAssertTrue(period.waitForExistence(timeout: 3), "有数字的目标没有周期")
        // 拉到整页再审（停在 60% 时审计按放大字号推算，会把标题当成被截掉）
        expandSheet(app, from: app.staticTexts["添加目标"])
        audit(app, "定目标-填表")
        app.buttons["做完就算"].tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: period)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 3), .completed, "做完就算还有周期")
        let name = app.textFields["名称"]
        name.tap()
        name.typeText("读完《三体》")
        audit(app, "定目标-填表-做完就算")
        app.buttons["取消"].firstMatch.tap()
        let closed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: app.staticTexts["添加目标"])
        XCTAssertEqual(XCTWaiter().wait(for: [closed], timeout: 5), .completed, "点取消没收起")
    }

    /// 一个目标的设置（06 交互细节 12「设置」，3.0 收尾补上）：周期、类别点了是系统菜单，只算原地改，
    /// 从哪天算弹出系统的日历；改了有轻提示
    @MainActor func testSettingsEdits() throws {
        let app = openGoals()
        tapRow(app, 4)
        XCTAssertTrue(app.staticTexts["goal.head.line"].waitForExistence(timeout: 5), "跑步那个目标没打开")
        let period = app.buttons["goal.setting.period"]
        for _ in 0..<14 where !period.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(period.isHittable, "设置里没有能点的周期")
        pause()
        audit(app, "目标-设置")
        period.tap()
        let month = app.buttons["这个月"].firstMatch
        XCTAssertTrue(month.waitForExistence(timeout: 3), "周期没弹出菜单")
        month.tap()
        XCTAssertTrue(toast(app, "周期改成「这个月」（10月1日–10月31日）"), "改周期没有轻提示")
        let category = app.buttons["goal.setting.category"]
        app.reveal(category)
        category.tap()
        let sport = app.buttons["运动"].firstMatch
        XCTAssertTrue(sport.waitForExistence(timeout: 3), "类别没弹出菜单")
        sport.tap()
        XCTAssertTrue(toast(app, "类别改成「运动」"), "改类别没有轻提示")
        let only = app.buttons["goal.setting.only"]
        app.reveal(only)
        only.tap()
        let field = app.textFields["goal.edit.only"]
        XCTAssertTrue(field.waitForExistence(timeout: 3), "只算没变成输入框")
        field.typeText("长跑")
        app.buttons["goal.edit.save"].tap()
        XCTAssertTrue(toast(app, "只算名称里带「长跑」的记录"), "改只算没有轻提示")
        let start = app.buttons["修改从哪天算"]
        app.reveal(start)
        start.tap()
        XCTAssertTrue(app.datePickers.firstMatch.waitForExistence(timeout: 3), "从哪天算没弹出日历")
    }
}
