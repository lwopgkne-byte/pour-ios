import XCTest

/// 补记和「说到的」纠错（docs/模块/产品优化.md R1、R2）：点时间轴上的空当，输入框先填好那段时间；
/// 长按「说到的」里的名字，改名字、不再显示（轻提示上能撤销）
final class BackfillUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// 画布样张前天是大学生：20:50 英语下课以后到 23 点没记，点那一段，输入框里先填好「20:50 到 23:00，」
    @MainActor func testGapFillsComposer() throws {
        let app = XCUIApplication()
        // 和 testSampleWeek 一样：样张自己就用 App 里的假服务器，退出以后连一个不存在的地址
        app.launchArguments += ["-canvasSamples", "on", "-serverURL", "http://127.0.0.1:9"]
        app.launch()
        XCTAssertTrue(app.buttons["canvas.samples"].waitForExistence(timeout: 5), "没有样张的胶囊")
        app.swipeRight()
        settle()
        app.swipeRight()
        let track = app.descendants(matching: .any)["ribbon.track"]
        XCTAssertTrue(track.waitForExistence(timeout: 5), "前天没有一天的时间")
        for _ in 0..<4 where !track.isHittable { app.swipeUp(velocity: .slow) }
        settle()
        // 范围是 6 点到 23 点：0.95 大约是 22:09，在空当里
        track.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        let input = app.descendants(matching: .any)["pourbar.input"]
        let filled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value BEGINSWITH '20:50 到 23:00'"), object: input)
        XCTAssertEqual(XCTWaiter().wait(for: [filled], timeout: 3), .completed, "输入框里没填好时间：\(input.value ?? "")")
        XCTAssertTrue(input.label.hasPrefix("补记"), "前天的输入框没写补记：\(input.label)")
        attach(app, "补记-点空当")
        // 3.0：填好开头时对话就展开了（说一句就是对话），先收起来再退出样张，不留给别的测试
        let chat = app.buttons["pourbar.chat"]
        if chat.exists, chat.label == "收起对话" { chat.tap() }
        app.buttons["canvas.samples"].firstMatch.tap()
    }

    /// 长按「小李」：改名字、不再显示；选「不再显示」它就不在了，轻提示上「撤销」它又回来
    @MainActor func testMentionMenu() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest", "-canvasSample", "上班族"]
        app.launch()
        let chip = app.buttons["小李，这周 3 天"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "没有说到的小李")
        chip.press(forDuration: 1.0)
        XCTAssertTrue(app.buttons["改名字…"].waitForExistence(timeout: 3), "长按没有改名字")
        attach(app, "说到的-长按")
        app.buttons["不再显示"].tap()
        XCTAssertTrue(app.staticTexts["「小李」不再显示"].waitForExistence(timeout: 3), "没说不再显示")
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: chip)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed, "小李还在")
        app.buttons["撤销"].firstMatch.tap()
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "撤销了小李没回来")
    }

    /// 不再显示以后，关于我的「改过的名字」里看得到，点「恢复」回到画布上
    @MainActor func testRestoreInAbout() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest", "-canvasSample", "上班族"]
        app.launch()
        let chip = app.buttons["小李，这周 3 天"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "没有说到的小李")
        chip.press(forDuration: 1.0)
        XCTAssertTrue(app.buttons["不再显示"].waitForExistence(timeout: 3))
        app.buttons["不再显示"].tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: chip)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed, "小李还在")
        go(to: "关于我", in: app)
        let rule = app.staticTexts["小李 · 不再显示"]
        let restore = app.buttons["恢复小李"]
        // 滚到「恢复」整个露出来：只露出一半时，点下去点到的是浮在底部的「说一句」（2026-10-31 查出来的，
        // 第 0 步的全部检查里这个测试两次都没过就是这样）
        app.reveal(restore)
        XCTAssertTrue(rule.waitForExistence(timeout: 5), "关于我里没有改过的名字")
        settle()
        attach(app, "关于我-改过的名字")
        restore.tap()
        XCTAssertEqual(
            XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: rule)],
                timeout: 5), .completed, "恢复了还在")
        go(to: "生活画布", in: app)
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "恢复了小李没回来")
    }

    // MARK: -

    /// 左上角菜单去一页。按菜单按钮的位置点（像手指一样）：画布往下翻过以后，按名字找按钮去点，
    /// 测试工具会点偏、菜单打不开（2026-10-26 对照实验：按坐标点能打开，手机上也正常）
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

    /// 等动画、滚动停下来
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
