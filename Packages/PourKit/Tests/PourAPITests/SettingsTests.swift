import Foundation
import Testing

@testable import PourAPI

/// 设置页的数据（Fixtures/settings.json：网页版演示数据的 /api/llm/status、/api/reminders……；
/// 评测演示数据里没跑过，照服务器 evals.ts 的样子写了一份）
@Suite("设置页的接口")
struct SettingsTests {
    struct All: Decodable {
        let llmStatus: API.LlmStatus
        let reminders: API.ReminderStatus
        let lan: API.LanInfo
        let growth: API.Growth
        let audit: API.AuditStatus
        let data: API.DataStatus
        let categories: API.CategoriesPage
        let candidates: API.Candidates
        let evals: API.Evals
    }

    func load() throws -> All {
        let url = try #require(
            Bundle.module.url(forResource: "settings", withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(All.self, from: try Data(contentsOf: url))
    }

    @Test func decodes() throws {
        let all = try load()
        #expect(all.llmStatus.model == "deepseek-v4-pro")
        #expect(all.llmStatus.keyMasked == nil)
        #expect(all.reminders.morning.time == "07:30")
        #expect(all.reminders.dnd.to == "07:00")
        #expect(all.reminders.keys.bark == nil)
        #expect(all.lan.rememberDays == 30)
        #expect(all.growth.weeks.count == 8)
        #expect(all.audit.exam?.passed == true)
        #expect(all.data.mode == "demo")
        #expect(all.categories.categories.first?.count == 61)
        #expect(all.categories.suggestions?.first?.kind == "tidy-other")
        #expect(all.candidates.candidates.count == 2)
        let run = try #require(all.evals.runs.first)
        #expect(run.summary["time"]?.rate == 0.97)
        #expect(run.failures.first?.problems.first?.dim == "time")
    }
}
