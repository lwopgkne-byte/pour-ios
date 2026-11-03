import XCTest

/// 目标的界面测试共用的（GoalsUITests、GoalsEditUITests）：打开目标首页、找一行、点开一个目标、看轻提示、截图加审计
@MainActor
protocol GoalTesting: TodoTesting {}

extension GoalTesting {
    /// 我 → 目标
    func openGoals() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        app.openTile("goals")
        XCTAssertTrue(app.staticTexts["goals.summary"].waitForExistence(timeout: 8), "目标没打开")
        pause()
        return app
    }

    /// 一个目标那一行；列表里还没滑到的往上滑着找（List 只画看得见的几行）
    func row(_ app: XCUIApplication, _ id: Int) -> XCUIElement {
        let element = app.descendants(matching: .any)["goal.row.\(id)"].firstMatch
        for _ in 0..<4 where !element.waitForExistence(timeout: 2) { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(element.exists, "没有目标 \(id)")
        return element
    }

    /// 点一行打开那个目标：点左边的环（中间那一行「落后两周了，聊聊怎么调？」是另一个链接）；
    /// 压在「说一句」后面的先往上滑出来，不然点到的是输入框
    func tapRow(_ app: XCUIApplication, _ id: Int) {
        let bar = app.buttons["pourbar"]
        let limit = bar.exists ? bar.frame.minY : app.frame.maxY * 0.85
        // 每次重新找：List 滑过以后那一行是新画的，旧的引用找不到了
        for _ in 0..<3 where row(app, id).frame.maxY > limit - 8 {
            app.swipeUp(velocity: .slow)
            pause()
        }
        row(app, id).coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.5)).tap()
    }

    /// 轻提示那句话：App 在汉字和数字、字母之间加了细空格（WebText.spaced），去掉再比
    func toast(_ app: XCUIApplication, _ text: String) -> Bool {
        let head = String(text.prefix { !$0.isASCII })
        let element = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", head)).firstMatch
        guard element.waitForExistence(timeout: 5) else { return false }
        let label = element.label.replacingOccurrences(of: "\u{2006}", with: "")
        XCTAssertEqual(label, text, "轻提示的字不对")
        return label == text
    }

    func audit(_ app: XCUIApplication, _ name: String) {
        shot(name, of: app.screenshot())
        XCTAssertNoThrow(try AppAudit.run(app, name: name))
    }
}
