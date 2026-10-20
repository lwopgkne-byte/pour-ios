import Foundation
import Testing

@testable import PourAPI

/// 目标（Fixtures/goals.json、goal-1.json、goal-2.json：演示数据的 /api/goals、/api/goals/1、/api/goals/2）
@Suite("目标")
struct GoalsTests {
    func fixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(T.self, from: try Data(contentsOf: url))
    }

    @Test func list() throws {
        let goals = try fixture("goals", as: API.GoalsPage.self).goals
        #expect(goals.count == 9)
        let run = try #require(goals.first { $0.id == 1 })
        #expect(run.title == "今年跑 500 公里")
        #expect(Show.keyNumber(run, run.progress) == "101.9 / 500 公里")
        #expect(Show.paceText(run, run.progress) == "落后 35%")
        #expect(Show.describeTarget(run) == "累计至少 500 公里")
        #expect(run.monthRows?.first?.weeks?.isEmpty == false)
        let parent = try #require(goals.first { $0.kind == "parent" })
        #expect(parent.children?.count == 2)
        let sleep = try #require(goals.first { $0.calc == "avg" })
        #expect(Show.paceText(sleep, sleep.progress) == "差 0.7 小时")
        let done = try #require(goals.first { $0.kind == "completion" && $0.status == "done" })
        #expect(Show.keyNumber(done, done.progress) == "已完成")
    }

    @Test func detail() throws {
        let run = try fixture("goal-1", as: API.GoalDetail.self)
        #expect(run.goal.id == 1)
        #expect(run.series.count > 100)
        #expect(run.prediction.hasPrefix("按最近的速度"))
        #expect(!run.contributions.isEmpty)
        let fasting = try fixture("goal-2", as: API.GoalDetail.self)
        #expect(fasting.goal.calc == "streak")
        #expect(fasting.streakDays?.isEmpty == false)
    }

    @Test func numbers() {
        #expect(Show.fmtNum(612) == "612")
        #expect(Show.fmtNum(6.84) == "6.8")
        #expect(Show.fmtNum(101.94) == "101.9")
        #expect(Show.periodName("week", repeating: true) == "每周")
    }
}
