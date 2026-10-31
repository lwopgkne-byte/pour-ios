import UIKit
import XCTest

/// 全部页面截图（docs/3.0/03-开发计划.md 2.1 第 5 条）：连一台演示数据的服务器，把每一页从上往下一屏一屏截下来，
/// 改之前、改之后并排对照用。平时的检查里不跑：只有 scripts/tour-shots.sh 给了服务器地址才跑，
/// 用法见那个脚本。日子都按服务器的「今天」算（演示数据每天重新生成，写死的日子过几天就对不上）
final class TourShotsUITests: XCTestCase {
    /// scripts/tour-shots.sh 用 TEST_RUNNER_ 开头的环境变量传进来（xcodebuild 去掉前缀再给测试）
    private let settings = ProcessInfo.processInfo.environment

    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor func testTour() throws {
        guard let server = settings["POUR_TOUR_SERVER"], !server.isEmpty else {
            throw XCTSkip("只在 scripts/tour-shots.sh 里跑（要给一台演示数据服务器的地址）")
        }
        let days = try TourDays(today: settings["POUR_TOUR_TODAY"] ?? "")
        let app = XCUIApplication()
        app.launchArguments += ["-serverURL", server]
        app.launch()
        sleep(6)
        pages(app, "00-画布")

        for (name, path) in tourPaths(days) {
            try open(app, path)
            sleep(4)
            pages(app, name)
        }

        // 搜索：画布右上角
        try open(app, "/")
        sleep(2)
        let search = app.buttons["搜索"].firstMatch
        if search.waitForExistence(timeout: 5) {
            search.tap()
            sleep(2)
            shot("70-搜索")
            app.typeText("跑步")
            sleep(3)
            shot("71-搜索-跑步")
        }
    }

    /// 要截的页（名字、页面地址）：编号和现状截图 docs/3.0/现状截图/ 一样，前后好对
    private func tourPaths(_ days: TourDays) -> [(String, String)] {
        var paths: [(String, String)] = [
            ("05-我的", "/me"),
            ("10-回顾-列表", "/review"),
            ("11-回顾-昨天", "/review/\(days.yesterday)"),
            ("12-回顾-周报", "/review/week/\(days.lastWeekMonday)"),
            ("13-回顾-月报", "/review/month/\(days.lastMonth)"),
            ("20-钱-主页", "/money"),
            ("21-钱-留意的", "/money/watch"),
            ("22-钱-一天", "/money/day/\(days.yesterday)"),
            ("23-钱-每一笔", "/money/list/\(days.thisMonth)"),
        ]
        if let thing = settings["POUR_TOUR_THING"], !thing.isEmpty {
            paths.append(("24-钱-一样东西", "/money/thing/\(thing)"))
        }
        paths.append(("25-钱-人情往来", "/money/renqing"))
        if let person = settings["POUR_TOUR_PERSON"], !person.isEmpty {
            paths.append(("26-钱-和一个人", "/money/renqing/\(person)"))
        }
        paths += [
            ("30-关于我-主页", "/about"),
            ("31-关于我-心情", "/about/mood"),
            ("32-关于我-人", "/about/people"),
            ("33-关于我-你说的话", "/about/talk"),
            ("34-关于我-你的一年", "/about/year"),
            ("35-关于我-领域-工作", "/about/domain/工作"),
            ("36-关于我-领域-孩子", "/about/domain/孩子"),
            ("40-目标", "/goals"),
            ("50-笔记库-原话", "/library"),
            ("51-笔记库-感悟", "/library?view=insights"),
            ("52-笔记库-好时刻", "/library?view=moments"),
            ("60-设置", "/settings"),
        ]
        return paths
    }

    /// 用 pour://open?path= 打开一页（和推送、对话里的链接走同一条路）
    @MainActor private func open(_ app: XCUIApplication, _ path: String) throws {
        // 除了字母、数字和「/-_.」都转义：中文、path 里的「?」「=」「&」不会被当成链接自己的
        let plain = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/-_.")
        let value = try XCTUnwrap(path.addingPercentEncoding(withAllowedCharacters: plain))
        app.open(try XCTUnwrap(URL(string: "pour://open?path=\(value)"), "链接拼不出来：\(path)"))
    }

    /// 一页从上往下，每屏一张；滑不动了就停（不看最上面的状态栏：时间走了一分钟不算动了），再滑回顶上
    @MainActor private func pages(_ app: XCUIApplication, _ name: String) {
        var shot = XCUIScreen.main.screenshot()
        var last = Self.content(of: shot)
        keep(shot.pngRepresentation, "\(name)-1")
        for index in 2...12 {
            app.swipeUp(velocity: .slow)
            sleep(1)
            shot = XCUIScreen.main.screenshot()
            let now = Self.content(of: shot)
            if now == last { break }
            keep(shot.pngRepresentation, "\(name)-\(index)")
            last = now
        }
        for _ in 0..<6 { app.swipeDown(velocity: .fast) }
    }

    /// 截图里状态栏以下的那一块（比较滑没滑动用）
    private static func content(of shot: XCUIScreenshot) -> Data {
        let image = shot.image
        guard let bitmap = image.cgImage else { return shot.pngRepresentation }
        let cut = Int(60 * image.scale)
        let rect = CGRect(x: 0, y: cut, width: bitmap.width, height: max(1, bitmap.height - cut))
        guard let cropped = bitmap.cropping(to: rect) else { return shot.pngRepresentation }
        return UIImage(cgImage: cropped).pngData() ?? shot.pngRepresentation
    }

    @MainActor private func shot(_ name: String) {
        keep(XCUIScreen.main.screenshot().pngRepresentation, name)
    }

    private func keep(_ png: Data, _ name: String) {
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

/// 按服务器的「今天」算出要截的那几天（北京时间的日历，和服务器一样）
struct TourDays {
    let yesterday: String
    let lastWeekMonday: String
    let lastMonth: String
    let thisMonth: String

    init(today: String) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        calendar.firstWeekday = 2
        let day = DateFormatter()
        day.calendar = calendar
        day.timeZone = calendar.timeZone
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyy-MM-dd"
        let month = DateFormatter()
        month.calendar = calendar
        month.timeZone = calendar.timeZone
        month.locale = day.locale
        month.dateFormat = "yyyy-MM"
        let now = try XCTUnwrap(day.date(from: today), "服务器的今天不对：\(today)")
        let back = { (component: Calendar.Component, value: Int) throws -> Date in
            try XCTUnwrap(calendar.date(byAdding: component, value: value, to: now))
        }
        yesterday = day.string(from: try back(.day, -1))
        let thisWeek = try XCTUnwrap(calendar.dateInterval(of: .weekOfYear, for: now)?.start)
        lastWeekMonday = day.string(from: try XCTUnwrap(calendar.date(byAdding: .day, value: -7, to: thisWeek)))
        lastMonth = month.string(from: try back(.month, -1))
        thisMonth = month.string(from: now)
    }
}
