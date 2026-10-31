import XCTest

/// 3.0 外壳（docs/3.0/06-交互细节.md 第 1 节、07 开发任务清单 1.5–1.9、1.15）：打开就是画布，左上角「我」进全部功能，
/// 别的页都推进来、返回一路回到画布；全部旧链接照旧能打开；「我的」里管理常用、长按、搜功能
final class ShellUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        XCTAssertTrue(app.buttons["today.me"].waitForExistence(timeout: 10), "画布没打开")
        return app
    }

    /// 我 → 我的 → 钱 → 返回 → 返回：回到画布；从左边缘右滑也能返回
    @MainActor func testMeAndBack() throws {
        let app = launch()
        // 底部只有「说一句」，没有标签栏，也没有以前的抽屉菜单
        XCTAssertEqual(app.tabBars.count, 0, "不该有标签栏")
        XCTAssertFalse(app.descendants(matching: .any)["today.menu"].exists, "抽屉菜单还在")
        app.buttons["today.me"].tap()
        let money = app.buttons["hub.tile.money"].firstMatch
        XCTAssertTrue(money.waitForExistence(timeout: 5), "「我的」没打开")
        XCTAssertTrue(app.staticTexts["记了 63 天 · 377 段话"].waitForExistence(timeout: 5), "头上没有记了几天")
        settle()
        try AppAudit.run(app, name: "我的")
        app.swipeUp(velocity: .slow)
        settle()
        try AppAudit.run(app, name: "我的-下面")
        app.swipeDown(velocity: .fast)
        money.tap()
        XCTAssertTrue(app.buttons["遮住金额"].waitForExistence(timeout: 5), "钱没打开")
        XCTAssertTrue(app.navigationBars.buttons["我的"].exists, "返回按钮没写上一页的名字")
        app.goBack()
        XCTAssertTrue(money.waitForExistence(timeout: 5), "没回到「我的」")
        // 等返回的动画停下来：动画没走完就滑，系统不接
        settle()
        // 从左边缘往右滑：返回
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
        XCTAssertTrue(app.buttons["today.me"].waitForExistence(timeout: 5), "右滑没回到画布")
    }

    /// 画布往下翻过以后，左上角的「我」照样点得进去（样张的上班族：画布很长）
    @MainActor func testMeFromScrolledCanvas() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest", "-canvasSample", "上班族"]
        app.launch()
        let avatar = app.buttons["today.me"]
        XCTAssertTrue(avatar.waitForExistence(timeout: 10), "画布没打开")
        app.swipeUp(velocity: .slow)
        app.swipeUp(velocity: .slow)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "画布翻下去以后"
        shot.lifetime = .keepAlways
        add(shot)
        avatar.tap()
        XCTAssertTrue(app.buttons["hub.manage"].waitForExistence(timeout: 5), "画布翻下去以后点「我」没进去")
    }

    /// 用过长按菜单（「说到的」里的名字 → 不再显示）以后，顶上的「我」、搜索第一下就点得动
    /// （2026-10-31 查出来的：长按菜单收起以后，顶上那一排的第一下被吞掉了）
    @MainActor func testTopBarAfterContextMenu() throws {
        for target in ["today.me", "搜索"] {
            let app = XCUIApplication()
            app.launchArguments += ["-uiTest", "-canvasSample", "上班族"]
            app.launch()
            let chip = app.buttons["小李，这周 3 天"]
            XCTAssertTrue(chip.waitForExistence(timeout: 10), "没有说到的小李")
            chip.press(forDuration: 1.0)
            XCTAssertTrue(app.buttons["不再显示"].waitForExistence(timeout: 3))
            app.buttons["不再显示"].tap()
            RunLoop.current.run(until: Date().addingTimeInterval(1.5))
            app.buttons[target].firstMatch.tap()
            if target == "today.me" {
                XCTAssertTrue(app.buttons["hub.manage"].waitForExistence(timeout: 5), "用过长按菜单以后点「我」没进去")
            } else {
                let field = app.textFields.matching(NSPredicate(format: "placeholderValue BEGINSWITH '找说过的话'"))
                    .firstMatch
                XCTAssertTrue(field.waitForExistence(timeout: 5), "用过长按菜单以后点搜索没打开")
            }
            app.terminate()
        }
    }

    /// 每一页滚到最底下，最后一样东西都露在「说一句」上面、点得到（画布、「我的」）
    @MainActor func testLastRowAboveSayBar() throws {
        let app = launch()
        for _ in 0..<6 { app.swipeUp(velocity: .fast) }
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        let bar = app.otherElements["say.bar"].firstMatch
        let canvasShot = XCTAttachment(screenshot: app.screenshot())
        canvasShot.name = "画布滚到底"
        canvasShot.lifetime = .keepAlways
        add(canvasShot)
        app.buttons["today.me"].tap()
        let settings = app.buttons["hub.row.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        for _ in 0..<6 { app.swipeUp(velocity: .fast) }
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "我的滚到底"
        shot.lifetime = .keepAlways
        add(shot)
        // 「说一句」往下翻时收起来了：往上拨一下让它出来，最后一行也得在它上面
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        from.press(
            forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.53)),
            withVelocity: .slow, thenHoldForDuration: 0.3)
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        XCTAssertLessThanOrEqual(settings.frame.maxY, bar.frame.minY + 1, "「设置」那一行压在「说一句」下面")
    }

    /// 全部旧链接照旧能打开（pour://open?path=）：推进来那一页，返回一下就回到画布
    @MainActor func testEveryLinkOpens() throws {
        let app = launch()
        let links: [(String, String)] = [
            ("/review", "回顾"), ("/money", "遮住金额"), ("/money/watch", "留意的"), ("/money/renqing", "和谁来往"),
            ("/about", "你的生活由什么组成"), ("/about/mood", "心情和精力"), ("/goals", "添加目标"),
            ("/library?view=insights", "感悟"), ("/settings", "大模型"), ("/settings#data", "数据"),
        ]
        for (path, sign) in links {
            open(path, in: app)
            let mark = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", sign)).firstMatch
            XCTAssertTrue(mark.waitForExistence(timeout: 8), "\(path) 没打开（没看到「\(sign)」）")
            XCTAssertEqual(app.navigationBars.buttons.firstMatch.label, "今天", "\(path) 下面不是画布")
            app.goBack()
            XCTAssertTrue(app.buttons["today.me"].waitForExistence(timeout: 5), "\(path) 返回没回到画布")
        }
        // 「我的」也有地址
        open("/me", in: app)
        XCTAssertTrue(app.buttons["hub.tile.money"].firstMatch.waitForExistence(timeout: 5), "/me 没打开「我的」")
    }

    /// 管理常用：点「管理」格子抖起来，常用里的点了拿出来（多一个空位），下面的点了放进去；改了存在服务器上
    @MainActor func testManageFavorites() throws {
        let app = launch()
        app.buttons["today.me"].tap()
        let manage = app.buttons["hub.manage"]
        XCTAssertTrue(manage.waitForExistence(timeout: 5), "没有「管理」")
        manage.tap()
        XCTAssertEqual(manage.label, "完成")
        let empty = app.descendants(matching: .any)["空位：在下面点加号放进来"]
        XCTAssertFalse(empty.exists, "常用满 8 个时不该有空位")
        app.buttons["钱，从常用拿出来"].firstMatch.tap()
        XCTAssertTrue(empty.waitForExistence(timeout: 3), "拿出来以后没有空位")
        settle()
        try AppAudit.run(app, name: "我的-管理常用")
        let health = app.buttons["健康，放进常用"].firstMatch
        for _ in 0..<4 where !health.isHittable { app.swipeUp(velocity: .slow) }
        health.tap()
        XCTAssertTrue(app.buttons["健康，从常用拿出来"].firstMatch.waitForExistence(timeout: 3), "健康没放进来")
        XCTAssertFalse(empty.exists, "放满了还有空位")
        manage.tap()
        XCTAssertEqual(manage.label, "管理")
    }

    /// 长按格子：「加到常用」「移出常用」
    @MainActor func testLongPressTile() throws {
        let app = launch()
        app.buttons["today.me"].tap()
        let watch = app.buttons["hub.tile.watch"].firstMatch
        XCTAssertTrue(watch.waitForExistence(timeout: 5))
        for _ in 0..<4 where !watch.isHittable { app.swipeUp(velocity: .slow) }
        watch.press(forDuration: 1.0)
        let remove = app.buttons["移出常用"]
        let add = app.buttons["加到常用"]
        XCTAssertTrue(add.waitForExistence(timeout: 3) || remove.exists, "长按没有菜单")
        // 常用已经满 8 个：「加到常用」不能点
        XCTAssertFalse(add.isEnabled, "常用满了还能加")
        app.tap()
    }

    /// 顶上往下拉出搜索框：搜「报销」找到「留意的」，点了推进去
    @MainActor func testSearchFunctions() throws {
        let app = launch()
        app.buttons["today.me"].tap()
        XCTAssertTrue(app.buttons["hub.tile.money"].firstMatch.waitForExistence(timeout: 5))
        let field = app.searchFields.firstMatch
        if !field.exists { app.swipeDown(velocity: .slow) }
        XCTAssertTrue(field.waitForExistence(timeout: 3), "没有搜功能的框")
        field.tap()
        field.typeText("报销")
        let watch = app.buttons["留意的，2"].firstMatch
        XCTAssertTrue(watch.waitForExistence(timeout: 3), "搜「报销」没找到「留意的」")
        XCTAssertFalse(app.buttons["钱"].exists, "搜出来了不相干的")
        watch.tap()
        XCTAssertTrue(app.staticTexts["留意的"].firstMatch.waitForExistence(timeout: 5), "留意的没打开")
    }

    /// 说一句：每一页都在；点了展开对话，上面一排快捷；在钱那一页提示是「记一笔」
    @MainActor func testSayBarEverywhere() throws {
        let app = launch()
        let input = app.textFields["pourbar.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5), "画布上没有说一句")
        app.openTile("money")
        XCTAssertTrue(app.buttons["遮住金额"].waitForExistence(timeout: 5), "钱没打开")
        XCTAssertTrue(input.exists, "钱那一页没有说一句")
        XCTAssertEqual(input.placeholderValue, "记一笔，比如：午饭 25")
        input.tap()
        let ask = app.buttons["say.问一句"]
        XCTAssertTrue(ask.waitForExistence(timeout: 3), "点了没展开对话、没有快捷")
        ask.tap()
        XCTAssertEqual(input.value as? String, "/问 ")
    }

    /// 没网（docs/3.0/07-开发任务清单.md 1.11）：拿过的页面照样有内容（上次存的），顶上一条细条说是几点的
    @MainActor func testOfflineShowsSaved() throws {
        let app = launch()
        app.buttons["today.me"].tap()
        let days = app.staticTexts["记了 63 天 · 377 段话"]
        XCTAssertTrue(days.waitForExistence(timeout: 5), "「我的」没拿到")
        app.goBack()
        // 假服务器：从这句话起全部连不上
        let input = app.textFields["pourbar.input"]
        input.tap()
        input.typeText("全部断网")
        app.buttons["pourbar.send"].tap()
        // 发出去对话就展开了：收起来再去「我的」
        let chat = app.buttons["pourbar.chat"]
        if chat.waitForExistence(timeout: 3), chat.label == "收起对话" { chat.tap() }
        app.buttons["today.me"].tap()
        XCTAssertTrue(days.waitForExistence(timeout: 5), "没网时「我的」没有用上次存的")
        let stale = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '没连上 · 显示的是'")).firstMatch
        XCTAssertTrue(stale.waitForExistence(timeout: 5), "顶上没有「没连上 · 显示的是……的」")
        settle()
        try AppAudit.run(app, name: "我的-没网")
    }

    // MARK: - 小工具

    @MainActor private func open(_ path: String, in app: XCUIApplication) {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.")
        let value = path.addingPercentEncoding(withAllowedCharacters: allowed) ?? path
        guard let url = URL(string: "pour://open?path=\(value)") else { return XCTFail("链接拼不出来：\(path)") }
        app.open(url)
    }

    @MainActor private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
    }
}
