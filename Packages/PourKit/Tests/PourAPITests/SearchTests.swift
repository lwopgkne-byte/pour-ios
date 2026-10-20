import Foundation
import Testing

@testable import PourAPI

/// 搜索和问答（Fixtures/search-run.json：演示数据的 /api/search?q=跑步；answer.json：带来源、五种图表、报告的回答）
@Suite("搜索和问答")
struct SearchTests {
    func fixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(T.self, from: try Data(contentsOf: url))
    }

    @Test func search() throws {
        let result = try fixture("search-run", as: API.SearchResult.self)
        #expect(result.hits.first?.via == "both" && result.hits.first?.noteId == 210)
        #expect(result.hits.dropFirst().allSatisfy { $0.via == "semantic" })
        #expect(result.goals.isEmpty && result.day == nil && result.semantic?.state == "ready")
    }

    @Test func answer() throws {
        let answer = try fixture("answer", as: API.Answer.self)
        #expect(answer.sources?.map(\.noteId) == [210, 295])
        #expect(answer.reports?.first?.id == 84)
        let charts = try #require(answer.charts)
        #expect(charts.count == 6)
        guard case .series(let bar) = charts[0], case .ring(let ring) = charts[2], case .unknown("radar") = charts[5]
        else {
            Issue.record("图表的种类认错了")
            return
        }
        #expect(bar.type == "bar" && bar.points[0].value == nil && bar.target == 5)
        #expect(ring.tone == "good")
        // 存下来再读回来一样
        let again = try JSONDecoder().decode(API.Answer.self, from: try JSONEncoder().encode(answer))
        #expect(again == answer)
    }

    @Test func between() {
        #expect(Show.between(3, words: Show.moodWords) == "一般")
        #expect(Show.between(3.5, words: Show.moodWords) == "在一般和挺好之间")
        #expect(Show.between(0.8, words: Show.moodWords) == "很差")
    }
}
