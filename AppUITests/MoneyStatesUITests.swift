import XCTest

/// 钱的主页在不同情况下都正常（01 需求文档 5.8 第 4 条）：刚开始用 3 天（假服务器 -moneyEarly）。
/// 收到人情的月份、没有钱的月份、新用户连演示服务器和空的服务器截图（验收/第3步.md）；遮住金额在 MoneyUITests
final class MoneyStatesUITests: XCTestCase, TodoTesting {
    override func setUp() {
        continueAfterFailure = false
    }

    /// 刚开始用 3 天：大数照常；还不能和上个月比，写「11月18日起，就能和上个月比了」；没有预算、留意；还在攒的写清楚
    @MainActor func testEarlyDays() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest", "-moneyEarly"]
        app.launch()
        app.openTile("money")
        let spent = app.staticTexts["money.spent"]
        XCTAssertTrue(spent.waitForExistence(timeout: 8), "钱没打开")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '就能和上个月比了'")).firstMatch.exists,
            "刚开始用没写什么时候能和上个月比")
        XCTAssertFalse(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '还能花'")).firstMatch.exists, "没有预算也写了还能花")
        pause()
        audit(app, "钱-刚开始用")
        app.swipeUp(velocity: .slow)
        pause()
        audit(app, "钱-刚开始用-下面")
        app.swipeUp(velocity: .slow)
        pause()
        audit(app, "钱-刚开始用-最下面")
    }

    @MainActor private func audit(_ app: XCUIApplication, _ name: String) {
        shot(name, of: app.screenshot())
        XCTAssertNoThrow(try AppAudit.run(app, name: name))
    }
}
