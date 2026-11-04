import XCTest

/// 说话记录（docs/模块/生活画布2.0.md 第 6 节）：用假的听写（-uiTest，不开麦克风，「听到」早上跑了五公里）。
/// 点一下说：拉上来对话，第一次先看说明 → 最下面听写（正在听、声波、字一边出）→ 发送；转成字留在输入框；按住说松开就发
final class VoiceUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// 点一下说，说完直接发
    @MainActor func testTapToTalk() throws {
        let app = launch()
        startTalking(app) { attach(app, "语音-第一次的说明") }
        XCTAssertTrue(app.staticTexts["正在听"].waitForExistence(timeout: 3), "没有录音卡")
        let words = app.descendants(matching: .any)["voice.words"]
        let heard = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == '早上跑了五公里'"), object: words)
        XCTAssertEqual(XCTWaiter().wait(for: [heard], timeout: 5), .completed, "字没出来")
        settle()
        attach(app, "语音-正在听")
        try AppAudit.run(app, name: "语音-正在听")
        app.buttons["voice.send"].tap()
        XCTAssertTrue(app.staticTexts["早上跑了五公里"].waitForExistence(timeout: 3), "没发出去")
    }

    /// ✓ 转成字：留在输入框里再改，不发
    @MainActor func testToText() throws {
        let app = launch()
        startTalking(app)
        let words = app.descendants(matching: .any)["voice.words"]
        let heard = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == '早上跑了五公里'"), object: words)
        XCTAssertEqual(XCTWaiter().wait(for: [heard], timeout: 5), .completed, "字没出来")
        app.buttons["voice.text"].tap()
        let field = app.descendants(matching: .any)["pourbar.input"]
        let filled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '早上跑了五公里'"), object: field)
        XCTAssertEqual(XCTWaiter().wait(for: [filled], timeout: 3), .completed, "字没放进输入框")
        XCTAssertTrue(app.buttons["pourbar.send"].exists, "有字了应该有发送")
        // 说了一半停了：麦克风还在，点一下接着说，说的接在后面（产品主人 2026-11-03：「语音不能连续说」）
        XCTAssertTrue(app.buttons["pourbar.mic"].exists, "有字了麦克风也要在，好接着说")
        app.buttons["pourbar.mic"].tap()
        let before = app.descendants(matching: .any)["voice.before"]
        XCTAssertTrue(before.waitForExistence(timeout: 3), "接着说时没写前面说过的")
        let again = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == '早上跑了五公里'"), object: words)
        XCTAssertEqual(XCTWaiter().wait(for: [again], timeout: 5), .completed, "第二段字没出来")
        settle()
        attach(app, "语音-接着说")
        try AppAudit.run(app, name: "语音-接着说")
        app.buttons["voice.text"].tap()
        let joined = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == '早上跑了五公里，早上跑了五公里'"), object: field)
        XCTAssertEqual(XCTWaiter().wait(for: [joined], timeout: 3), .completed, "接着说的字没接在后面")
    }

    /// 按住说：松开就发（看过说明以后才有按住说：先点一下看说明、开始说、✕ 不要了，再按住说）
    @MainActor func testHoldToTalk() throws {
        let app = launch()
        startTalking(app)
        XCTAssertTrue(app.buttons["voice.cancel"].waitForExistence(timeout: 3), "没有录音卡")
        app.buttons["voice.cancel"].tap()
        XCTAssertTrue(app.buttons["pourbar.mic"].waitForExistence(timeout: 3), "✕ 以后没回到输入框")
        app.buttons["pourbar.mic"].press(forDuration: 1.5)
        XCTAssertTrue(app.staticTexts["早上跑了五公里"].waitForExistence(timeout: 3), "松开没发出去")
    }

    // MARK: -

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        XCTAssertTrue(app.buttons["pourbar.mic"].waitForExistence(timeout: 5), "没有麦克风")
        return app
    }

    /// 点麦克风，第一次的说明里点「好，开始说」。点了麦克风对话弹层正往上拉，按钮还在动：等它停稳再点（不然点空）
    @MainActor
    private func startTalking(_ app: XCUIApplication, beforeStart: () -> Void = {}) {
        app.buttons["pourbar.mic"].tap()
        let start = app.buttons["好，开始说"]
        XCTAssertTrue(start.waitForExistence(timeout: 3), "第一次没有说明")
        var last = start.frame
        for _ in 0..<15 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            if start.frame == last { break }
            last = start.frame
        }
        beforeStart()
        start.tap()
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
