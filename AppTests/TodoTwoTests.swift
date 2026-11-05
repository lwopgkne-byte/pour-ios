import Foundation
import PourAPI
import PourCore
import Testing

@testable import Pour

/// 待办 2.0 第 1 步（docs/todo-2.0）：象限、时间段、以后再说。旧数据（旧服务器、手机上的旧缓存）没有这几样也照样读；
/// 时间三选一（钟点、时间段、都没有），以后再说没有日子、放在「以后」最后；界面先改的规矩和服务器 edited 一样
@Suite("待办 2.0：数据")
@MainActor
struct TodoTwoTests {
    static let today = "2026-10-27"

    private func row(_ id: Int, day: String = today, at time: String? = nil) -> API.TodoRow {
        API.TodoRow(id: id, content: "回复客户电话", day: day, remindAt: time)
    }

    @Test func oldRowsStillDecode() throws {
        let old =
            #"{"id":7,"content":"喝水","day":"2026-10-27","remindAt":"11:12","done":false,"doneAt":null,"#
            + #""repeat":null,"repeatText":null,"overdue":false,"snoozedFrom":null,"people":[],"things":["水"],"#
            + #""places":[],"source":null}"#
        let decoded = try JSONDecoder().decode(API.TodoRow.self, from: Data(old.utf8))
        #expect(decoded.lane == .unsorted && !decoded.guessed && decoded.timeWindow == nil && !decoded.isSomeday)
        let new =
            #"{"id":8,"content":"回复客户电话","day":"2026-10-27","remindAt":null,"done":false,"doneAt":null,"#
            + #""repeat":null,"repeatText":null,"overdue":false,"snoozedFrom":null,"people":[],"things":[],"#
            + #""places":[],"source":null,"quadrant":1,"quadrantByAI":true,"window":"afternoon","someday":false}"#
        let two = try JSONDecoder().decode(API.TodoRow.self, from: Data(new.utf8))
        #expect(two.lane == .doNow && two.guessed && two.timeWindow == .afternoon)
        // 认不出的时间段当没有，整行照样读
        let odd = new.replacingOccurrences(of: "afternoon", with: "noon")
        #expect(try JSONDecoder().decode(API.TodoRow.self, from: Data(odd.utf8)).timeWindow == nil)
    }

    @Test func timeIsOneOfThree() {
        let base = row(1, at: "15:00")
        let windowed = AppModel.edited(base, today: Self.today, window: .some(.afternoon))
        #expect(windowed.remindAt == nil && windowed.timeWindow == .afternoon)
        let clocked = AppModel.edited(windowed, today: Self.today, time: .some("16:00"))
        #expect(clocked.remindAt == "16:00" && clocked.timeWindow == nil)
        let loose = AppModel.edited(clocked, today: Self.today, time: .some(nil), window: .some(nil))
        #expect(loose.remindAt == nil && loose.timeWindow == nil)
    }

    @Test func somedayHasNoDayAndGoesLast() {
        let old = row(2, day: "2026-10-20", at: "20:00")
        let later = AppModel.edited(old, today: Self.today, someday: true)
        #expect(later.isSomeday && later.remindAt == nil && !later.overdue)
        #expect(TodoBoard.key(day: later.day, done: false, today: Self.today, someday: true) == "later")
        let dated = API.TodoRow(id: 3, content: "续保险", day: "2027-03-05")
        #expect(TodoBoard.before(dated, later, in: "later"))
        let back = AppModel.edited(later, today: Self.today, day: "2026-10-28")
        #expect(!back.isSomeday && back.day == "2026-10-28")
    }

    @Test func choosingAQuadrantIsNotAGuess() {
        var guessed = row(4)
        guessed.quadrant = TodoQuadrant.doNow.rawValue
        guessed.quadrantByAI = true
        #expect(guessed.guessed)
        let mine = AppModel.edited(guessed, today: Self.today, quadrant: .schedule)
        #expect(mine.lane == .schedule && !mine.guessed)
    }

    /// 一行右边只放时间或状态：过了沙色、半小时内蓝色写几分钟后、时段写「下午」、以前的写本来的日子、不定时不写
    @Test func trailingStates() {
        let now = "2026-10-27T11:35"
        let past = API.TodoRow(id: 1, content: "喝水", day: Self.today, remindAt: "11:12")
        #expect(TodoBoard.trailing(past, today: Self.today, now: now) == .late("11:12 过了"))
        let soon = API.TodoRow(id: 2, content: "喝三瓶水", day: Self.today, remindAt: "11:43")
        #expect(TodoBoard.trailing(soon, today: Self.today, now: now) == .soon("11:43 · 8 分钟后"))
        let later = API.TodoRow(id: 3, content: "接小孩", day: Self.today, remindAt: "17:00")
        #expect(TodoBoard.trailing(later, today: Self.today, now: now) == .clock("17:00"))
        let window = API.TodoRow(id: 4, content: "回复客户电话", day: Self.today, window: .afternoon)
        #expect(TodoBoard.trailing(window, today: Self.today, now: now) == .window("下午"))
        let loose = API.TodoRow(id: 5, content: "吃午饭", day: Self.today)
        #expect(TodoBoard.trailing(loose, today: Self.today, now: now) == nil)
        let yesterday = API.TodoRow(id: 6, content: "修自行车", day: "2026-10-26", remindAt: "19:00", overdue: true)
        #expect(TodoBoard.trailing(yesterday, today: Self.today, now: now) == .late("昨天 19:00"))
        let friday = API.TodoRow(id: 7, content: "团建", day: "2026-10-30", window: .evening)
        #expect(TodoBoard.trailing(friday, today: Self.today, now: now) == .day("周五 晚上"))
        let someday = API.TodoRow(id: 8, content: "学吉他", day: Self.today, someday: true)
        #expect(TodoBoard.trailing(someday, today: Self.today, now: now) == nil)
    }
}
