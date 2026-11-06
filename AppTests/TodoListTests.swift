import Foundation
import PourAPI
import PourCore
import Testing

@testable import Pour

/// 待办 2.0 第 4、5 步（docs/todo-2.0）：清单页怎么摆（过点了、今天、放一放）、过点了往哪挪；
/// 编辑弹框只发改了的那几样
@Suite("待办 2.0：清单和编辑")
@MainActor
struct TodoListTests {
    static let today = "2026-10-27"

    private func page(_ today: [API.TodoRow], overdue: [API.TodoRow] = []) -> API.TodoPage {
        API.TodoPage(
            today: Self.today,
            groups: [
                API.TodoGroup(key: "overdue", title: "以前没做完的", rows: overdue),
                API.TodoGroup(key: "today", title: "今天", rows: today),
            ], open: today.count + overdue.count)
    }

    /// 过点了：今天到了钟点没做的（越早过的越前）在前，再是前几天的；只说了时间段的不算过点；放一放的折起来
    @Test func lateTakesPassedClocks() {
        let water = API.TodoRow(id: 1, content: "喝水", day: Self.today, remindAt: "11:12")
        let call = API.TodoRow(id: 2, content: "回复客户电话", day: Self.today, remindAt: "09:30")
        let lunch = API.TodoRow(id: 3, content: "吃午饭", day: Self.today, window: .morning)
        let kid = API.TodoRow(id: 4, content: "接小孩", day: Self.today, remindAt: "17:00")
        var guitar = API.TodoRow(id: 5, content: "学吉他", day: Self.today)
        guitar.quadrant = TodoQuadrant.later.rawValue
        let fee = API.TodoRow(id: 6, content: "交水费", day: "2026-10-25", overdue: true)
        let plan = TodoListPlan.make(
            page: page([water, call, lunch, kid, guitar], overdue: [fee]), held: [:], events: [],
            now: "2026-10-27T11:35")
        #expect(plan.late.map(\.id) == [2, 1, 6])
        #expect(plan.today.map(\.id) == ["todo.3", "todo.4"])
        #expect(plan.later.map(\.id) == [5])
        #expect(plan.counts(page: page([water, call, lunch, kid, guitar], overdue: [fee])).left == 6)
    }

    /// 调整顺序：排过的照你排的（没排过的、新加的在前面），日程插在第一件比它晚的待办前面；挪到别的日子就不算了
    @Test func yourOrderWins() {
        var pickup = API.TodoRow(id: 1, content: "接孩子", day: Self.today, remindAt: "17:00")
        pickup.order = 1
        var report = API.TodoRow(id: 2, content: "交周报", day: Self.today)
        report.order = 0
        let milk = API.TodoRow(id: 3, content: "买牛奶", day: Self.today, remindAt: "10:00")
        let review = CalendarItem(
            id: "e", title: "评审", start: "\(Self.today)T15:00", end: "\(Self.today)T16:00", allDay: false,
            calendar: "工作")
        let items = TodayItem.merge([pickup, report, milk], events: [review])
        #expect(items.map(\.id) == ["todo.3", "todo.2", "event.e", "todo.1"])
        #expect(AppModel.edited(pickup, today: Self.today, day: "2026-10-28").order == nil)
        #expect(AppModel.edited(pickup, today: Self.today, quadrant: .doNow).order == 1)
        var page = API.TodoPage(
            today: Self.today, groups: [API.TodoGroup(key: "today", title: "今天", rows: [pickup, report, milk])],
            open: 3)
        page.reorder([1, 3, 2])
        #expect(page.groups[0].rows.map(\.id) == [1, 3, 2])
    }

    /// 编辑弹框的日子按钮不重复：周五的「周六」就是明天、周日的「下周一」就是明天，只留「明天」
    @Test func dayChoicesNeverRepeat() {
        #expect(TodoEditCards.dayChoices(today: "2026-11-06").map(\.title) == ["今天", "明天", "下周一"])
        #expect(TodoEditCards.dayChoices(today: "2026-11-08").map(\.title) == ["今天", "明天", "周六"])
        #expect(TodoEditCards.dayChoices(today: "2026-11-04").map(\.title) == ["今天", "明天", "周六", "下周一"])
    }

    /// 往后挪：中午以前挪到下午，傍晚以前挪到晚上，晚上只有明天再说
    @Test func laterTodayFollowsTheClock() {
        #expect(TodoListPlan.laterToday(now: "2026-10-27T11:35") == .afternoon)
        #expect(TodoListPlan.laterToday(now: "2026-10-27T15:00") == .evening)
        #expect(TodoListPlan.laterToday(now: "2026-10-27T21:03") == nil)
    }

    /// 编辑弹框：没改就不发；改成时间段把钟点去掉；以后再说只发 someday（日子、钟点由服务器去掉）
    @Test func draftSendsOnlyChanges() {
        var row = API.TodoRow(id: 7, content: "回复客户电话", day: Self.today, remindAt: "15:00")
        row.quadrant = TodoQuadrant.quick.rawValue
        row.quadrantByAI = true
        var draft = TodoDraft(row)
        #expect(!draft.change(from: row).any)
        draft.title = "  回复客户电话  "
        #expect(!draft.change(from: row).any)
        draft.time = nil
        draft.window = .afternoon
        draft.quadrant = .doNow
        let change = draft.change(from: row)
        #expect(change.time == .some(nil) && change.window == .some(.afternoon) && change.quadrant == .doNow)
        #expect(change.day == nil && change.someday == nil && change.content == nil)
        draft.day = nil
        let later = draft.change(from: row)
        #expect(later.someday == true && later.day == nil && later.time == nil)
        let back = TodoDraft(AppModel.edited(row, today: Self.today, someday: true))
        #expect(back.day == nil && back.time == nil && back.window == nil)
    }
}
