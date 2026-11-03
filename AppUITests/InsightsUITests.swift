import XCTest

/// 3.0 感悟（01 需求文档 7.6、06 交互细节第 5 节和 10.3）：第一屏今天重温的一句，点了翻过来看原话，换一句换别的
/// （点按钮、往左滑都行）；标签胶囊带条数、「语录 ★」只看语录；★ 收藏 / 取消；按住一张出菜单；搜；一条感悟（改字、
/// 收藏成语录、删除带撤销）；记一句（最上面多一张「整理中」、轻提示能撤销）；分享成图片（三种样子、拷贝）。
/// 用假服务器（-uiTest）：演示数据的 13 句感悟、7 句语录，今天重温是一个月前的今天那句
final class InsightsUITests: XCTestCase, TodoTesting {
    override func setUp() {
        continueAfterFailure = false
    }

    /// 第一屏：今天重温 + 收藏 · 分享 · 换一句；点卡片翻过来看原话和「以前也说过类似的」，再点翻回来；换一句、往左滑都换别的
    @MainActor func testRevisit() throws {
        let app = openInsights()
        let card = app.descendants(matching: .any)["insights.revisit"]
        XCTAssertTrue(card.label.contains("一个月前的今天你说"), "今天重温不是一个月前的今天那句：\(card.label)")
        XCTAssertTrue(card.isHittable, "今天重温要在第一屏")
        XCTAssertTrue(app.buttons["insights.revisit.next"].isHittable, "换一句要在第一屏")
        audit(app, "感悟")
        card.tap()
        let related = app.buttons["insights.revisit.related"]
        XCTAssertTrue(related.waitForExistence(timeout: 3), "翻过来没有「以前也说过类似的」")
        XCTAssertTrue(app.staticTexts["你当时说的"].exists, "翻过来没写「你当时说的」")
        pause()
        audit(app, "感悟-翻过来")
        related.tap()
        XCTAssertTrue(app.buttons["insightDetail.done"].waitForExistence(timeout: 3), "点「以前也说过类似的」没打开这一条")
        XCTAssertTrue(app.staticTexts["以前也说过类似的 3 条"].waitForExistence(timeout: 3), "一条感悟里没有类似的几条")
        app.buttons["关闭"].tap()
        pause()
        // 再点翻回来
        app.descendants(matching: .any)["insights.revisit.back"].tap()
        XCTAssertTrue(card.waitForExistence(timeout: 3), "点背面没翻回来")
        let first = card.label
        app.buttons["insights.revisit.next"].tap()
        XCTAssertTrue(waitForChange(card, from: first), "换一句没换")
        let second = card.label
        card.swipeLeft()
        XCTAssertTrue(waitForChange(card, from: second), "往左滑没换一句")
        let star = app.buttons["insights.revisit.star"]
        XCTAssertEqual(star.label, "收藏")
        star.tap()
        XCTAssertTrue(waitFor(star, labelContains: "已收藏"), "收藏了没变「已收藏」")
    }

    /// 标签胶囊带条数，「语录 ★」只看语录；★ 点了收藏、条数跟着变；搜（字面上有的）；按住一张能删，删了能撤销
    @MainActor func testListAndMenu() throws {
        let app = openInsights()
        let starred = app.buttons["insights.filter.starred"]
        XCTAssertTrue(starred.label.contains("7"), "语录 ★ 没写几句：\(starred.label)")
        starred.tap()
        XCTAssertEqual(cards(app).count, 7, "只看语录不是 7 张")
        pause()
        audit(app, "感悟-语录")
        starred.tap()
        XCTAssertEqual(cards(app).count, 13, "再点一下没回到全部")
        let star = app.buttons["insight.522.star"]
        app.reveal(star)
        XCTAssertEqual(star.label, "收藏成语录")
        star.tap()
        XCTAssertTrue(waitFor(star, labelContains: "取消收藏"), "点星没收藏上")
        XCTAssertTrue(waitFor(starred, labelContains: "8"), "收藏以后语录 ★ 不是 8 句：\(starred.label)")
        // 按住一张：收藏 / 取消、分享成图片、看原话、删除
        let row = app.buttons["insight.472"]
        app.reveal(row)
        row.press(forDuration: 1.2)
        for name in ["收藏成语录", "分享成图片", "看原话", "删除"] {
            XCTAssertTrue(app.buttons[name].waitForExistence(timeout: 3), "按住没有「\(name)」")
        }
        shot("感悟-按住", of: app.screenshot())
        app.buttons["删除"].tap()
        XCTAssertTrue(app.staticTexts["删了这句感悟"].waitForExistence(timeout: 3), "删了没说")
        // 轻提示只留 4 秒：马上看、马上撤销
        XCTAssertFalse(row.exists, "删了的还在")
        app.buttons["undoToast"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 3), "撤销以后没放回来")
        // 搜
        let field = app.searchFields.firstMatch
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(field.waitForExistence(timeout: 3), "没有搜索框")
        field.tap()
        field.typeText("专注")
        XCTAssertTrue(app.staticTexts["搜到 3 句（意思相近的也算）"].waitForExistence(timeout: 5), "搜「专注」不是 3 句")
        pause()
        audit(app, "感悟-搜")
    }

    /// 一条感悟：大宋体直接改字（「好了」能撤销）；「收藏成语录」开关马上生效；删除带撤销
    @MainActor func testDetail() throws {
        let app = openInsights()
        let row = app.buttons["insight.571"]
        app.reveal(row)
        row.tap()
        let quote = app.descendants(matching: .any)["insightDetail.quote"]
        XCTAssertTrue(quote.waitForExistence(timeout: 3), "一条感悟没打开")
        XCTAssertTrue((quote.value as? String ?? "").contains("关掉消息"), "那一句不对：\(quote.value ?? "")")
        let toggle = app.switches["insightDetail.star"]
        XCTAssertEqual(toggle.value as? String, "1", "收藏了的开关要开着")
        XCTAssertTrue(app.staticTexts["这是 AI 从你的话里摘出来的，点字就能改"].exists)
        expandSheet(app, from: app.buttons["关闭"])
        audit(app, "一条感悟")
        quote.tap()
        quote.typeText("！")
        app.buttons["insightDetail.done"].tap()
        XCTAssertTrue(app.staticTexts["改好了"].waitForExistence(timeout: 3), "改好了没说")
        XCTAssertTrue(app.buttons["undoToast"].exists, "改好了没有撤销")
        XCTAssertTrue(waitFor(row, labelContains: "！"), "改的字没到卡片上：\(row.label)")
        row.tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertTrue(waitFor(toggle, value: "0"), "关不掉收藏成语录")
        let delete = app.buttons["insightDetail.delete"]
        app.reveal(delete)
        delete.tap()
        XCTAssertTrue(app.staticTexts["删了这句感悟"].waitForExistence(timeout: 3), "删了没说")
        XCTAssertFalse(row.waitForExistence(timeout: 1), "删了的还在")
    }

    /// 记一句：大宋体输入、「记下」以后最上面多一张「整理中」、轻提示能撤销；分享成图片：三种样子、拷贝；「我的」的快捷也能记一句
    @MainActor func testAddAndShare() throws {
        let app = openInsights()
        app.buttons["insights.add"].tap()
        let text = app.descendants(matching: .any)["insightAdd.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 3), "记一句没打开")
        XCTAssertFalse(app.buttons["insightAdd.save"].isEnabled, "没写字时「记下」要是灰的")
        text.typeText("先把一件事做完，再开始下一件。")
        pause()
        audit(app, "记一句")
        app.buttons["insightAdd.save"].tap()
        XCTAssertTrue(app.staticTexts["记下了，收藏成你的语录"].waitForExistence(timeout: 3), "记下了没说")
        XCTAssertTrue(app.buttons["undoToast"].exists, "记一句没有撤销")
        let pending = app.buttons["insight.pending"]
        XCTAssertTrue(pending.waitForExistence(timeout: 3), "最上面没多一张")
        XCTAssertTrue(pending.label.contains("整理中"), "刚记的没写整理中：\(pending.label)")
        app.buttons["insights.revisit.share"].tap()
        let image = app.descendants(matching: .any)["share.card"]
        XCTAssertTrue(image.waitForExistence(timeout: 3), "分享成图片没打开")
        XCTAssertTrue(image.label.contains("—— 我，2026年10月"), "图片上没写「—— 我，几月几日」：\(image.label)")
        pause()
        audit(app, "分享成图片")
        app.buttons["share.look.ink"].tap()
        XCTAssertTrue(app.buttons["share.look.ink"].isSelected, "墨色没选上")
        XCTAssertTrue(app.buttons["share.send"].exists, "没有发给朋友")
        pause()
        shot("分享成图片-墨色", of: app.screenshot())
        app.buttons["share.copy"].tap()
        XCTAssertTrue(app.staticTexts["拷贝好了，去微信里粘贴"].waitForExistence(timeout: 3), "拷贝了没说")
        app.goBackToCanvas()
        app.buttons["today.me"].tap()
        let quick = app.buttons["hub.quick.记一句"]
        XCTAssertTrue(quick.waitForExistence(timeout: 5), "「我的」没有记一句")
        quick.tap()
        XCTAssertTrue(text.waitForExistence(timeout: 3), "「我的」的记一句没打开弹层")
    }

    // MARK: - 共用

    /// 我的 → 感悟
    @MainActor private func openInsights() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        app.launch()
        app.openTile("insights")
        XCTAssertTrue(
            app.descendants(matching: .any)["insights.revisit"].waitForExistence(timeout: 8), "感悟没打开")
        pause()
        return app
    }

    /// 按月分组的那些卡片（不算星、不算刚记下的）
    @MainActor private func cards(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(
            NSPredicate(format: "identifier MATCHES 'insight\\\\.[0-9]+'"))
    }

    @MainActor private func waitForChange(_ element: XCUIElement, from label: String) -> Bool {
        let deadline = Date().addingTimeInterval(4)
        while Date() < deadline {
            if element.exists, element.label != label { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }

    @MainActor private func audit(_ app: XCUIApplication, _ name: String) {
        shot(name, of: app.screenshot())
        XCTAssertNoThrow(try AppAudit.run(app, name: name))
    }
}
