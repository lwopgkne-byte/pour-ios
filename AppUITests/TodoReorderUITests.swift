import XCTest

/// 待办 2.0：调整顺序（产品主人 2026-11-06：待办和清单没法调顺序）——右上角「···」或按住的菜单里「调整顺序」，
/// 拖右边的把手排，点「完成」；清单、首页的待办卡都照你排的
final class TodoReorderUITests: XCTestCase, TodoTesting {
    override func setUp() {
        continueAfterFailure = false
    }

    /// 清单：「···」→「调整顺序」，把「吃降压药」拖到「回邮件」上面，点「完成」；清单和首页的待办卡都照这个顺序
    @MainActor func testReorder() throws {
        let app = openTodos()
        app.buttons["todos.more"].tap()
        app.buttons["调整顺序"].tap()
        XCTAssertTrue(app.buttons["todos.reorder.done"].waitForExistence(timeout: 3), "没进调整顺序")
        let handle = { (name: String) in
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "对\(name)")).firstMatch
        }
        XCTAssertTrue(handle("吃降压药").exists && handle("回邮件").exists, "没有拖动的把手")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "调整顺序"
        shot.lifetime = .keepAlways
        add(shot)
        try AppAudit.run(app, name: "调整顺序")
        handle("吃降压药").press(forDuration: 0.6, thenDragTo: handle("回邮件"), withVelocity: .slow, thenHoldForDuration: 0.4)
        pause()
        app.buttons["todos.reorder.done"].tap()
        let pills = row(app, "吃降压药")
        XCTAssertTrue(pills.waitForExistence(timeout: 3))
        XCTAssertLessThan(pills.frame.minY, row(app, "回邮件").frame.minY, "清单没照拖过的顺序")
        // 首页的待办卡：过点的以后照你排的
        app.goBackToCanvas()
        let card = app.buttons.matching(NSPredicate(format: "identifier == 'todo.row' AND label BEGINSWITH '吃降压药'"))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "首页没有吃降压药")
        let mail = app.buttons.matching(NSPredicate(format: "identifier == 'todo.row' AND label BEGINSWITH '回邮件'"))
            .firstMatch
        XCTAssertLessThan(card.frame.minY, mail.frame.minY, "首页的待办卡没照你排的顺序")
    }

    /// 按住一行的菜单里「调整顺序」：直接进调整顺序
    @MainActor func testReorderFromMenu() throws {
        let app = openTodos()
        row(app, "回邮件").press(forDuration: 1.0)
        let item = app.buttons["todoPress.reorder"]
        XCTAssertTrue(item.waitForExistence(timeout: 3), "菜单里没有「调整顺序」")
        item.tap()
        XCTAssertTrue(app.buttons["todos.reorder.done"].waitForExistence(timeout: 3), "没进调整顺序")
    }
}
