import XCTest

/// 我的卡片和语录（docs/模块/产品优化.md R3、R4）：画布样张里的三张卡（一个数、一张清单、一张小图），
/// 长按「不要了」轻提示能撤销；每日回顾故事的最后一页「你说过」；「关于我 → Pour 认识的」里「我的语录」
final class CardsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testMyCardsAndMenu() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest", "-canvasSample", "上班族"]
        app.launch()
        let coffee = app.descendants(matching: .any)["mycard.1"]
        XCTAssertTrue(coffee.waitForExistence(timeout: 5), "没有我的卡片")
        for _ in 0..<6 where !coffee.isHittable { app.swipeUp(velocity: .slow) }
        settle()
        XCTAssertTrue(app.staticTexts["这个月的咖啡"].exists)
        XCTAssertTrue(app.staticTexts["今年读的书"].exists)
        attach(app, "我的卡片")
        coffee.press(forDuration: 1.0)
        XCTAssertTrue(app.buttons["不要了"].waitForExistence(timeout: 3), "长按没有菜单")
        app.buttons["不要了"].tap()
        XCTAssertTrue(app.staticTexts["「这个月的咖啡」不要了"].waitForExistence(timeout: 3), "没说不要了")
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: coffee)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed, "卡片还在")
        app.buttons["撤销"].firstMatch.tap()
        XCTAssertTrue(coffee.waitForExistence(timeout: 5), "撤销了卡片没回来")
    }

    @MainActor func testReviewSaidAndQuotes() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        go(to: "回顾", in: app)
        // 3.0 第 6 步起：每天 · 每周 · 每月三段（回顾页记得上次看的是哪一段，先回到「每天」），点一篇是故事
        let tabs = app.segmentedControls["review.tabs"]
        XCTAssertTrue(tabs.waitForExistence(timeout: 5), "回顾页没出来")
        tabs.buttons["每天"].tap()
        let daily = app.buttons["review.card.2026-10-18"]
        XCTAssertTrue(daily.waitForExistence(timeout: 5), "回顾列表没出来")
        daily.tap()
        // 「你说过」是故事最后一页：点右边一页一页翻
        let said = app.staticTexts["「付出不亚于任何人的努力」"]
        for _ in 0..<8 where !said.exists {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.88)).tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        }
        XCTAssertTrue(said.waitForExistence(timeout: 3), "每日回顾最后一页没有「你说过」")
        settle()
        attach(app, "回顾-你说过")
        app.buttons["story.close"].tap()
        // 3.0 第 8 步起：我的语录在「关于我 → Pour 认识的」那一页
        go(to: "关于我", in: app)
        let known = app.buttons["about.known.sayings"]
        app.reveal(known)
        known.tap()
        let quotes = app.staticTexts["我的语录"]
        app.reveal(quotes)
        XCTAssertTrue(quotes.waitForExistence(timeout: 3), "Pour 认识的没有我的语录")
        settle()
        attach(app, "关于我-我的语录")
    }

    // MARK: -

    /// 左上角菜单去一页（按位置点：翻过的页面按名字点会点偏，见 ios-test-gotchas）
    @MainActor
    private func go(to page: String, in app: XCUIApplication) {
        // 3.0 外壳：画布是首页（返回到底），别的页从「我」进
        switch page {
        case "生活画布": app.goBackToCanvas()
        case "关于我": app.openTile("about")
        case "回顾": app.openTile("review")
        default: XCTFail("测试里没写怎么去「\(page)」")
        }
    }

    @MainActor
    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
