import XCTest

/// 待办 2.0 第 10 步：说一句「下午回复客户电话」——结果卡片写三个小标签（马上做 · 猜的 / 今天 / 下午），
/// 下面问「下午几点提醒你？」；点 15:00 就定下钟点，不再问；点哪个标签改哪个
final class TodoVoiceUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testReceiptTags() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        let field = app.descendants(matching: .any)["pourbar.input"]
        XCTAssertTrue(field.waitForExistence(timeout: 3), "输入框没有")
        field.tap()
        field.typeText("下午回复客户电话")
        app.buttons["pourbar.send"].tap()
        let quadrant = app.buttons["receipt.quadrant"]
        XCTAssertTrue(quadrant.waitForExistence(timeout: 5), "结果卡片上没有格子的标签")
        XCTAssertTrue(quadrant.label.contains("马上做") && quadrant.label.contains("猜的"), "格子不对：\(quadrant.label)")
        XCTAssertTrue(app.buttons["receipt.day"].label.contains("今天"), "日子不对")
        XCTAssertTrue(app.buttons["receipt.time"].label.contains("下午"), "时间段丢了")
        XCTAssertTrue(app.staticTexts["下午几点提醒你？"].exists, "只说了下午没有问几点")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "说一句-结果卡片"
        shot.lifetime = .keepAlways
        add(shot)
        try AppAudit.run(app, name: "说一句-结果卡片")
        app.buttons["15:00"].tap()
        XCTAssertTrue(app.staticTexts["下午几点提醒你？"].waitForNonExistence(timeout: 3), "定了钟点还在问")
        XCTAssertTrue(app.buttons["receipt.time"].label.contains("15:00"), "钟点没定上：\(app.buttons["receipt.time"].label)")
        // 点格子的标签：换一格，不再是猜的
        quadrant.tap()
        app.buttons["放进排时间"].tap()
        XCTAssertTrue(
            app.buttons["receipt.quadrant"].label.contains("排时间")
                && !app.buttons["receipt.quadrant"].label.contains("猜的"),
            "换格子没换上：\(app.buttons["receipt.quadrant"].label)")
    }
}
