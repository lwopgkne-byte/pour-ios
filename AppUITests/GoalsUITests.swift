import XCTest

/// 3.0 目标（docs/3.0/01-需求文档.md 第 9 章、06 交互细节第 12 节）：首页、一个目标、按住菜单、左滑暂停、定目标的理解卡、
/// 花 1 分钟想清楚、聊聊怎么调、每周回顾、我在乎的一块。每一屏跑无障碍审计。
/// 用假服务器（-uiTest）：10月27日（原型那天）的演示数据原样（StubServer+GoalsData）；改动回服务器同样的轻提示
final class GoalsUITests: XCTestCase, TodoTesting {
    override func setUp() {
        continueAfterFailure = false
    }

    /// 首页：这周一句话、每周回顾那一行、我在乎的、按我在乎的分组、坚持（14 天的格子）、做到的 · 放下的
    @MainActor func testGoalsHome() throws {
        let app = openGoals()
        let summary = app.staticTexts["goals.summary"]
        XCTAssertTrue(summary.label.hasPrefix("这周 7 个目标里 4 个在正轨上；「今年跑 500 公里」落后两周了"), "这周一句话不对：\(summary.label)")
        XCTAssertTrue(app.buttons["goals.weekly"].label.contains("上周的回顾还没看"), "没有每周回顾那一行")
        let run = row(app, 4)
        XCTAssertTrue(run.label.contains("比应达少 78 公里") && run.label.contains("落后两周了，聊聊怎么调？"), "跑步那一行不对：\(run.label)")
        audit(app, "目标-首页")
        // 01 需求文档 9.14 第 6 条：iPhone 15 第一屏看得到 5 个目标——第 5 个（人类简史）的名字和那句话在「说一句」上面
        let fifth = app.descendants(matching: .any)["goal.row.12"].firstMatch
        let bar = app.buttons["pourbar"]
        XCTAssertTrue(fifth.exists, "第一屏没有第 5 个目标")
        if fifth.exists, bar.exists {
            XCTAssertLessThan(fifth.frame.minY + 48, bar.frame.minY, "第 5 个目标压在「说一句」后面")
        }
        XCTAssertTrue(row(app, 12).label.contains("看完两部分，到第 220 页"), "人类简史那一行不对")
        app.swipeUp(velocity: .slow)
        pause()
        XCTAssertTrue(row(app, 2).label.contains("30 天做到 26 天"), "坚持里没有每天走 8000 步")
        audit(app, "目标-首页-坚持")
        app.buttons["goals.closed"].tap()
        app.swipeUp(velocity: .slow)
        pause()
        XCTAssertTrue(app.staticTexts["每天冥想 10 分钟"].waitForExistence(timeout: 3), "做到的 · 放下的没展开")
        audit(app, "目标-首页-做到的放下的")
    }

    /// 按住出菜单（改 · 暂停 · 标记完成 · 删除），左滑暂停：都不弹确认框，轻提示带撤销
    @MainActor func testMenuAndSwipe() throws {
        let app = openGoals()
        let sleep = row(app, 3)
        sleep.press(forDuration: 1.0)
        XCTAssertTrue(app.buttons["标记完成"].waitForExistence(timeout: 3), "按住没出菜单")
        XCTAssertTrue(app.buttons["删除"].exists && app.buttons["改"].exists, "菜单少了几项")
        audit(app, "目标-按住菜单")
        app.buttons["暂停"].tap()
        XCTAssertTrue(app.staticTexts["暂停了：平均睡 7.5 小时"].waitForExistence(timeout: 3), "暂停没有轻提示")
        XCTAssertTrue(app.buttons["撤销"].exists, "轻提示上没有撤销")
        row(app, 11).swipeLeft()
        let swipePause = app.buttons["暂停"].firstMatch
        XCTAssertTrue(swipePause.waitForExistence(timeout: 3), "左滑没露出暂停")
        swipePause.tap()
        XCTAssertTrue(app.staticTexts["暂停了：每月外卖不超过 300 元"].waitForExistence(timeout: 3), "左滑暂停没有轻提示")
    }

    /// 一个目标：头（大数、一句状态、预测带、一排数）、三句话、图、什么时候最容易做到、最近推进它的、每个月、设置
    @MainActor func testGoalPage() throws {
        let app = openGoals()
        tapRow(app, 4)
        let line = app.staticTexts["goal.head.line"]
        XCTAssertTrue(line.waitForExistence(timeout: 5), "一个目标没打开")
        XCTAssertEqual(line.label, "比应达少 78 公里")
        XCTAssertEqual(app.staticTexts["goal.head.more"].label, "照最近的速度，年底在 163–193 公里之间")
        XCTAssertTrue(app.buttons["goal.grow"].exists, "落后两周没有聊聊怎么调的卡")
        audit(app, "一个目标-头")
        for name in ["一个目标-三句话和图", "一个目标-什么时候", "一个目标-原话和每个月", "一个目标-设置"] {
            app.swipeUp(velocity: .slow)
            pause()
            audit(app, name)
        }
        XCTAssertTrue(app.buttons["goal.pause"].exists, "最下面没有暂停")
    }

    /// 坚持每天：30 天做到 26 天、补假；做完就算：在等你回答（算 → 到第 260 页）、勾里程碑
    @MainActor func testStreakAndBook() throws {
        let app = openGoals()
        app.swipeUp(velocity: .slow)
        tapRow(app, 2)
        XCTAssertTrue(app.staticTexts["goal.head.line"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["goal.head.line"].label, "这周用了 1 次补假，还剩 1 次")
        audit(app, "坚持-头")
        app.swipeUp(velocity: .slow)
        pause()
        audit(app, "坚持-30 天和补假")
        app.navigationBars.buttons.firstMatch.tap()
        app.swipeDown(velocity: .slow)
        tapRow(app, 12)
        XCTAssertTrue(app.buttons["goal.ask.yes"].waitForExistence(timeout: 5), "没有在等你回答")
        audit(app, "做完就算-在等回答")
        app.buttons["goal.ask.yes"].tap()
        XCTAssertTrue(toast(app, "记住了：算进《人类简史》，到第 260 页"), "回答没有轻提示")
        let third = app.buttons["goal.milestone.2"]
        app.swipeUp(velocity: .slow)
        XCTAssertTrue(third.waitForExistence(timeout: 3), "没有里程碑")
        third.tap()
        XCTAssertTrue(toast(app, "勾上了：第三部分 人类的融合统一"), "勾里程碑没有轻提示")
        audit(app, "做完就算-里程碑")
    }

    /// 定目标：自己说的一句 → 理解卡（从「喝水」算）→ 对 → 定好了；模糊的先问再拆；已经有的不重复建
    @MainActor func testDefine() throws {
        let app = openGoals()
        app.buttons["goals.add"].tap()
        let field = app.textFields["define.field"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "定目标没打开")
        audit(app, "定目标-说一句")
        field.tap()
        field.typeText("我想每天喝 8 杯水\n")
        XCTAssertTrue(app.staticTexts["define.plan.title"].waitForExistence(timeout: 5), "没有理解卡")
        XCTAssertTrue(app.staticTexts["从你说的「喝水」算，一天够 8 杯算做到"].exists, "怎么算不对")
        audit(app, "定目标-理解卡")
        app.buttons["define.yes"].tap()
        XCTAssertTrue(app.staticTexts["define.made"].waitForExistence(timeout: 5), "没有定好了")
        audit(app, "定目标-定好了")
        app.buttons["define.ok"].tap()
        app.buttons["goals.add"].tap()
        let again = app.textFields["define.field"].firstMatch
        XCTAssertTrue(again.waitForExistence(timeout: 5))
        again.tap()
        again.typeText("我想变健康\n")
        let move = app.buttons["define.option.动起来"]
        XCTAssertTrue(move.waitForExistence(timeout: 5), "模糊的没先问")
        move.tap()
        XCTAssertTrue(app.buttons["define.split.yes"].waitForExistence(timeout: 5), "没拆开")
        XCTAssertTrue(app.staticTexts["「每天走 8000 步」已经有了，不重复建"].exists, "已经有的没说")
        audit(app, "定目标-拆开")
    }

    /// 聊聊怎么调：还想要吗 → 卡在哪（程序摆事实）→ 有哪些办法（新日期）→ 下一步 → 就这样；花 1 分钟想清楚：改一句
    @MainActor func testGrowAndWoop() throws {
        let app = openGoals()
        app.buttons["goal.grow.4"].tap()
        let important = app.buttons["grow.chip.重要"]
        XCTAssertTrue(important.waitForExistence(timeout: 5), "聊聊怎么调没打开")
        audit(app, "GROW-还想要吗")
        important.tap()
        XCTAssertEqual(app.staticTexts["grow.facts"].label, "10 月你跑了 3 次，都在周末早上；工作日一次没跑。")
        app.buttons["grow.chip.下班太累就不想动"].tap()
        let weekend = app.buttons["grow.option.weekend"]
        XCTAssertTrue(weekend.waitForExistence(timeout: 3), "没有办法")
        XCTAssertTrue(weekend.label.contains("照周末各 8 公里，12月27日能到 230"), "办法的新日期不对：\(weekend.label)")
        audit(app, "GROW-有哪些办法")
        weekend.tap()
        app.buttons["grow.pick"].tap()
        let apply = app.buttons["grow.apply"]
        XCTAssertTrue(apply.waitForExistence(timeout: 3))
        audit(app, "GROW-下一步")
        apply.tap()
        XCTAssertTrue(toast(app, "改好了：改成周末长跑，从 11月2日重新开始算"), "生效没有轻提示")
        tapRow(app, 4)
        let why = app.buttons["goal.three.0"]
        XCTAssertTrue(why.waitForExistence(timeout: 5), "没有三句话")
        why.tap()
        let option = app.buttons["woop.option.1"]
        XCTAssertTrue(option.waitForExistence(timeout: 5), "WOOP 没打开")
        audit(app, "WOOP-一句")
        option.tap()
        app.buttons["woop.next"].tap()
        XCTAssertTrue(toast(app, "三句话写在目标页最上面了 · 每个工作日 18:30 提醒你"), "改好了没有轻提示")
    }

    /// 每周回顾三屏、我在乎的一块（四块；关系还没有目标给一句建议）
    @MainActor func testWeeklyAndCare() throws {
        let app = openGoals()
        app.buttons["goals.weekly"].tap()
        XCTAssertTrue(app.staticTexts["weekly.observation"].waitForExistence(timeout: 5), "每周回顾没打开")
        audit(app, "每周回顾-这一周")
        app.buttons["weekly.button"].tap()
        XCTAssertTrue(app.buttons["weekly.apply.4"].waitForExistence(timeout: 3), "没有要调一调的")
        audit(app, "每周回顾-要调一调的")
        app.buttons["weekly.button"].tap()
        app.buttons["weekly.next.0"].tap()
        audit(app, "每周回顾-下周最重要的一件")
        app.buttons["weekly.button"].tap()
        XCTAssertTrue(toast(app, "加上了：10月31日 周六 08:00 在小区跑 8 公里"), "没放进待办")
        app.buttons["care.chip.family"].tap()
        XCTAssertTrue(app.buttons["care.suggest"].waitForExistence(timeout: 5), "关系没有建议")
        audit(app, "我在乎的-关系")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["care.chip.health"].tap()
        XCTAssertTrue(app.staticTexts["care.wish"].waitForExistence(timeout: 5), "健康没打开")
        audit(app, "我在乎的-健康")
        app.swipeUp(velocity: .slow)
        pause()
        audit(app, "我在乎的-健康-下面")
        app.buttons["care.score.7"].tap()
        XCTAssertTrue(toast(app, "健康这个季度打 7 分"), "打分没有轻提示")
    }

    /// 设置 → 提醒和推送：每周回顾（默认周日 20:00，能改、能关）、目标的「如果就」一个一个能关（07 开发任务清单 7.6）
    @MainActor func testReminderSettings() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest", "-open", "/settings"]
        app.launch()
        let kinds = [XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.switch.rawValue]
        let toggle = { (label: String) in
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@ AND elementType IN %@", label, kinds)).firstMatch
        }
        let review = toggle("每周回顾")
        app.reveal(review)
        XCTAssertTrue(review.exists, "设置里没有每周回顾")
        XCTAssertEqual(review.value as? String, "开", "每周回顾默认开着")
        XCTAssertEqual(app.buttons["settings.review.day"].label, "每周回顾在星期几")
        let run = toggle("「今年跑 500 公里」的提醒")
        app.reveal(run)
        XCTAssertTrue(run.exists, "没有跑步的「如果就」")
        XCTAssertEqual(run.value as? String, "开")
        audit(app, "设置-目标的提醒")
        run.tap()
        XCTAssertTrue(toast(app, "关了「今年跑 500 公里」的提醒"), "关了没有轻提示")
    }

    // MARK: - 共用

    /// 我 → 目标
    @MainActor private func openGoals() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        app.openTile("goals")
        XCTAssertTrue(app.staticTexts["goals.summary"].waitForExistence(timeout: 8), "目标没打开")
        pause()
        return app
    }

    /// 一个目标那一行；列表里还没滑到的往上滑着找（List 只画看得见的几行）
    @MainActor private func row(_ app: XCUIApplication, _ id: Int) -> XCUIElement {
        let element = app.descendants(matching: .any)["goal.row.\(id)"].firstMatch
        for _ in 0..<4 where !element.waitForExistence(timeout: 2) { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(element.exists, "没有目标 \(id)")
        return element
    }

    /// 点一行打开那个目标：点左边的环（中间那一行「落后两周了，聊聊怎么调？」是另一个链接）；
    /// 压在「说一句」后面的先往上滑出来，不然点到的是输入框
    @MainActor private func tapRow(_ app: XCUIApplication, _ id: Int) {
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
    @MainActor private func toast(_ app: XCUIApplication, _ text: String) -> Bool {
        let head = String(text.prefix { !$0.isASCII })
        let element = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", head)).firstMatch
        guard element.waitForExistence(timeout: 5) else { return false }
        let label = element.label.replacingOccurrences(of: "\u{2006}", with: "")
        XCTAssertEqual(label, text, "轻提示的字不对")
        return label == text
    }

    @MainActor private func audit(_ app: XCUIApplication, _ name: String) {
        shot(name, of: app.screenshot())
        XCTAssertNoThrow(try AppAudit.run(app, name: name))
    }
}
