import Foundation
import PourAPI
import PourPlatform
import Testing

@testable import Pour

/// 目标的通知（docs/3.0/07-开发任务清单.md 7.6）：服务器的单子 → 手机排哪几条
@Suite("目标的提醒")
struct GoalRemindersTests {
    private func list(_ json: String) throws -> API.GoalReminderList {
        try JSONDecoder().decode(API.GoalReminderList.self, from: Data(json.utf8))
    }

    private let sample = #"""
        {"ifthen":[
          {"id":4,"title":"今年跑 500 公里","plan":"如果下班觉得累，就先换上跑鞋出门走 10 分钟",
           "remind":{"kind":"time","text":"每个工作日 18:30","at":"18:30","days":[0,1,2,3,4]},
           "line":"每个工作日 18:30 提醒你「如果就」","paused":false},
          {"id":3,"title":"平均睡 7.5 小时","plan":null,
           "remind":{"kind":"time","text":"每天 23:00","at":"23:00","off":true},
           "line":"每天 23:00 提醒你「如果就」","paused":false},
          {"id":2,"title":"每天走 8000 步","plan":"如果到家还没走够，就下楼走一圈",
           "remind":{"kind":"place","text":"到家的时候"},"line":"到家的时候提醒你「如果就」","paused":false},
          {"id":12,"title":"读完《人类简史》","plan":"如果睡前刷手机，就换成看 10 页",
           "remind":{"kind":"time","text":"每天 22:00","at":"22:00"},"line":"每天 22:00 提醒你「如果就」","paused":true}],
         "weekly":{"weekday":6,"time":"20:00"},
         "resume":[{"id":12,"title":"读完《人类简史》","back":"2026-11-28","at":"2026-11-27T20:00",
                    "text":"先停到 11月27日；11月28日起照常提醒、照常算进度"}]}
        """#

    @Test func onlyWhatShouldRing() throws {
        let notices = GoalReminders.notices(try list(sample), home: nil)
        // 关了的（睡觉）、暂停的（读书）不排；到家的时候还不知道家在哪也不排
        #expect(notices.map(\.key) == ["ifthen.4", "weekly", "resume.12"])
        #expect(notices[0].title == "如果下班觉得累，就先换上跑鞋出门走 10 分钟")
        #expect(notices[0].when == .weekly(days: [0, 1, 2, 3, 4], hour: 18, minute: 30))
        #expect(notices[1].when == .weekly(days: [6], hour: 20, minute: 0))
        #expect(notices[1].path == "/goals/weekly")
        #expect(notices[2].title == "明天「读完《人类简史》」接着算了")
        #expect(notices[2].when == .once("2026-11-27T20:00"))
    }

    @Test func arriveHomeOnceHomeIsKnown() throws {
        let home = HomePlace.Point(latitude: 31.23, longitude: 121.47)
        let notices = GoalReminders.notices(try list(sample), home: home)
        #expect(notices.map(\.key) == ["ifthen.4", "ifthen.2", "weekly", "resume.12"])
        #expect(notices[1].when == .arrive(latitude: 31.23, longitude: 121.47))
        #expect(notices[1].path == "/goals/2")
    }

    @Test func clockParsing() {
        let clock = GoalReminders.clock("18:30")
        #expect(clock?.hour == 18 && clock?.minute == 30)
        #expect(GoalReminders.clock("25:00") == nil)
        #expect(GoalReminders.clock("8点") == nil)
    }
}
