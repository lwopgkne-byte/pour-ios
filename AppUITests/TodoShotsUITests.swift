import XCTest

/// 待办 2.0 每一步做完截图，和 docs/todo-2.0/design 里的图对照（手动跑，平时的检查里跳过）：连一台演示数据服务器，
/// 截首页的待办卡、清单（上、下）、四象限、时间线、按住一行的菜单、点开一行的编辑弹框。
///   TEST_RUNNER_POUR_TOUR_SERVER=http://127.0.0.1:5288 xcodebuild test … -only-testing:PourUITests/TodoShotsUITests
final class TodoShotsUITests: XCTestCase {
    private let settings = ProcessInfo.processInfo.environment
    private var step = 0

    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor func testTodoScreens() throws {
        guard let server = settings["POUR_TOUR_SERVER"], !server.isEmpty else {
            throw XCTSkip("只在手动对照设计图时跑（要给一台演示数据服务器的地址）")
        }
        let app = XCUIApplication()
        app.launchArguments += ["-serverURL", server]
        app.launch()
        sleep(6)
        shot("首页")
        open(app, "/todos")
        sleep(3)
        if app.buttons["todos.guide.ok"].exists { app.buttons["todos.guide.ok"].tap() }
        sleep(1)
        shot("清单")
        app.swipeUp(velocity: .slow)
        sleep(1)
        shot("清单-下面")
        app.swipeDown(velocity: .fast)
        sleep(1)
        for mode in ["四象限", "时间线"] where app.buttons[mode].exists {
            app.buttons[mode].tap()
            sleep(2)
            shot(mode)
        }
        if app.buttons["清单"].exists { app.buttons["清单"].tap() }
        sleep(1)
        let row = app.buttons.matching(identifier: "todo.row").element(boundBy: 1)
        guard row.waitForExistence(timeout: 5) else { return }
        row.press(forDuration: 1.0)
        sleep(2)
        shot("长按菜单")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06)).tap()
        sleep(1)
        row.tap()
        sleep(2)
        shot("编辑")
    }

    @MainActor private func open(_ app: XCUIApplication, _ path: String) {
        guard let url = URL(string: "pour://open?path=\(path)") else { return }
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
