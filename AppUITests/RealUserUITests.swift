import XCTest

/// 当成真的用户用一遍（手动跑，平时的检查里跳过）：连一台演示数据服务器，做每天最常做的事——勾待办、撤销、
/// 左滑、长按、加待办、说一句、记一笔、记心情、搜、问一句、改提醒——每一步截一张图，看弹层、键盘、轻提示这些
/// 只在动手时才出现的样子。和 TourShotsUITests 一样只在给了服务器地址时跑：
///   TEST_RUNNER_POUR_TOUR_SERVER=http://127.0.0.1:5288 TEST_RUNNER_POUR_TOUR_TODAY=<服务器的今天> xcodebuild test …
///   -only-testing:PourUITests/RealUserUITests
/// 会改演示数据（加一件待办、记一句话）；真实数据不连
final class RealUserUITests: XCTestCase {
    private let settings = ProcessInfo.processInfo.environment
    private var step = 0

    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor func testJourney() throws {
        guard let server = settings["POUR_TOUR_SERVER"], !server.isEmpty else {
            throw XCTSkip("只在手动走一遍时跑（要给一台演示数据服务器的地址）")
        }
        let days = try TourDays(today: settings["POUR_TOUR_TODAY"] ?? "")
        let app = XCUIApplication()
        app.launchArguments += ["-serverURL", server]
        app.launch()
        sleep(6)
        shot("打开")
        todos(app)
        say(app)
        quickActions(app)
        money(app, days)
        moodAndSearch(app)
        reminders(app)
        reviewAndSettings(app, days)
    }

    /// 昨天的每日回顾从上往下看一遍；设置里接上健康、日历的按钮
    @MainActor private func reviewAndSettings(_ app: XCUIApplication, _ days: TourDays) {
        open(app, "/review/\(days.yesterday)")
        sleep(3)
        shot("每日回顾")
        for index in 2...6 {
            app.swipeUp(velocity: .slow)
            sleep(1)
            shot("每日回顾-\(index)")
        }
        open(app, "/settings#health")
        sleep(3)
        shot("设置-健康和日历")
    }

    /// 画布上勾掉一件、撤销；进待办页左滑、长按、点开、加一件
    @MainActor private func todos(_ app: XCUIApplication) {
        let check = app.buttons.matching(identifier: "todo.check").firstMatch
        if tap(check) {
            sleep(1)
            shot("画布-勾掉一件")
            if tap(app.buttons["undoToast"]) { sleep(1) }
            shot("画布-撤销")
        }
        guard tap(app.buttons["card.title.todo"]) else { return }
        sleep(3)
        shot("待办页")
        let row = app.buttons.matching(identifier: "todo.row").firstMatch
        if row.waitForExistence(timeout: 5) {
            row.swipeLeft()
            sleep(1)
            shot("待办-左滑")
            row.swipeRight()
            sleep(1)
            row.press(forDuration: 1.0)
            sleep(1)
            shot("待办-长按")
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
            sleep(1)
            row.tap()
            sleep(2)
            shot("待办-点开一件")
            close(app)
        }
        if tap(app.buttons["todos.add"]) {
            sleep(2)
            shot("加待办")
            app.typeText("周五前把房租交了")
            sleep(2)
            shot("加待办-打字")
            if tap(app.buttons["todoAdd.add"]) { sleep(2) }
            shot("加待办-加上了")
        }
        open(app, "/")
    }

    /// 底下那一条：点开打字、发出去、等整理好、关掉回画布
    @MainActor private func say(_ app: XCUIApplication) {
        guard tap(app.textFields["pourbar.input"]) else { return }
        sleep(2)
        shot("说一句-键盘")
        app.typeText("中午和同事吃了碗牛肉面，28 块")
        sleep(1)
        shot("说一句-打字")
        guard tap(app.buttons["pourbar.send"]) else { return }
        sleep(2)
        shot("说一句-发出去")
        sleep(15)
        shot("说一句-整理好")
        if tap(app.buttons["chat.close"]) { sleep(2) }
        shot("说一句-回到画布")
    }

    /// 我的：上面四个快捷（记一笔、记心情、记一句、加待办），常用的管理，搜功能
    @MainActor private func quickActions(_ app: XCUIApplication) {
        guard tap(app.buttons["today.me"]) else { return }
        sleep(2)
        shot("我的")
        if tap(app.buttons["hub.quick.记一笔"]) {
            sleep(2)
            shot("记一笔")
            for key in ["keypad.3", "keypad.5"] { _ = tap(app.buttons[key]) }
            sleep(1)
            shot("记一笔-35")
            close(app)
        }
        if tap(app.buttons["hub.quick.记心情"]) {
            sleep(2)
            shot("记心情")
            if tap(app.buttons["mood.level.4"]) { sleep(1) }
            shot("记心情-挺好")
            close(app)
        }
        if tap(app.buttons["hub.quick.记一句"]) {
            sleep(2)
            shot("记一句")
            close(app)
        }
        if tap(app.buttons["hub.manage"]) {
            sleep(1)
            shot("我的-管理常用")
            if tap(app.buttons["完成"]) { sleep(1) }
        }
        app.swipeDown(velocity: .slow)
        let find = app.searchFields.firstMatch
        if tap(find) {
            app.typeText("报销")
            sleep(2)
            shot("我的-搜功能")
            if tap(app.buttons["取消"]) { sleep(1) }
        }
    }

    /// 钱：主页记一笔、每一笔里点开一笔
    @MainActor private func money(_ app: XCUIApplication, _ days: TourDays) {
        open(app, "/money")
        sleep(3)
        if tap(app.buttons["money.record"]) {
            sleep(2)
            shot("钱-记一笔")
            close(app)
        }
        open(app, "/money/list/\(days.thisMonth)")
        sleep(3)
        shot("钱-每一笔")
        let cell = app.cells.element(boundBy: 1)
        if tap(cell) {
            sleep(2)
            shot("钱-一笔")
            close(app)
        }
    }

    /// 心情点一天；搜一个词、点一条结果；问一句
    @MainActor private func moodAndSearch(_ app: XCUIApplication) {
        open(app, "/mood")
        sleep(3)
        let day = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'mood.day.'")).element(boundBy: 3)
        if tap(day) {
            sleep(2)
            shot("心情-点一天")
        }
        open(app, "/")
        sleep(2)
        guard tap(app.buttons["搜索"].firstMatch) else { return }
        sleep(2)
        app.typeText("牛肉面")
        sleep(3)
        shot("搜索-牛肉面")
        app.typeText(
            XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue)
        app.typeText("这个月吃饭花了多少钱")
        sleep(2)
        shot("问一句-打字")
        if tap(app.buttons["search.ask"]) {
            sleep(20)
            shot("问一句-回答")
            close(app)
        }
        open(app, "/")
    }

    /// 设置里的提醒：关一个、再开回来
    @MainActor private func reminders(_ app: XCUIApplication) {
        open(app, "/settings#reminders")
        sleep(3)
        shot("设置-提醒")
        let toggle = app.switches.firstMatch
        if tap(toggle) {
            sleep(2)
            shot("设置-提醒-关一个")
            _ = tap(toggle)
            sleep(1)
        }
    }

    // MARK: - 小工具

    @MainActor private func tap(_ element: XCUIElement) -> Bool {
        guard element.waitForExistence(timeout: 5), element.isHittable else {
            shot("没找到-\(element.description.prefix(40))")
            return false
        }
        element.tap()
        return true
    }

    /// 关掉弹层：有「关闭」「取消」点它，没有就往下拉
    @MainActor private func close(_ app: XCUIApplication) {
        for name in ["关闭", "取消", "chat.close"] where app.buttons[name].firstMatch.isHittable {
            app.buttons[name].firstMatch.tap()
            sleep(1)
            return
        }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).press(
            forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        sleep(1)
    }

    @MainActor private func open(_ app: XCUIApplication, _ path: String) {
        let plain = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/-_.")
        guard let value = path.addingPercentEncoding(withAllowedCharacters: plain),
            let url = URL(string: "pour://open?path=\(value)")
        else { return }
        app.open(url)
        sleep(2)
    }

    @MainActor private func shot(_ name: String) {
        step += 1
        let attachment = XCTAttachment(
            data: XCUIScreen.main.screenshot().pngRepresentation, uniformTypeIdentifier: "public.png")
        attachment.name = String(format: "%02d-", step) + name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
