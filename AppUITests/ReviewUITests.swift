import XCTest

/// 3.0 回顾（01 需求文档第 8 章、06 交互细节第 6 节和 10.4）：回顾页三段、「需要留意」、一篇一张卡（新、已更新、几个数）；
/// 点一张打开全屏的故事——点右边下一页、点左边上一页、往下拉关掉、最后一页「看整页」进长页面。每一屏跑无障碍审计。
/// 用假服务器（-uiTest）：每天两篇（10月18日没看过、10月17日看过且重写过）和需要留意两件，每周一篇，每月还没有
final class ReviewUITests: XCTestCase, TodoTesting {
    override func setUp() {
        continueAfterFailure = false
    }

    /// 回顾页：每天最上面「需要留意 · 2 件」（知道了收起），卡片上新 / 已更新 / 几个数；每周一篇；每月空的说一句
    @MainActor func testReviewList() throws {
        let app = openReview()
        XCTAssertTrue(app.staticTexts["需要留意 · 2 件"].exists, "没有需要留意")
        let fresh = app.buttons["review.card.2026-10-18"]
        XCTAssertTrue(fresh.label.contains("睡眠 8:20") && fresh.value as? String == "新", "没看过的卡不对：\(fresh.label)")
        let read = app.buttons["review.card.2026-10-17"]
        XCTAssertTrue(read.label.contains("已更新"), "重写过的没写已更新：\(read.label)")
        audit(app, "回顾-每天")
        app.buttons["review.attention.dismiss"].tap()
        XCTAssertFalse(app.staticTexts["需要留意 · 2 件"].waitForExistence(timeout: 1), "知道了没收起")
        let tabs = app.segmentedControls["review.tabs"]
        tabs.buttons["每周"].tap()
        XCTAssertTrue(app.buttons["review.card.2026-10-12"].waitForExistence(timeout: 3), "每周没有周报")
        audit(app, "回顾-每周")
        tabs.buttons["每月"].tap()
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '还没有月报'")).firstMatch.waitForExistence(
                timeout: 3),
            "每月空的没说一句")
        tabs.buttons["每天"].tap()
    }

    /// 每日回顾的故事：点右边下一页、点左边上一页；翻到最后一页「看整页」进长页面；长页面上下翻都审计
    @MainActor func testDailyStory() throws {
        let app = openReview()
        app.buttons["review.card.2026-10-18"].tap()
        let close = app.buttons["story.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "故事没打开")
        let title = app.staticTexts["10月18日 周日"]
        XCTAssertTrue(title.waitForExistence(timeout: 3), "第一页不对")
        audit(app, "故事-每日-1")
        next(app)
        XCTAssertTrue(app.staticTexts["三个数 · 和平时比"].waitForExistence(timeout: 3), "第二页不是几个数")
        audit(app, "故事-每日-2")
        // 点左边回到上一页
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.88)).tap()
        XCTAssertTrue(title.waitForExistence(timeout: 3), "点左边没回到上一页")
        let full = toLast(app)
        audit(app, "故事-每日-最后一页")
        full.tap()
        XCTAssertFalse(close.waitForExistence(timeout: 2), "看整页没关掉故事")
        // 照原型：整页的大标题是那一天
        XCTAssertTrue(app.navigationBars["10月18日 周日"].waitForExistence(timeout: 5), "没进每日回顾的整页")
        pause()
        audit(app, "每日回顾-整页")
        for name in ["每日回顾-整页-下面", "每日回顾-整页-再下面"] {
            app.swipeUp(velocity: .slow)
            pause()
            audit(app, name)
        }
    }

    /// 周报的故事：往下拉关掉；再打开翻到最后「看整页」
    @MainActor func testWeeklyStory() throws {
        let app = openReview()
        app.segmentedControls["review.tabs"].buttons["每周"].tap()
        let card = app.buttons["review.card.2026-10-12"]
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        card.tap()
        let close = app.buttons["story.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "周报的故事没打开")
        audit(app, "故事-周报-1")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))
        XCTAssertFalse(close.waitForExistence(timeout: 2), "往下拉没关掉")
        card.tap()
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        toLast(app).tap()
        XCTAssertTrue(app.navigationBars["周报"].waitForExistence(timeout: 5), "没进周报的整页")
        pause()
        audit(app, "周报-整页")
        app.swipeUp(velocity: .slow)
        pause()
        audit(app, "周报-整页-下面")
    }

    /// 故事 5.5 秒自动翻到下一页（界面测试平时不自动翻，这一个带上 -storyAutoplay）
    @MainActor func testAutoplay() throws {
        let app = openReview(["-storyAutoplay"])
        app.buttons["review.card.2026-10-18"].tap()
        XCTAssertTrue(app.buttons["story.close"].waitForExistence(timeout: 5), "故事没打开")
        XCTAssertTrue(app.staticTexts["三个数 · 和平时比"].waitForExistence(timeout: 9), "5.5 秒没自动翻到下一页")
    }

    // MARK: - 共用

    /// 我的 → 回顾（先回到「每天」：回顾页记得上次看的是哪一段）
    @MainActor private func openReview(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"] + extra
        app.launch()
        app.openTile("review")
        let tabs = app.segmentedControls["review.tabs"]
        XCTAssertTrue(tabs.waitForExistence(timeout: 8), "回顾没打开")
        tabs.buttons["每天"].tap()
        XCTAssertTrue(app.buttons["review.card.2026-10-18"].waitForExistence(timeout: 5), "每天没有卡片")
        pause()
        return app
    }

    /// 点右下角的空地方：下一页
    @MainActor private func next(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.88)).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
    }

    /// 一页一页翻到最后（最多 8 页），返回「看整页」
    @MainActor private func toLast(_ app: XCUIApplication) -> XCUIElement {
        let full = app.buttons["story.full"]
        for _ in 0..<8 where !full.exists { next(app) }
        XCTAssertTrue(full.waitForExistence(timeout: 2), "翻不到最后一页")
        return full
    }

    @MainActor private func audit(_ app: XCUIApplication, _ name: String) {
        shot(name, of: app.screenshot())
        XCTAssertNoThrow(try AppAudit.run(app, name: name))
    }
}
