import XCTest

/// 3.0 外壳里怎么去一页（docs/3.0/06-交互细节.md 第 1 节）：画布左上角「我」→ 点格子；返回用导航栏左上角的返回按钮。
/// 第 1 步以前是左上角的抽屉菜单，测试都改成走这里
extension XCUIApplication {
    /// 回到画布点「我」，再点「我的」里的一个格子（常用和全部功能里都有的，点第一个）。
    /// 不在画布上就先一路返回；点了「我」没推进来（刚收起一个菜单，那一下被吃掉了）就再点一次
    @MainActor func openTile(_ tile: String, file: StaticString = #filePath, line: UInt = #line) {
        let avatar = buttons["today.me"]
        if !(avatar.exists && avatar.isHittable) { goBackToCanvas(file: file, line: line) }
        XCTAssertTrue(avatar.waitForExistence(timeout: 10), "画布上没有「我」", file: file, line: line)
        let target = buttons["hub.tile.\(tile)"].firstMatch
        for _ in 0..<3 where !target.exists {
            if avatar.exists, avatar.isHittable { avatar.tap() }
            _ = target.waitForExistence(timeout: 3)
        }
        if !target.exists {
            let shot = XCTAttachment(screenshot: screenshot())
            shot.name = "没找到格子-\(tile)"
            shot.lifetime = .keepAlways
            XCTContext.runActivity(named: "没找到格子 \(tile)") { $0.add(shot) }
        }
        XCTAssertTrue(target.exists, "「我的」里没有格子 \(tile)", file: file, line: line)
        target.tap()
    }

    /// 导航栏左上角的返回
    @MainActor func goBack(file: StaticString = #filePath, line: UInt = #line) {
        let back = navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: 5), "没有返回按钮", file: file, line: line)
        back.tap()
    }

    /// 一路返回到画布
    @MainActor func goBackToCanvas(file: StaticString = #filePath, line: UInt = #line) {
        let avatar = buttons["today.me"]
        for _ in 0..<8 where !(avatar.exists && avatar.isHittable) {
            let back = navigationBars.buttons.element(boundBy: 0)
            guard back.waitForExistence(timeout: 2) else { break }
            back.tap()
            _ = avatar.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(avatar.waitForExistence(timeout: 5), "没回到画布", file: file, line: line)
    }

    /// 滚到这个东西整个露出来：在导航栏下面、在「说一句」条上面（条收起来时在屏幕底边上面）。
    /// 每次只拖三分之一屏、拖完停一下（没有惯性，不会一下滑过头）；滚过头了往回拖；滚不动了就停
    @MainActor func reveal(_ element: XCUIElement, tries: Int = 14) {
        let top = (navigationBars.firstMatch.exists ? navigationBars.firstMatch.frame.maxY : 110) + 8
        for _ in 0..<tries {
            // 底部那一整块（轻提示、整理到哪的小条、输入框）的上沿；收起来了（挪到屏幕外）就是屏幕底边
            let bar = otherElements["say.bar"].firstMatch
            let barTop = bar.exists ? bar.frame.minY : frame.height
            let bottom = min(barTop, frame.height - 34) - 12
            let before = element.exists ? element.frame : .zero
            if element.exists, before.minY >= top, before.maxY <= bottom, element.isHittable { return }
            let down = element.exists && before.minY < top
            let from = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.35 : 0.65))
            let to = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.65 : 0.35))
            from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.3)
            // 滚不动了（已经到头）：就停在这里
            if element.exists, element.frame == before { return }
        }
    }
}
