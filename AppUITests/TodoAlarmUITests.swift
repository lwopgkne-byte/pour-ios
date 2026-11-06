import XCTest

/// 响铃（产品主人 2026-11-06：「提醒一定叫得到」）：说「明天早上7点叫我起床」——结果卡片的钟点标签是闹钟，
/// 点开能改回一条通知；编辑弹框定了钟点有「响铃」开关，开了清单上那一行写着响铃
final class TodoAlarmUITests: XCTestCase, TodoTesting {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testSayWakeUp() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        let field = app.descendants(matching: .any)["pourbar.input"]
        XCTAssertTrue(field.waitForExistence(timeout: 3), "输入框没有")
        field.tap()
        field.typeText("明天早上7点叫我起床")
        app.buttons["pourbar.send"].tap()
        let time = app.buttons["receipt.time"]
        XCTAssertTrue(time.waitForExistence(timeout: 5), "结果卡片上没有钟点的标签")
        XCTAssertTrue(time.label.contains("07:00") && time.label.contains("响铃"), "叫我起床没认成响铃：\(time.label)")
        shot("说一句-叫我起床", of: app.screenshot())
        try AppAudit.run(app, name: "说一句-叫我起床")
        // 认错了：点钟点的标签，关掉响铃，改回一条通知
        time.tap()
        let toggle = app.buttons["响铃"].exists ? app.buttons["响铃"] : app.switches["响铃"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3), "钟点的菜单里没有「响铃」")
        toggle.tap()
        XCTAssertTrue(
            waitFor(app.buttons["receipt.time"], labelLacks: "响铃"), "关了响铃标签没变：\(app.buttons["receipt.time"].label)")
    }

    @MainActor func testEditSheetSwitch() throws {
        let app = openTodos()
        row(app, "吃降压药").tap()
        let alarm = app.switches["todoDetail.alarm"]
        app.reveal(alarm)
        XCTAssertTrue(alarm.waitForExistence(timeout: 3), "定了钟点没有「响铃」开关")
        XCTAssertEqual(alarm.value as? String, "0", "没开过的默认是通知")
        alarm.switches.firstMatch.tap()
        XCTAssertTrue(waitFor(alarm, value: "1"), "开关没打开")
        let hint = app.staticTexts["todoDetail.hint"]
        XCTAssertTrue(hint.label.contains("像闹钟一样响"), "下面那一行没跟着变：\(hint.label)")
        shot("待办编辑-响铃", of: app.screenshot())
        try AppAudit.run(app, name: "待办编辑-响铃")
        // 改成不定时：开关跟着没了
        app.buttons["不定时"].tap()
        XCTAssertTrue(alarm.waitForNonExistence(timeout: 3), "不定时还有响铃开关")
        app.buttons["todoDetail.clock"].tap()
        XCTAssertTrue(alarm.waitForExistence(timeout: 3), "定了钟点没有「响铃」开关")
        if alarm.value as? String == "0" { alarm.switches.firstMatch.tap() }
        app.reveal(app.buttons["todoDetail.save"])
        app.buttons["todoDetail.save"].tap()
        XCTAssertTrue(waitFor(row(app, "吃降压药"), labelContains: "响铃"), "存了以后那一行没写响铃：\(row(app, "吃降压药").label)")
        shot("待办页-响铃", of: app.screenshot())
    }

    /// 真的响一次（和通知那条一样是真的，只有服务器是假的）：加「1分钟后叫我测闹钟」，第一次问能不能排闹钟（点允许），
    /// 到点系统的闹钟出来（「停止」「稍后提醒」），点「停止」App 里这件勾掉了。
    /// 闹钟没打开（iOS 27 的模拟器不弹闹钟的权限、直接回「不允许」，Apple 开发者论坛 thread 849449）：
    /// 照样到点发一条通知，待办页底下写「闹钟没打开」——真的响铃只能在真机上看
    @MainActor func testAlarmRings() throws {
        allowNotifications()
        let app = openTodos(["-remindersCheck"])
        app.buttons["todos.add"].tap()
        let field = addField(app)
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("1分钟后叫我测闹钟")
        app.buttons["todoAdd.add"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        // 第一次有响铃的：系统问能不能排闹钟（通知没问过的话也一起问）
        let allow = springboard.buttons["允许"]
        let asked = Date().addingTimeInterval(10)
        while Date() < asked {
            if allow.exists { allow.tap() }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        // 「闹钟没打开」在清单最下面：滚下去看有没有
        let off = app.descendants(matching: .any)["todos.alarms"]
        app.reveal(off, tries: 6)
        if off.exists {
            XCTAssertTrue(off.label.contains("闹钟没打开"), "闹钟没打开的提示不对：\(off.label)")
            shot("闹钟没打开", of: app.screenshot())
            let banner = springboard.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS '测闹钟'")).firstMatch
            XCTAssertTrue(banner.waitForExistence(timeout: 150), "闹钟没打开时，到点连通知都没有")
            shot("闹钟没打开-照样发通知", of: XCUIScreen.main.screenshot())
            throw XCTSkip("这台模拟器不给闹钟权限：通知照样到了；真的响铃到真机上看")
        }
        let stop = springboard.buttons.matching(NSPredicate(format: "label IN {'停止', 'Stop'}")).firstMatch
        XCTAssertTrue(stop.waitForExistence(timeout: 150), "到点没响：\(springboard.debugDescription)")
        shot("闹钟响了", of: XCUIScreen.main.screenshot())
        XCTAssertTrue(springboard.buttons["稍后提醒"].exists, "闹钟上没有「稍后提醒」")
        stop.tap()
        XCTAssertTrue(app.staticTexts["已勾掉「测闹钟」"].waitForExistence(timeout: 10), "点了「停止」这件没勾掉")
    }

    private func waitFor(_ element: XCUIElement, labelLacks text: String, timeout: TimeInterval = 3) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists, !element.label.contains(text) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }
}
