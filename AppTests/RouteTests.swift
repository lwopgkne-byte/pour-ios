import Testing

@testable import Pour

/// 3.0 外壳的页面地址（docs/3.0/07-开发任务清单.md 1.6）：服务器、对话、推送、小组件里的每一种链接都还认得，
/// 推哪一页、返回回到哪
@Suite("3.0 外壳：链接和导航栈")
@MainActor
struct RouteTests {
    /// 全部链接的对照表：地址 → 推哪一页（服务器和对话里出现过的样子都在这里）
    @Test(arguments: [
        ("/me", Route.hub),
        ("/review", .review(nil)),
        ("/review/2026-10-18", .review(.daily("2026-10-18"))),
        ("/review/week/2026-10-12", .review(.period("weekly", "2026-10-12"))),
        ("/review/month/2026-09", .review(.period("monthly", "2026-09-01"))),
        ("/money", .money(.month(nil))),
        ("/money/2026-09", .money(.month("2026-09"))),
        ("/money/day/2026-10-18", .money(.day("2026-10-18"))),
        ("/money/list/2026-10", .money(.list("2026-10", MoneyFilter()))),
        ("/money/list/2026-10?kind=fixed", .money(.list("2026-10", MoneyFilter(kind: "fixed")))),
        ("/money/watch", .money(.watch)),
        ("/money/thing/22", .money(.thing(22))),
        ("/money/renqing", .money(.renqing)),
        ("/money/renqing/小李", .money(.person("小李"))),
        ("/money/renqing/%E5%B0%8F%E6%9D%8E", .money(.person("小李"))),
        ("/about", .about(.home, ask: nil)),
        ("/about?find=老地方", .about(.home, ask: KnownAsk(item: nil, find: "老地方"))),
        ("/about?item=person:小王", .about(.home, ask: KnownAsk(item: "person:小王", find: nil))),
        ("/about/mood", .about(.mood, ask: nil)),
        ("/about/people", .about(.people, ask: nil)),
        ("/about/talk", .about(.talk, ask: nil)),
        ("/about/year", .about(.year(nil), ask: nil)),
        ("/about/year/2025", .about(.year(2025), ask: nil)),
        ("/about/domain/diet", .about(.domain("diet"), ask: nil)),
        ("/goals", .goals),
        ("/library", .library(LibraryAsk())),
        ("/library?note=12", .library(LibraryAsk(note: 12))),
        ("/library?view=insights", .library(LibraryAsk(view: "insights"))),
        ("/library?view=moments", .library(LibraryAsk(view: "moments"))),
        ("/library?tag=小王", .library(LibraryAsk(tag: "小王"))),
        ("/settings", .settings(nil)),
        ("/settings#data", .settings("data")),
        ("/settings#health", .settings("health")),
    ])
    func everyLinkOpensItsPage(path: String, route: Route) {
        #expect(Route(path: path) == route)
    }

    @Test(arguments: ["/", "/nothing", "/money/day", "/about/what", "/review/week", "/goalsx", "/me/x", ""])
    func unknownLinksDoNothing(path: String) {
        #expect(Route(path: path) == nil)
    }

    private func model() -> AppModel {
        AppModel(client: StubServer.client(), health: .forTests(), calendar: .forTests())
    }

    @Test func pushingAndGoingBack() {
        let model = model()
        model.open("/me")
        model.open("/money")
        model.open("/money/day/2026-10-18")
        #expect(model.stack == [.hub, .money(.month(nil)), .money(.day("2026-10-18"))])
        // 左右滑翻到上一天：换掉这一页，不再推一层（不然要按十次返回）
        model.open("/money/day/2026-10-17")
        #expect(model.stack == [.hub, .money(.month(nil)), .money(.day("2026-10-17"))])
        // 页面里点「钱」回到这个月：它就在下面，退回去
        model.open("/money")
        #expect(model.stack == [.hub, .money(.month(nil))])
        // 「/」回到画布
        model.open("/")
        #expect(model.stack.isEmpty)
    }

    @Test func linksFromOutsideStartAtTheCanvas() {
        let model = model()
        model.open("/me")
        model.open("/goals")
        model.chatOpen = true
        // 推送、小组件、pour://open?path=：画布在最底下，只推这一页
        model.openLink("/review/2026-10-18")
        #expect(model.stack == [.review(.daily("2026-10-18"))])
        #expect(!model.chatOpen)
        model.openLink("/nothing")
        #expect(model.stack.isEmpty)
    }

    /// 说一句带上在哪一页说的（docs/3.0/01-需求文档.md 2.2）
    @Test func sayContextFollowsThePage() {
        let model = model()
        #expect(model.sayContext == nil)
        model.open("/money/watch")
        #expect(model.sayContext == "money")
        model.open("/goals")
        #expect(model.sayContext == "goals")
        model.open("/about/mood")
        #expect(model.sayContext == "mood")
        model.open("/library?view=insights")
        #expect(model.sayContext == "insights")
        model.open("/library")
        #expect(model.sayContext == nil)
        model.goHome()
        #expect(model.sayContext == nil)
    }

    @Test func backButtonsSayThePreviousPage() {
        #expect(Route.money(.renqing).title == "人情往来")
        #expect(Route.about(.mood, ask: nil).title == "心情")
        #expect(Route.review(.period("monthly", "2026-09-01")).title == "月报")
        #expect(Route.hub.title == "我的")
    }

    /// 「我的」里每个格子都有样子、点了有地方去（键和服务器 HUB_TILES 一样）
    @Test func everyHubTileIsComplete() {
        let keys = HubCatalog.groups.flatMap(\.tiles)
        #expect(keys.count == 22)
        #expect(Set(keys).count == keys.count)
        for key in keys {
            guard let tile = HubCatalog.tiles[key] else {
                Issue.record("没有格子 \(key)")
                continue
            }
            #expect(tile.name.count <= 4, "\(key) 的名字超过 4 个字")
            // 日历先打开「跳到某一天」（第 10 步做日历页）
            guard key != "calendar" else { continue }
            let path = tile.path(today: "2026-10-31")
            #expect(path == "/" || Route(path: path) != nil, "\(key) 点了没地方去：\(path)")
        }
        #expect(HubCatalog.defaultFavorites.allSatisfy { HubCatalog.tiles[$0] != nil })
        #expect(HubCatalog.search("报销").map(\.id) == ["watch"])
        #expect(HubCatalog.search("红包").map(\.id) == ["renqing"])
        #expect(HubCatalog.search("没有这个").isEmpty)
    }
}
