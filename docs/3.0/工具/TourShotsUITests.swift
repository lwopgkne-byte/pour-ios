import XCTest

/// 临时：3.0 方案用的「全部页面截图」（连 5199 演示服务器），不提交
final class TourShotsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor func testTour() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-serverURL", "http://127.0.0.1:5199"]
        app.launch()
        let menu = app.descendants(matching: .any)["today.menu"]
        _ = menu.waitForExistence(timeout: 15)
        sleep(4)
        shot(app, "00-画布-第1屏")
        if menu.exists {
            menu.tap()
            sleep(1)
            shot(app, "00-菜单")
            app.buttons["目标"].firstMatch.tap()
            sleep(3)
            pages(app, "40-目标")
            menu.tap()
            sleep(1)
            app.buttons["生活画布"].firstMatch.tap()
            sleep(2)
        }
        let paths: [(String, String)] = [
            ("10-回顾-列表", "/review"),
            ("11-回顾-昨天", "/review/2026-10-26"),
            ("12-回顾-周报", "/review/week/2026-10-19"),
            ("13-回顾-月报", "/review/month/2026-09"),
            ("20-钱-主页", "/money"),
            ("21-钱-留意的", "/money/watch"),
            ("22-钱-一天", "/money/day/2026-10-24"),
            ("23-钱-每一笔", "/money/list/2026-10"),
            ("24-钱-一样东西", "/money/thing/359"),
            ("25-钱-人情往来", "/money/renqing"),
            ("26-钱-和小李", "/money/renqing/小李"),
            ("30-关于我-主页", "/about"),
            ("31-关于我-心情", "/about/mood"),
            ("32-关于我-人", "/about/people"),
            ("33-关于我-你说的话", "/about/talk"),
            ("34-关于我-你的一年", "/about/year"),
            ("35-关于我-领域-工作", "/about/domain/工作"),
            ("36-关于我-领域-孩子", "/about/domain/孩子"),
            ("50-笔记库-原话", "/library"),
            ("51-笔记库-感悟", "/library?view=insights"),
            ("52-笔记库-好时刻", "/library?view=moments"),
            ("60-设置", "/settings"),
        ]
        for (name, path) in paths {
            let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path
            app.open(URL(string: "pour://open?path=\(encoded.replacingOccurrences(of: "&", with: "%26").replacingOccurrences(of: "?", with: "%3F"))")!)
            sleep(4)
            pages(app, name)
        }
        // 一天的钱里点第一笔：记录详情
        app.open(URL(string: "pour://open?path=/money/day/2026-10-24")!)
        sleep(4)
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS '¥'")).element(boundBy: 2)
        if row.exists {
            row.tap()
            sleep(3)
            pages(app, "27-钱-一笔的详情")
        }
        // 搜索、对话
        app.open(URL(string: "pour://open?path=/review")!)
        sleep(2)
        let search = app.buttons["搜索"].firstMatch
        if search.exists {
            search.tap()
            sleep(2)
            shot(app, "70-搜索")
            app.typeText("跑步")
            sleep(3)
            shot(app, "71-搜索-跑步")
        }
    }

    @MainActor func testMoneyOnly() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-serverURL", "http://127.0.0.1:5199"]
        app.launch()
        _ = app.descendants(matching: .any)["today.menu"].waitForExistence(timeout: 15)
        for (name, path) in [("20-钱-主页", "/money"), ("23-钱-每一笔", "/money/list/2026-10")] {
            app.open(URL(string: "pour://open?path=\(path)")!)
            sleep(4)
            pages(app, name)
        }
    }

    /// 一页从上往下，每屏一张；滑不动了就停
    @MainActor private func pages(_ app: XCUIApplication, _ name: String) {
        var last = XCUIScreen.main.screenshot().pngRepresentation
        keep(last, "\(name)-1")
        for index in 2...12 {
            app.swipeUp(velocity: .slow)
            sleep(1)
            let now = XCUIScreen.main.screenshot().pngRepresentation
            if now == last { break }
            keep(now, "\(name)-\(index)")
            last = now
        }
        for _ in 0..<6 { app.swipeDown(velocity: .fast) }
    }

    @MainActor private func shot(_ app: XCUIApplication, _ name: String) {
        keep(XCUIScreen.main.screenshot().pngRepresentation, name)
    }

    private func keep(_ png: Data, _ name: String) {
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
