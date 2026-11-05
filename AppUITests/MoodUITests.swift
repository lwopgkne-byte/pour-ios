import XCTest

/// 3.0 心情（01 需求文档 6.6、06 交互细节第 4 节和 10.1）：第一屏五个表情 + 今天的每一刻；点月历的一天下面出现那天的每一刻；
/// 记心情（选档、情绪词、因为……）、只点一档就记；一条心情里改档、删除都带撤销。
/// 用假服务器（-uiTest）：演示数据的 10 月，10月31日当今天（三刻、有起有落）
final class MoodUITests: XCTestCase, TodoTesting {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testMoodPage() throws {
        let app = openMood()
        for level in 1...5 { XCTAssertTrue(app.buttons["mood.level.\(level)"].exists, "没有第 \(level) 档的表情") }
        // 第一屏不用翻就看到今天的每一刻（验收 6.6 第 4 条）
        let moments = app.buttons.matching(identifier: "mood.moment")
        XCTAssertEqual(moments.count, 3, "今天不是三刻")
        XCTAssertTrue(moments.element(boundBy: 2).isHittable, "今天的每一刻要在第一屏")
        XCTAssertTrue(app.staticTexts["3 刻 · 有起有落"].exists, "今天没写几刻")
        pause()
        audit(app, "心情")
        let day = app.buttons["mood.day.2026-10-13"]
        app.reveal(day)
        day.tap()
        let picked = app.staticTexts["mood.pickedDay"]
        XCTAssertTrue(picked.waitForExistence(timeout: 3), "点一天下面没出来那天的每一刻")
        XCTAssertTrue(picked.label.contains("有起有落"), "那天的心情不对：\(picked.label)")
        pause()
        audit(app, "心情-点了一天")
        let all = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '全部 15 个'")).firstMatch
        app.reveal(all)
        XCTAssertTrue(all.exists, "好时刻没写全部几个")
        pause()
        audit(app, "心情-下面")
        app.swipeUp(velocity: .slow)
        pause()
        audit(app, "心情-最下面")
        XCTAssertTrue(app.buttons["mood.analysis"].exists, "没有心情分析")
    }

    /// 记心情：点「不太好」→ 不好的感觉排前面；点「烦躁」、写「方案又改了」，原话是「心情不太好，烦躁，因为方案又改了」；
    /// 记下以后轻提示能撤销。只点一档就记：原话「心情挺好」
    @MainActor func testCheckin() throws {
        let app = openMood()
        app.buttons["mood.level.2"].tap()
        let save = app.buttons["moodCheckin.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 3), "记心情没打开")
        let bad = app.staticTexts["不好的感觉（可以不选）"].frame.minY
        XCTAssertLessThan(bad, app.staticTexts["好的感觉（可以不选）"].frame.minY, "心情不好时不好的感觉要排前面")
        app.buttons["烦躁"].tap()
        let because = app.descendants(matching: .any)["moodCheckin.because"]
        because.tap()
        because.typeText("方案又改了")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '「心情不太好，烦躁，因为方案又改了」'")).firstMatch.exists,
            "原话不对")
        pause()
        audit(app, "记心情")
        save.tap()
        let said = app.staticTexts["记下了：不太好 · 烦躁"]
        if !said.waitForExistence(timeout: 3) { shot("记下以后", of: app.screenshot()) }
        XCTAssertTrue(said.exists, "记下了没说：\(app.staticTexts.allElementsBoundByIndex.prefix(40).map(\.label))")
        XCTAssertTrue(app.buttons["undoToast"].exists, "记心情没有撤销")
        app.buttons["mood.level.4"].tap()
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        save.tap()
        XCTAssertTrue(app.staticTexts["记下了：挺好"].waitForExistence(timeout: 3), "只点一档没记下")
    }

    /// 一条心情：改档以后「改好了」才能点，改好了能撤销；删除带撤销
    @MainActor func testMoodDetail() throws {
        let app = openMood()
        app.buttons.matching(identifier: "mood.moment").firstMatch.tap()
        let done = app.buttons["moodDetail.save"]
        XCTAssertTrue(done.waitForExistence(timeout: 3), "一条心情没打开")
        XCTAssertFalse(done.isEnabled, "没改时「改好了」要是灰的")
        XCTAssertTrue(app.staticTexts["AI 推测"].exists, "没写是 AI 推测的")
        app.buttons["moodDetail.level.4"].tap()
        XCTAssertTrue(done.isEnabled, "改了档「改好了」还是灰的")
        XCTAssertTrue(app.staticTexts["你改的"].exists, "改了档没写「你改的」")
        expandSheet(app, from: app.buttons["关闭"])
        audit(app, "一条心情")
        done.tap()
        XCTAssertTrue(app.staticTexts["改好了"].waitForExistence(timeout: 3), "改好了没说")
        XCTAssertTrue(app.buttons["undoToast"].exists, "改好了没有撤销")
        app.buttons.matching(identifier: "mood.moment").firstMatch.tap()
        let delete = app.buttons["moodDetail.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        app.reveal(delete)
        delete.tap()
        XCTAssertTrue(app.staticTexts["已删除"].waitForExistence(timeout: 3), "删了没说")
    }

    /// 心情分析（以前「关于我 → 心情」的全部）和好时刻（按月分组）：打得开、每一屏跑审计；
    /// 「你说出过的感受」点一个展开说它的那几次原话，再点收起
    @MainActor func testAnalysisAndMoments() throws {
        let app = openMood()
        let link = app.buttons["mood.analysis"]
        app.reveal(link)
        link.tap()
        XCTAssertTrue(app.navigationBars["心情分析"].waitForExistence(timeout: 5), "心情分析没打开")
        XCTAssertTrue(app.staticTexts["心情和精力"].waitForExistence(timeout: 5), "没有心情和精力")
        pause()
        audit(app, "心情分析")
        for name in ["心情分析-下面", "心情分析-再下面"] {
            app.swipeUp(velocity: .slow)
            pause()
            audit(app, name)
        }
        let glad = app.buttons["mood.feeling.开心"]
        app.reveal(glad)
        XCTAssertEqual(glad.value as? String, "收着")
        glad.tap()
        let quote = app.buttons.matching(NSPredicate(format: "label CONTAINS '方案评审一次过了'")).firstMatch
        XCTAssertTrue(quote.waitForExistence(timeout: 3), "点了「开心」没展开那几次的原话")
        XCTAssertTrue(app.staticTexts["说「开心」的 12 次里，最近的 2 次"].exists, "没写是 12 次里的几次")
        XCTAssertEqual(glad.value as? String, "展开了")
        app.reveal(quote)
        pause()
        audit(app, "心情分析-感受展开")
        app.reveal(glad)
        glad.tap()
        XCTAssertEqual(glad.value as? String, "收着")
        app.goBack()
        let all = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '全部 15 个'")).firstMatch
        app.reveal(all)
        all.tap()
        XCTAssertTrue(app.navigationBars["好时刻"].waitForExistence(timeout: 5), "好时刻没打开")
        pause()
        audit(app, "好时刻")
    }

    /// 晚上问问心情（设置 → 提醒和推送，默认关）：打开以后手机上排好几个晚上（真的系统通知）
    @MainActor func testEveningQuestion() throws {
        allowNotifications()
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest", "-open", "/settings#reminders"]
        app.launch()
        // 设置页的开关是系统开关（3.0 收尾以前是带「开关」特征的按钮）：开是 1、关是 0
        let kinds = [XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.switch.rawValue]
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == '晚上问问心情' AND elementType IN %@", kinds)).firstMatch
        app.reveal(row)
        XCTAssertTrue(row.exists, "设置里没有「晚上问问心情」")
        XCTAssertEqual(row.value as? String, "0", "晚上问问心情默认要关着")
        row.tap()
        app.tap()  // 让通知权限的弹窗被接住
        let scheduled = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '手机上排好了'")).firstMatch
        XCTAssertTrue(scheduled.waitForExistence(timeout: 8), "打开以后没排上晚上的通知")
        pause()
        shot("设置-晚上问问心情", of: app.screenshot())
    }

    // MARK: - 共用

    /// 我的 → 心情
    @MainActor private func openMood() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        app.openTile("mood")
        XCTAssertTrue(app.buttons["mood.level.3"].waitForExistence(timeout: 8), "心情没打开")
        pause()
        return app
    }

    @MainActor private func audit(_ app: XCUIApplication, _ name: String) {
        shot(name, of: app.screenshot())
        XCTAssertNoThrow(try AppAudit.run(app, name: name))
    }
}
