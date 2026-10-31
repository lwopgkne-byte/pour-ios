import XCTest

/// 待办的界面测试共用的（TodosUITests、TodoSheetsUITests）：打开待办页、找一行、等一个值、拉开弹层、截图
@MainActor
protocol TodoTesting: XCTestCase {}

extension TodoTesting {
    /// 带样例待办打开待办页（我 → 待办）；extra 是多加的启动参数
    func openTodos(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest", "-todoSample"] + extra
        app.launch()
        app.openTile("todos")
        XCTAssertTrue(app.staticTexts["以前没做完的"].waitForExistence(timeout: 8), "待办页没打开")
        pause()
        return app
    }

    /// 一行待办（点了打开详情的那一块）
    func row(_ app: XCUIApplication, _ content: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == 'todo.row' AND label BEGINSWITH %@", content))
            .firstMatch
    }

    /// 这一行左边的圆圈
    func circle(_ app: XCUIApplication, _ content: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == 'todo.check' AND label == %@", content)).firstMatch
    }

    /// 加待办的输入框（竖着能长的输入框是 textView）
    func addField(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "todoAdd.field").firstMatch
    }

    func waitFor(_ element: XCUIElement, value: String, timeout: TimeInterval = 3) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.value as? String == value { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }

    func waitFor(_ element: XCUIElement, labelContains text: String, timeout: TimeInterval = 3) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists, element.label.contains(text) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }

    /// 半屏的弹层拉到全屏（按住弹层上的一样往上拖）：半屏的系统画得略小一点（约 96%），审计量字会以为被截了
    func expandSheet(_ app: XCUIApplication, from element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)))
        pause()
    }

    /// 往下翻着找（单子是懒加载的，在屏幕外的行还没生成）；找到了停下
    func find(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<6 {
            if element.waitForExistence(timeout: 1) { return true }
            app.swipeUp(velocity: .slow)
        }
        return element.exists
    }

    /// 第一次排提醒时系统问能不能发通知：点「允许」
    func allowNotifications() {
        addUIInterruptionMonitor(withDescription: "通知") { alert in
            for title in ["允许", "Allow"] where alert.buttons[title].exists {
                alert.buttons[title].tap()
                return true
            }
            return false
        }
    }

    func shot(_ name: String, of screenshot: XCUIScreenshot) {
        let shot = XCTAttachment(screenshot: screenshot)
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func pause() {
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
    }
}
