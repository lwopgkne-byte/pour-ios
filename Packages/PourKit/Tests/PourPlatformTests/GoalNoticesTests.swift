import Foundation
import Testing
import UserNotifications

@testable import PourPlatform

@Suite("目标的通知")
struct GoalNoticesTests {
    private let now = Date(timeIntervalSince1970: 1_793_500_000)  // 2026-10-31 前后
    private let calendar = Calendar(identifier: .gregorian)

    private func notice(_ when: GoalNotices.Notice.When, key: String = "ifthen.4") -> GoalNotices.Notice {
        GoalNotices.Notice(key: key, title: "如果下班到家了，就先换上跑鞋", body: "「今年跑 500 公里」", when: when, path: "/goals/4")
    }

    @Test func weekdaysBecomeOneRepeatingTriggerEach() throws {
        let work = notice(.weekly(days: [0, 1, 2, 3, 4], hour: 18, minute: 30))
        let requests = GoalNotices.requests(work, now: now, calendar: calendar)
        #expect(requests.map(\.identifier) == (0...4).map { "pour.goal.ifthen.4.\($0)" })
        let first = try #require(requests.first?.trigger as? UNCalendarNotificationTrigger)
        #expect(first.repeats)
        #expect(first.dateComponents == DateComponents(hour: 18, minute: 30, weekday: 2))
        #expect(requests.first?.content.userInfo["path"] as? String == "/goals/4")
        #expect(GoalNotices.slots([work], now: now, calendar: calendar) == 5)
    }

    @Test func sundayIsSystemWeekdayOneAndEverydayIsOneTrigger() throws {
        #expect(GoalNotices.weekday(6) == 1)
        #expect(GoalNotices.weekday(5) == 7)
        let daily = GoalNotices.requests(notice(.weekly(days: [], hour: 7, minute: 0)), now: now, calendar: calendar)
        #expect(daily.map(\.identifier) == ["pour.goal.ifthen.4"])
        let trigger = try #require(daily.first?.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents == DateComponents(hour: 7, minute: 0))
    }

    @Test func onceInThePastIsSkipped() {
        let past = notice(.once("2020-01-01T20:00"), key: "resume.4")
        #expect(GoalNotices.requests(past, now: now, calendar: calendar).isEmpty)
        let later = notice(.once("2030-11-27T20:00"), key: "resume.4")
        #expect(GoalNotices.requests(later, now: now, calendar: calendar).map(\.identifier) == ["pour.goal.resume.4"])
    }

    @Test func tappedGoalNoticeOpensItsPath() {
        #expect(
            GoalNotices.path(identifier: "pour.goal.weekly.6", userInfo: ["path": "/goals/weekly"]) == "/goals/weekly")
        #expect(GoalNotices.path(identifier: "pour.todo.12", userInfo: ["path": "/goals/weekly"]) == nil)
    }
}
