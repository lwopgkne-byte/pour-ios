import XCTest

/// 目标用手走一遍（04 验收标准 B「用手指试」在模拟器上能做的那部分）：连一台演示数据的真服务器（5288），
/// 首页往下翻、每个目标点进去一屏一屏往下看、按住出菜单、左滑暂停再撤销、聊聊怎么调、每周回顾、定一个新目标、
/// 我在乎的、坚持和预算两页、设置里的提醒，每一步截图。平时的检查里不跑，只有给了服务器地址才跑：
/// `TEST_RUNNER_POUR_TOUR_SERVER=http://127.0.0.1:5288 xcodebuild test-without-building … -only-testing:PourUITests/GoalsJourneyUITests`
final class GoalsJourneyUITests: XCTestCase, TodoTesting {
    private let settings = ProcessInfo.processInfo.environment

    override func setUp() {
        continueAfterFailure = true
    }

    private func launch(_ path: String) throws -> XCUIApplication {
        guard let server = settings["POUR_TOUR_SERVER"], !server.isEmpty else {
            throw XCTSkip("只在连演示数据服务器时跑（TEST_RUNNER_POUR_TOUR_SERVER）")
        }
        let app = XCUIApplication()
        app.launchArguments += ["-serverURL", server, "-open", path]
        app.launch()
        return app
    }

    /// 首页一屏一屏往下；每个目标点进去一屏一屏往下（最多 12 个）
    @MainActor func testHomeAndEveryGoal() throws {
        let app = try launch("/goals")
        XCTAssertTrue(app.staticTexts["goals.summary"].waitForExistence(timeout: 15), "目标没打开")
        pause()
        shot("目标-首页-1", of: app.screenshot())
        var ids: [String] = []
        for index in 2...5 {
            ids += visibleRows(app).filter { !ids.contains($0) }
            app.swipeUp(velocity: .slow)
            pause()
            shot("目标-首页-\(index)", of: app.screenshot())
        }
        ids += visibleRows(app).filter { !ids.contains($0) }
        XCTAssertGreaterThanOrEqual(ids.count, 5, "首页的目标不到 5 个：\(ids)")
        for id in ids.prefix(12) {
            let number = id.replacingOccurrences(of: "goal.row.", with: "")
            app.terminate()
            let page = try launch("/goals/\(number)")
            XCTAssertTrue(page.staticTexts["goal.head.line"].waitForExistence(timeout: 10), "目标 \(number) 没打开")
            pause()
            for screen in 1...4 {
                shot("目标-\(number)-\(screen)", of: page.screenshot())
                page.swipeUp(velocity: .slow)
                pause()
            }
        }
    }

    /// 按住出菜单、左滑暂停再撤销、「聊聊怎么调？」、每周回顾
    @MainActor func testGesturesGrowWeekly() throws {
        let app = try launch("/goals")
        XCTAssertTrue(app.staticTexts["goals.summary"].waitForExistence(timeout: 15), "目标没打开")
        pause()
        let first = rowElement(app, visibleRows(app).first ?? "goal.row.1")
        first.press(forDuration: 1.2)
        pause()
        shot("手势-按住出菜单", of: app.screenshot())
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        pause()
        rowElement(app, visibleRows(app).first ?? "goal.row.1").swipeLeft()
        pause()
        shot("手势-左滑", of: app.screenshot())
        let pauseButton = app.buttons.matching(NSPredicate(format: "label == '暂停'")).firstMatch
        if pauseButton.waitForExistence(timeout: 3) {
            pauseButton.tap()
            pause()
            shot("手势-暂停了", of: app.screenshot())
            let undo = app.buttons["undoToast"]
            if undo.waitForExistence(timeout: 3) { undo.tap() }
            pause()
        }
        growFlow(app)
        weeklyFlow(app)
    }

    /// 「这周一句话」后半句点进聊聊怎么调，一步一步点到最后（每一步截图）
    @MainActor private func growFlow(_ app: XCUIApplication) {
        let grow = app.links.firstMatch
        guard grow.exists else { return }
        grow.tap()
        pause()
        for screen in 1...4 {
            shot("聊聊怎么调-\(screen)", of: app.screenshot())
            let chip = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'grow.chip.'")).firstMatch
            let option = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'grow.option.'")).firstMatch
            if chip.exists {
                chip.tap()
            } else if option.exists {
                option.tap()
                if app.buttons["grow.pick"].exists { app.buttons["grow.pick"].tap() }
            }
            pause()
        }
        if app.buttons["grow.close"].exists { app.buttons["grow.close"].tap() }
        pause()
    }

    /// 首页「上周的回顾还没看」进每周回顾，三屏各截一张
    @MainActor private func weeklyFlow(_ app: XCUIApplication) {
        app.swipeDown(velocity: .slow)
        let weekly = app.buttons["goals.weekly"]
        guard weekly.waitForExistence(timeout: 3) else { return }
        weekly.tap()
        pause()
        for screen in 1...3 {
            shot("每周回顾-\(screen)", of: app.screenshot())
            if app.buttons["weekly.button"].exists, screen < 3 { app.buttons["weekly.button"].tap() }
            pause()
        }
        app.buttons["weekly.close"].tap()
    }

    /// 定一个新目标（服务器没开 AI 时程序理解）、我在乎的、坚持和预算两页、设置里的提醒
    @MainActor func testDefineCareListsSettings() throws {
        let app = try launch("/goals")
        XCTAssertTrue(app.staticTexts["goals.summary"].waitForExistence(timeout: 15), "目标没打开")
        app.buttons["goals.add"].tap()
        let field = app.textFields["define.field"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "定目标没打开")
        field.tap()
        field.typeText("每周去两次游泳\n")
        let card = app.staticTexts["define.plan.title"]
        XCTAssertTrue(card.waitForExistence(timeout: 30), "没有理解卡")
        pause()
        shot("定目标-理解卡", of: app.screenshot())
        app.buttons["define.close"].tap()
        pause()
        for key in ["health", "money", "growth", "family"] {
            app.terminate()
            let page = try launch("/goals/care/\(key)")
            pause()
            pause()
            shot("我在乎的-\(key)-1", of: page.screenshot())
            page.swipeUp(velocity: .slow)
            pause()
            shot("我在乎的-\(key)-2", of: page.screenshot())
        }
        for path in ["/goals/streaks", "/goals/budgets"] {
            app.terminate()
            let page = try launch(path)
            pause()
            pause()
            shot("列表-\(path.split(separator: "/").last ?? "")", of: page.screenshot())
        }
        app.terminate()
        let settingsPage = try launch("/settings")
        let review = settingsPage.descendants(matching: .any)
            .matching(
                NSPredicate(
                    format: "label == '每周回顾' AND elementType IN %@",
                    [
                        XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.switch.rawValue,
                    ])
            ).firstMatch
        settingsPage.reveal(review)
        pause()
        shot("设置-每周回顾和如果就", of: settingsPage.screenshot())
    }

    // MARK: - 共用

    /// 看得见的目标行（「goal.row.4」）
    @MainActor private func visibleRows(_ app: XCUIApplication) -> [String] {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'goal.row.'"))
            .allElementsBoundByIndex.filter { $0.exists && $0.isHittable }.map(\.identifier)
    }

    @MainActor private func rowElement(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }
}
