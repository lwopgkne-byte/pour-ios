import XCTest

/// 小组件、控制中心（docs/模块/产品优化.md R7）：开发版的「小组件样张」截图核对小组件的样子；
/// pour://voice（小组件、控制中心的「说一句」）打开就开始听
final class WidgetsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testWidgetSamples() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest", "-widgetSamples"]
        app.launch()
        XCTAssertTrue(app.staticTexts["小组件样张"].waitForExistence(timeout: 5), "没有小组件样张")
        XCTAssertTrue(app.staticTexts["说一句"].exists, "没有说一句")
        XCTAssertTrue(app.staticTexts["喝水"].exists, "今天的待办没画出来")
        XCTAssertTrue(app.staticTexts["做完 1/4"].exists, "没写做完几件")
        XCTAssertTrue(app.staticTexts["「付出不亚于任何人的努力」"].exists, "没有我的语录")
        XCTAssertTrue(app.staticTexts["连不上电脑上的 Pour"].exists, "连不上时没说清楚")
        XCTAssertTrue(app.staticTexts["送车去保养"].exists, "锁屏没有下一件")
        attach(app, "小组件样张")
    }

    @MainActor func testVoiceLink() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["today.header"].waitForExistence(timeout: 5), "画布没打开")
        app.open(URL(string: "pour://voice") ?? URL(fileURLWithPath: "/"))
        // 第一次用说的：先看一张说明（和点麦克风一样）
        XCTAssertTrue(app.buttons["好，开始说"].waitForExistence(timeout: 5), "从链接打开没开始说")
        app.buttons["好，开始说"].tap()
        XCTAssertTrue(app.staticTexts["正在听"].waitForExistence(timeout: 3), "没有录音卡")
        attach(app, "从小组件打开-正在听")
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
