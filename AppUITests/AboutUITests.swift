import XCTest

/// 关于我（2026-10-20）：主页和点进去的几页；跑系统的无障碍审计，截图留给自验收看。
/// 用假服务器（-uiTest）：演示数据里的关于我
final class AboutUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testAboutHome() throws {
        let app = open()
        audit(app, "关于我")
        app.swipeUp(velocity: .slow)
        settle()
        audit(app, "关于我-2")
        app.swipeUp(velocity: .slow)
        settle()
        audit(app, "关于我-3")
        app.swipeUp(velocity: .slow)
        settle()
        audit(app, "关于我-4")
    }

    @MainActor func testAboutPages() throws {
        let app = open()
        // 方块图点一块：那一块生活的那一页
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '饮食'")).firstMatch.tap()
        let back = app.buttons["‹ 关于我"]
        XCTAssertTrue(back.waitForExistence(timeout: 5), "饮食那一页没打开")
        settle()
        audit(app, "关于我-饮食")
        back.tap()
        // 换个角度看你：心情、人、你说的话
        for (name, title) in [("mood", "关于我-心情"), ("people", "关于我-人"), ("talk", "关于我-你说的话")] {
            let card = app.buttons["angle.\(name)"]
            scroll(app, to: card)
            card.tap()
            XCTAssertTrue(back.waitForExistence(timeout: 5), "\(name)那一页没打开")
            settle()
            audit(app, title)
            back.tap()
            XCTAssertTrue(app.staticTexts["关于我"].waitForExistence(timeout: 5), "没回到关于我")
        }
        let year = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '你的 '")).firstMatch
        scroll(app, to: year)
        year.tap()
        XCTAssertTrue(back.waitForExistence(timeout: 5), "你的一年没打开")
        settle()
        audit(app, "关于我-一年")
    }

    /// 心情那一页下面：心情和精力的曲线、心情从哪来
    @MainActor func testMoodBoard() throws {
        let app = open()
        let card = app.buttons["angle.mood"]
        scroll(app, to: card)
        card.tap()
        XCTAssertTrue(app.buttons["‹ 关于我"].waitForExistence(timeout: 5), "心情那一页没打开")
        let curve = app.staticTexts["心情和精力"]
        scroll(app, to: curve)
        XCTAssertTrue(curve.isHittable, "没有心情和精力的曲线")
        settle()
        audit(app, "关于我-心情和精力")
        let sources = app.staticTexts["好时刻多出现在什么时候"]
        scroll(app, to: sources)
        XCTAssertTrue(sources.isHittable, "没有心情从哪来")
        settle()
        audit(app, "关于我-心情从哪来")
    }

    /// Pour 认识的：点一个说法看从哪学来的；人那一页点一个认识的人
    @MainActor func testKnown() throws {
        let app = open()
        let saying = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '老地方 = '")).firstMatch
        scroll(app, to: saying)
        saying.tap()
        XCTAssertTrue(app.staticTexts["从哪学来的"].waitForExistence(timeout: 5), "说法的详情没打开")
        settle()
        expandSheet(app)
        audit(app, "关于我-一个说法")
    }

    /// 链接打开（推送、对话里的链接点进来是 pour://open?path=…）：只知道一个词也能打开 Pour 认识的那一条
    @MainActor func testDeepLink() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["today.menu"].waitForExistence(timeout: 5), "画布没打开")
        // path=/about?find=老地方
        let link = try XCTUnwrap(URL(string: "pour://open?path=%2Fabout%3Ffind%3D%E8%80%81%E5%9C%B0%E6%96%B9"))
        app.open(link)
        XCTAssertTrue(app.staticTexts["从哪学来的"].waitForExistence(timeout: 8), "链接没打开「老地方」那个说法")
    }

    /// 底部弹出的详情拉到全屏再审：半屏的那一层系统画得略小一点（约 96%），审计量字的大小会以为字被截了
    @MainActor
    private func expandSheet(_ app: XCUIApplication) {
        let title = app.staticTexts["从哪学来的"].firstMatch
        title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)))
        settle()
    }

    @MainActor
    private func open() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        let menu = app.descendants(matching: .any)["today.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5), "画布没打开")
        menu.tap()
        app.buttons["关于我"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["你的生活由什么组成"].waitForExistence(timeout: 5), "关于我没打开")
        settle()
        return app
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

    /// 往下翻到它能点为止（最多翻 8 次）
    @MainActor
    private func scroll(_ app: XCUIApplication, to element: XCUIElement) {
        // 翻到它能点、而且在输入框上面（压在输入框下面也算「能点」，点到的却是输入框）
        var tries = 0
        while !(element.isHittable && element.frame.maxY < app.frame.height * 0.7) && tries < 8 {
            app.swipeUp(velocity: .slow)
            tries += 1
        }
    }

    @MainActor
    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(2))
    }
}
