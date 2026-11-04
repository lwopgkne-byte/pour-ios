import XCTest

/// 3.0.1 照可交互原型补的几页（产品主人 2026-11-03：「里面有很多都没有 UI」）：「我的」里的格子点进来——
/// 日历（每一格那天的心情和花了多少，点一天回到画布看那天）、值不值（一样一张卡，点了进那样东西）、
/// 健康（步数、那一觉、最近 7 天的锻炼，分清你说过的和健康 App 记的）
final class ProtoPagesUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testCalendar() throws {
        let app = launch()
        app.openTile("calendar")
        XCTAssertTrue(app.staticTexts["每一格：那天的心情、花了多少。"].waitForExistence(timeout: 5), "日历没打开")
        // 假服务器的心情和钱都是 10 月的：换到 10 月看
        open("/calendar/2026-10", in: app)
        let day = app.buttons["calendar.2026-10-18"]
        XCTAssertTrue(day.waitForExistence(timeout: 5), "10 月没有 18 号")
        let filled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS '花了'"), object: day)
        XCTAssertEqual(XCTWaiter().wait(for: [filled], timeout: 5), .completed, "18 号没写花了多少：\(day.label)")
        settle()
        attach(app, "日历")
        try AppAudit.run(app, name: "日历")
        day.tap()
        let header = app.descendants(matching: .any)["today.header"]
        let shown = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS '10月18日'"), object: header)
        XCTAssertEqual(XCTWaiter().wait(for: [shown], timeout: 5), .completed, "点了没回到画布看 10月18日")
    }

    @MainActor func testWorth() throws {
        let app = launch()
        app.openTile("worth")
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '降噪耳机'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "值不值里没有降噪耳机")
        XCTAssertTrue(card.label.contains("「通勤戴着太安静了」"), "没写你说的那句：\(card.label)")
        XCTAssertTrue(card.label.contains("你说值 · 用了 4 次 · 每次 ¥225"), "下面那一行不对：\(card.label)")
        settle()
        attach(app, "值不值")
        try AppAudit.run(app, name: "值不值")
        card.tap()
        // 假服务器的「一样东西」都是空气炸锅（每次 ¥33）
        XCTAssertTrue(app.staticTexts["每次 ¥33"].waitForExistence(timeout: 5), "点了没进那样东西")
    }

    @MainActor func testHealth() throws {
        let app = launch()
        app.openTile("health")
        let steps = app.staticTexts["6,039 步"]
        XCTAssertTrue(steps.waitForExistence(timeout: 5), "健康没打开（没有步数）")
        XCTAssertTrue(app.staticTexts["昨天 · 目标每天 8,000 步 · 来自健康"].exists, "步数下面那一行不对")
        XCTAssertTrue(app.staticTexts["0:10 – 7:00 · 6 小时 50 分"].exists, "没有那一觉")
        XCTAssertTrue(app.staticTexts["来自健康"].exists && app.staticTexts["你说过"].exists, "锻炼没分清谁记的")
        settle()
        attach(app, "健康")
        try AppAudit.run(app, name: "健康")
        let settings = app.buttons["health.settings"]
        app.reveal(settings)
        settings.tap()
        XCTAssertTrue(app.navigationBars["健康和日历"].waitForExistence(timeout: 5), "没去设置里的健康和日历")
    }

    // MARK: -

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        XCTAssertTrue(app.buttons["today.me"].waitForExistence(timeout: 10), "画布没打开")
        return app
    }

    /// 用 pour://open?path= 打开一页
    @MainActor
    private func open(_ path: String, in app: XCUIApplication) {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.")
        let value = path.addingPercentEncoding(withAllowedCharacters: allowed) ?? path
        guard let url = URL(string: "pour://open?path=\(value)") else { return XCTFail("链接拼不出来：\(path)") }
        app.open(url)
    }

    @MainActor
    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(1))
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
