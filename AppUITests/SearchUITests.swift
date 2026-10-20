import XCTest

/// 搜索和问答（照网页版 1 比 1，2026-10-20）：右上角的搜索、对话里的回答（来源编号、图表）；跑系统的无障碍审计，截图留给自验收看。
/// 用假服务器（-uiTest）：搜什么都给网页版演示数据里搜「跑步」的结果；「/问」开头的话给一段带来源、五种图表的回答
final class SearchUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testSearch() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        let search = app.buttons["搜索"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), "画布没打开")
        search.tap()
        let field = app.textFields["搜索"]
        XCTAssertTrue(field.waitForExistence(timeout: 3), "搜索没打开")
        settle()
        audit(app, "搜索-空")
        field.typeText("跑步")
        let hit = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '晚上去跑步了'")).firstMatch
        XCTAssertTrue(hit.waitForExistence(timeout: 5), "没搜到")
        settle()
        audit(app, "搜索-跑步")
        // 点一段原话：到笔记库，从那一段开始看
        hit.tap()
        XCTAssertTrue(app.buttons["看最新的"].waitForExistence(timeout: 5), "没跳到笔记库那段原话")
    }

    @MainActor func testAnswer() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        let field = app.descendants(matching: .any)["pourbar.input"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "输入框没有")
        field.tap()
        field.typeText("/问 这周跑了几次")
        app.buttons["pourbar.send"].tap()
        XCTAssertTrue(app.staticTexts["每天跑了多少"].waitForExistence(timeout: 5), "回答里的图表没出来")
        settle()
        audit(app, "回答")
    }

    @MainActor
    private func audit(_ app: XCUIApplication, _ name: String) {
        let screenshot = app.screenshot()
        let shot = XCTAttachment(screenshot: screenshot)
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        if let folder = ProcessInfo.processInfo.environment["POUR_SHOT_DIR"] {
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: folder).appending(path: "\(name).png"))
        }
        XCTAssertNoThrow(try AppAudit.run(app, name: name))
    }

    @MainActor
    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(2))
    }
}
