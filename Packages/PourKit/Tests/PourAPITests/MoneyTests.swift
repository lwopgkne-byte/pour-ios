import Foundation
import Testing

@testable import PourAPI

/// 钱（Fixtures/money-*.json：演示数据的 /api/money/2026-10、/overview、/watch、/findings、/day/2026-10-18、
/// /thing/22、/renqing、/renqing/小李）
@Suite("钱")
struct MoneyTests {
    func fixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(T.self, from: try Data(contentsOf: url))
    }

    @Test func month() throws {
        let page = try fixture("money-month", as: API.MoneyMonth.self)
        #expect(page.month == "2026-10" && page.current)
        #expect(page.spent == 5924 && page.count == 51)
        #expect(page.compare?.text.hasPrefix("比上个月这时候少") == true)
        #expect(page.fixed.series.count == 4)
        #expect(page.counts["daily"] == 51 && page.counts["gift"] == nil)
        #expect(page.items.first?.domain.name == "饮食")
        #expect(page.prevMonth == "2026-09" && page.nextMonth == nil)
    }

    @Test func overview() throws {
        let page = try fixture("money-overview", as: API.MoneyOverview.self)
        #expect(page.watch.count == 4)
        #expect(page.who?.family?.share == "大半")
        #expect(page.worth.good.first?.perUse == 225)
        #expect(page.worth.regret.first?.verdict?.tone == "regret")
        #expect(page.renqing?.into == 3100)
    }

    @Test func watch() throws {
        let page = try fixture("money-watch", as: API.MoneyWatchPage.self)
        #expect(page.pending.reimburse?.items.count == 1)
        #expect(page.pending.lends.first?.days == 11)
        #expect(page.fixed.rows.first { $0.unused != nil }?.name == "瑜伽月卡")
        #expect(page.packs.first?.pack == 24)
        #expect(page.frequent.last?.price == "比8月贵了 ¥11")
        #expect(page.quotes["481"]?.hasPrefix("老同学") == true)
        #expect(page.budgets.first?.tone == "good")
    }

    @Test func pages() throws {
        let findings = try fixture("money-findings", as: API.MoneyFindingsPage.self)
        #expect(findings.findings.first?.bars.count == 2 && findings.findings.first?.vote == nil)
        let day = try fixture("money-day", as: API.MoneyDayPage.self)
        #expect(day.items.count == 4 && day.feelings == ["烦躁", "放松"])
        let thing = try fixture("money-thing", as: API.MoneyThingPage.self)
        #expect(thing.uses.count == 12 && thing.bought?.text == "买了个空气炸锅 399")
        let renqing = try fixture("money-renqing", as: API.RenqingPage.self)
        #expect(renqing.people.first { $0.name == "小王" }?.relation == "同事")
        let person = try fixture("money-person", as: API.RenqingPersonPage.self)
        #expect(person.rows.first { !$0.together.isEmpty }?.together == ["大姐", "老同学"])
    }

    /// 钱怎么写：遮住、标签、给谁
    @Test func words() throws {
        #expect(Show.yuan(3126, hide: false) == "¥3,126")
        #expect(Show.yuan(18500, hide: false, plus: true) == "+¥18,500")
        #expect(Show.yuan(12, hide: true) == "¥•••")
        #expect(Show.maskYuan("一般花 ¥131，最多 ¥1,200.5", hide: true) == "一般花 ¥•••，最多 ¥•••")
        #expect(Show.monthDay("2026-08-09") == "8月9日")
        #expect(Show.moneyPath("2026-10", today: "2026-10-20") == "/money")
        #expect(Show.moneyPath("2026-09", today: "2026-10-20") == "/money/2026-09")
        let items = try fixture("money-month", as: API.MoneyMonth.self).items
        let shoes = try #require(items.first { $0.name == "给儿子买运动鞋" })
        #expect(Show.whoLabel(shoes).isEmpty)
        let fixed = try #require(items.first { $0.kind == "fixed" })
        #expect(Show.kindTag(fixed) == "固定的")
        let watch = try fixture("money-watch", as: API.MoneyWatchPage.self)
        let yoga = try #require(watch.fixed.rows.first { $0.unused != nil })
        #expect(Show.unusedText(yoga) == "10月8日又扣了；9月1日以后没说到瑜伽")
        #expect(Show.kindTag(watch.pending.lends[0].item) == "借出去")
    }
}
