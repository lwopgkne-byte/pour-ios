import Foundation
import Testing

@testable import PourAPI

/// 回顾（Fixtures/review-*.json：演示数据的 /api/review、/api/review/daily/2026-10-18、
/// /api/review/period/weekly/2026-10-12、/api/review/period/monthly/2026-09-01）
@Suite("回顾")
struct ReviewTests {
    func fixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(T.self, from: try Data(contentsOf: url))
    }

    @Test func list() throws {
        let items = try fixture("review-list", as: API.ReviewList.self).items
        #expect(items.first?.kind == "weekly")
        #expect(items.contains { $0.kind == "daily" && $0.day == "2026-10-18" })
    }

    @Test func daily() throws {
        let page = try fixture("review-daily", as: API.DailyReviewPage.self)
        let review = page.review
        #expect(review.day == "2026-10-18")
        #expect(review.numbers.first?.parts.first?.number == "8")
        #expect(review.groups.first?.items?.isEmpty == false)
        #expect(review.entries.count == 16)
        #expect(page.weekly == "2026-10-12")
    }

    @Test func periods() throws {
        let weekly = try fixture("review-weekly", as: API.PeriodReviewPage.self).review
        #expect(weekly.kind == "weekly" && weekly.days.count == 7)
        #expect(weekly.groups.first?.text?.hasPrefix("跑步") == true)
        #expect(weekly.mood?.moments.count == 3)
        let monthly = try fixture("review-monthly", as: API.PeriodReviewPage.self).review
        #expect(monthly.weeklyReports.count == 5)
        #expect(monthly.moodNote?.isEmpty == false)
    }

    @Test func words() {
        #expect(Show.weekRowLabel("2026-10-12") == "周一 12")
        #expect(Show.periodRelative("weekly", from: "2026-10-12", today: "2026-10-19") == "上周")
        #expect(Show.periodRelative("monthly", from: "2026-09-01", today: "2026-10-19") == "上个月")
        #expect(Show.periodRelative("weekly", from: "2026-10-05", today: "2026-10-19") == nil)
        #expect(Show.monthName("2026-09") == "9月")
    }
}
