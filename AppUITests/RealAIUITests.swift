import XCTest

/// 用真的 AI 走一遍（连这台 Mac 上的网关和 DeepSeek，要花一点钱）：平时的检查不跑，
/// 要跑时：TEST_RUNNER_POUR_REAL_AI=1 xcodebuild test … -only-testing:PourUITests/RealAIUITests。
/// 从空数据库开始说几句真话，每句整理完截一张图，留给自验收和产品主人看
final class RealAIUITests: XCTestCase {
    static let sentences = [
        "早上七点跑了五公里，有点累",
        "中午和小王吃了碗牛肉面 28",
        // 5 分钟内又发同一句：不记两遍
        "中午和小王吃了碗牛肉面 28",
        // 纠正刚才那条
        "刚才那个是 32 不是 28",
        "昨晚十一点半睡的，今早七点起",
        "下午陪闺女在楼下骑滑板车，看她骑得那么稳，我也挺高兴",
        "明天下午三点开会，记得带电脑",
    ]

    @MainActor
    func testRealSentences() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["POUR_REAL_AI"] == "1", "要花钱：只在手动指定时跑")
        let app = XCUIApplication()
        app.launchArguments += ["-freshStore"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["today.header"].waitForExistence(timeout: 5))
        let field = app.descendants(matching: .any)["pourbar.input"]
        for (index, sentence) in Self.sentences.enumerated() {
            XCTAssertTrue(field.waitForExistence(timeout: 3))
            field.tap()
            field.typeText(sentence)
            app.buttons["pourbar.send"].tap()
            // 等它整理完：对话里「正在整理…」「待处理」都没了
            let waiting = NSPredicate(format: "label CONTAINS '正在整理' OR label CONTAINS '待处理'")
            let organizing = app.staticTexts.matching(waiting).firstMatch
            let done = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: organizing)
            XCTAssertEqual(XCTWaiter().wait(for: [done], timeout: 60), .completed, "「\(sentence)」一分钟没整理完")
            RunLoop.current.run(until: Date().addingTimeInterval(2))
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "真的 AI-第\(index + 1)句"
            shot.lifetime = .keepAlways
            add(shot)
        }
        // 收起对话，看整个画布
        app.buttons["pourbar.chat"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        let canvas = XCTAttachment(screenshot: app.screenshot())
        canvas.name = "真的 AI-画布"
        canvas.lifetime = .keepAlways
        add(canvas)
        app.swipeUp()
        let lower = XCTAttachment(screenshot: app.screenshot())
        lower.name = "真的 AI-画布下面"
        lower.lifetime = .keepAlways
        add(lower)
    }
}
