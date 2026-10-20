import Foundation
import Testing

@testable import PourAPI

/// 关于我（Fixtures/about-*.json：演示数据的 /api/about/home、care、mood、people、talk、year/2026、domain/diet，
/// /api/board/time、metrics、trend、heatmap）
@Suite("关于我")
struct AboutTests {
    func fixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(T.self, from: try Data(contentsOf: url))
    }

    @Test func home() throws {
        let home = try fixture("about-home", as: API.MeHomePage.self)
        #expect(home.composition.tiles.first?.key == "diet")
        #expect(home.angles.map(\.key) == ["money", "people", "mood", "talk"])
        #expect(home.angles.first { $0.key == "talk" }?.clock?.hours.count == 24)
        #expect(home.recipe?.size == 10)
        #expect(home.changes.first?.color == "mood")
        let care = try fixture("about-care", as: API.MeCare.self)
        #expect(care.rows.first?.said.first?.kind == "goal" && !care.hidden)
        let time = try fixture("about-time", as: API.TimePage.self)
        #expect(time.items.first?.category == "work")
    }

    @Test func pages() throws {
        let mood = try fixture("about-mood", as: API.MeMoodPage.self)
        #expect(mood.word == "一般" && mood.week?.bars.count == 7)
        #expect(mood.when?.parts.count == 4 && mood.feelings?.words.first?.word == "开心")
        let people = try fixture("about-people", as: API.MePeoplePage.self)
        #expect(people.people.first?.name == "儿子" && people.findings.count == 2)
        let talk = try fixture("about-talk", as: API.MeTalkPage.self)
        #expect(talk.clock.total == 362 && talk.themes.first?.name == nil)
        let year = try fixture("about-year", as: API.MeYear.self)
        #expect(year.streak?.days == 63 && !year.enough)
        let domain = try fixture("about-domain", as: API.MeDomainPage.self)
        #expect(domain.key == "diet" && domain.mood?.tone == "same")
    }

    @Test func board() throws {
        let metrics = try fixture("about-metrics", as: API.BoardMetrics.self).metrics
        #expect(metrics.first?.id == "sleep:duration")
        let trend = try fixture("about-trend", as: API.BoardTrend.self)
        #expect(trend.metric.how == "avg" && !trend.points.isEmpty)
        let heat = try fixture("about-heat", as: API.YearHeatPage.self)
        #expect(heat.unit == "条" && heat.label == "记录量")
    }

    @Test func moodTrend() throws {
        let trend = try fixture("about-trend-mood", as: API.BoardTrend.self)
        #expect(trend.each?.first == [3] && trend.metric.category == nil)
    }

    @Test func moodSources() throws {
        let sources = try fixture("about-sources", as: API.MoodSources.self)
        #expect(sources.goodTotal == 12 && sources.when.good["glimpse"] == 4)
        #expect(sources.mirror.last?.key == "glimpse" && sources.mirror.first { $0.timeUnder1 } != nil)
        #expect(sources.people.last?.name == "没提到别人" && sources.enough.time)
        #expect(sources.examples["when:good:glimpse"]?.isEmpty == false)
    }
}
