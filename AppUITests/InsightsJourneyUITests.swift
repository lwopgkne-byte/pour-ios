import XCTest

/// 感悟用手走一遍（04 验收标准 B「用手指试」在模拟器上能做的那部分）：连一台演示数据的真服务器（5288），
/// 点着翻卡片、往左滑换一句、按住出菜单、分享换样子、改字再撤销、按意思搜、记一句，每一步截图。
/// 会改演示数据（收藏、改字、记一句）：跑完让服务器重新生成演示数据。平时的检查里不跑，只有给了服务器地址才跑：
/// `TEST_RUNNER_POUR_TOUR_SERVER=http://127.0.0.1:5288 xcodebuild test-without-building … -only-testing:PourUITests/InsightsJourneyUITests`
final class InsightsJourneyUITests: XCTestCase, TodoTesting {
    private let settings = ProcessInfo.processInfo.environment

    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor func testJourney() throws {
        guard let server = settings["POUR_TOUR_SERVER"], !server.isEmpty else {
            throw XCTSkip("只在连演示数据服务器时跑（TEST_RUNNER_POUR_TOUR_SERVER）")
        }
        let app = XCUIApplication()
        app.launchArguments += ["-serverURL", server, "-open", "/insights"]
        app.launch()
        let card = app.descendants(matching: .any)["insights.revisit"]
        XCTAssertTrue(card.waitForExistence(timeout: 15), "感悟没打开")
        pause()
        shot("旅程-1-感悟", of: app.screenshot())

        // 翻过来、翻回来
        card.tap()
        let back = app.descendants(matching: .any)["insights.revisit.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 3), "没翻过来")
        XCTAssertTrue(back.label.contains("你当时说的"), "背面不是当时说的话：\(back.label)")
        pause()
        shot("旅程-2-翻过来", of: app.screenshot())
        back.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 3), "没翻回来")

        // 手指往左滑：换一句；再点「换一句」
        let first = card.label
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: card.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)))
        XCTAssertTrue(waitFor(card, labelChangesFrom: first), "往左滑没换一句")
        pause()
        shot("旅程-3-往左滑换了一句", of: app.screenshot())
        let second = card.label
        app.buttons["insights.revisit.next"].tap()
        XCTAssertTrue(waitFor(card, labelChangesFrom: second), "换一句没换")

        // 按住第一张：分享成图片，三种样子，拷贝
        let row = app.buttons.matching(NSPredicate(format: "identifier MATCHES 'insight\\\\.[0-9]+'")).firstMatch
        app.reveal(row)
        row.press(forDuration: 1.0)
        XCTAssertTrue(app.buttons["分享成图片"].waitForExistence(timeout: 3), "按住没出菜单")
        shot("旅程-4-按住", of: app.screenshot())
        app.buttons["分享成图片"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["share.card"].waitForExistence(timeout: 3), "分享没打开")
        for look in ["ink", "moon", "warm"] {
            app.buttons["share.look.\(look)"].tap()
            pause()
            shot("旅程-5-分享-\(look)", of: app.screenshot())
        }
        app.buttons["share.copy"].tap()
        XCTAssertTrue(app.staticTexts["拷贝好了，去微信里粘贴"].waitForExistence(timeout: 3), "拷贝了没说")

        // 一条感悟：原话、以前也说过类似的（真服务器给的）；加个标签、好了、撤销
        let starred = app.buttons["insights.filter.starred"]
        let quotes = starred.label
        app.reveal(row)
        row.tap()
        let done = app.buttons["insightDetail.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 3), "一条感悟没打开")
        pause()
        shot("旅程-6-一条感悟", of: app.screenshot())
        app.buttons["insightDetail.addTag"].tap()
        let field = app.descendants(matching: .any)["insightDetail.newTag"]
        XCTAssertTrue(field.waitForExistence(timeout: 3), "没有写新标签的地方")
        field.tap()
        field.typeText("试一试\n")
        done.tap()
        XCTAssertTrue(app.staticTexts["改好了"].waitForExistence(timeout: 3), "改好了没说")
        app.buttons["undoToast"].tap()
        // 改字、改标签不会让「记一句」记的掉出语录（服务器 2026-11-02 修的）
        pause()
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(waitFor(starred, labelContains: quotes), "改了一下语录的句数变了：\(starred.label)，原来 \(quotes)")

        // 按意思搜：「早点睡」，字面上没有的也找到
        let search = app.searchFields.firstMatch
        app.swipeDown(velocity: .fast)
        search.tap()
        search.typeText("早点睡")
        let found = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '搜到'")).firstMatch
        XCTAssertTrue(found.waitForExistence(timeout: 8), "搜不出来")
        pause()
        shot("旅程-7-按意思搜", of: app.screenshot())

        // 记一句：最上面多一张「整理中」（重开一次，从感悟页开始）
        app.terminate()
        app.launch()
        XCTAssertTrue(card.waitForExistence(timeout: 15), "感悟没打开")
        app.buttons["insights.add"].tap()
        let text = app.descendants(matching: .any)["insightAdd.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 3), "记一句没打开")
        text.typeText("先把一件事做完，再开始下一件。")
        app.buttons["insightAdd.save"].tap()
        XCTAssertTrue(app.staticTexts["记下了，收藏成你的语录"].waitForExistence(timeout: 3), "记下了没说")
        pause()
        shot("旅程-8-记一句", of: app.screenshot())
    }

    @MainActor private func waitFor(_ element: XCUIElement, labelChangesFrom label: String) -> Bool {
        let deadline = Date().addingTimeInterval(6)
        while Date() < deadline {
            if element.exists, element.label != label { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }
}
