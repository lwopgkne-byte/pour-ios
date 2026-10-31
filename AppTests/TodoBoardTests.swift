import Foundation
import PourAPI
import PourCore
import PourDesign
import Testing

@testable import Pour

/// 3.0 待办页的单子怎么摆（docs/3.0/01-需求文档.md 4.2、06 交互细节 2.1–2.2）：界面先改时挪到对的组，
/// 勾掉的划线留在原地、离开再回来才收进「已完成」，胶囊写什么，推迟到哪（和服务器的 snoozeTarget 对拍）
@Suite("3.0 待办：分组、留在原地、胶囊、推迟")
@MainActor
struct TodoBoardTests {
    /// 2026-10-27 周二（服务器 todos.test.ts 的那一天）
    static let today = "2026-10-27"

    private func row(_ id: Int, _ content: String, day: String, at time: String? = nil, done: Bool = false)
        -> API.TodoRow
    {
        API.TodoRow(
            id: id, content: content, day: day, remindAt: time, done: done,
            doneAt: done ? "2026-10-27T01:00:00.000Z" : nil, overdue: !done && day < Self.today)
    }

    private func page() -> API.TodoPage {
        API.TodoPage(
            today: Self.today,
            groups: [
                API.TodoGroup(key: "overdue", title: "以前没做完的", rows: [row(1, "交水费", day: "2026-10-26")]),
                API.TodoGroup(
                    key: "today", title: "今天 · 10月27日 周二",
                    rows: [row(2, "取快递", day: Self.today, at: "18:00"), row(3, "回邮件", day: Self.today)]),
                API.TodoGroup(key: "tomorrow", title: "明天", rows: [row(4, "交周报", day: "2026-10-28")]),
            ],
            open: 3)
    }

    @Test(arguments: [
        ("2026-10-20", "overdue"), ("2026-10-27", "today"), ("2026-10-28", "tomorrow"), ("2026-10-29", "week"),
        ("2026-11-01", "week"), ("2026-11-02", "later"),
    ])
    func groupOfADay(day: String, key: String) {
        #expect(TodoBoard.key(day: day, done: false, today: Self.today) == key)
        #expect(TodoBoard.key(day: day, done: true, today: Self.today) == "done")
    }

    /// 周六周日：明天以后都是「以后」（这周只剩明天）
    @Test func weekendHasNoThisWeek() {
        #expect(TodoBoard.key(day: "2026-11-02", done: false, today: "2026-10-31") == "later")
        #expect(TodoBoard.key(day: "2026-11-01", done: false, today: "2026-10-31") == "tomorrow")
    }

    @Test func doneStaysInPlaceUntilLeaving() throws {
        var page = page()
        page.setDone(3, true, at: "2026-10-27T08:00:00.000Z")
        // 服务器回来的单子里它在「已完成」：这一次看着勾掉的（held）留在「今天」原来的位置
        var fresh = page
        let taken = fresh.take(3)
        let done = try #require(taken)
        fresh.groups.append(API.TodoGroup(key: "done", title: "已完成", rows: [done]))
        let shown = TodoBoard.sections(fresh, held: [3: "today"])
        #expect(shown.first { $0.key == "today" }?.rows.map(\.content) == ["取快递", "回邮件"])
        #expect(shown.contains { $0.key == "done" } == false)
        #expect(page.open == 2)
        // 离开待办页：收进「已完成」
        page.settle()
        #expect(page.groups.first { $0.key == "today" }?.rows.map(\.content) == ["取快递"])
        #expect(page.groups.last?.key == "done")
        #expect(page.groups.last?.rows.map(\.content) == ["回邮件"])
    }

    @Test func movingFindsTheRightGroup() {
        var page = page()
        // 推迟到下周一：「以后」这一组原来没有，按顺序加在「明天」后面
        page.move(2, day: "2026-11-02", time: "09:00")
        #expect(page.groups.map(\.key) == ["overdue", "today", "tomorrow", "later"])
        #expect(page.row(2)?.remindAt == "09:00")
        // 以前没做完的带到今天：「以前没做完的」空了就不要了；有钟点的排在没钟点的前面
        page.move(1, day: Self.today, time: "08:00")
        #expect(page.groups.map(\.key) == ["today", "tomorrow", "later"])
        #expect(page.groups[0].rows.map(\.content) == ["交水费", "回邮件"])
        #expect(page.row(1)?.overdue == false)
        // 「今天」空了也留着
        page.take(1)
        page.take(3)
        #expect(page.groups.map(\.key) == ["today", "tomorrow", "later"])
    }

    @Test func capsules() {
        let now = "2026-10-27T16:10"
        let capsule = { (row: API.TodoRow) -> String? in
            TodoBoard.capsule(row, today: Self.today, now: now).map { "\($0.text) · \($0.tone)" }
        }
        #expect(capsule(row(1, "取快递", day: Self.today, at: "18:00")) == "18:00 · remind")
        #expect(capsule(row(1, "回电话", day: Self.today, at: "10:00")) == "10:00 过了 · late")
        #expect(capsule(row(1, "回邮件", day: Self.today)) == nil)
        #expect(capsule(row(1, "交水费", day: "2026-10-26", at: "17:30")) == "昨天 17:30 · late")
        #expect(capsule(row(1, "修车", day: "2026-10-25")) == "10月25日 · late")
        #expect(capsule(row(1, "交周报", day: "2026-10-28", at: "09:00")) == "09:00 · remind")
        #expect(capsule(row(1, "团建", day: "2026-10-30")) == "周五 · plain")
        #expect(capsule(row(1, "续保险", day: "2027-03-05", at: "10:00")) == "3月5日 10:00 · remind")
        #expect(capsule(row(1, "买牛奶", day: Self.today, at: "09:00", done: true)) == nil)
        // 过了日界线（凌晨一点还算昨天）：昨天 23:00 的照样算过了
        let late = TodoBoard.capsule(
            row(1, "关灯", day: Self.today, at: "23:00"), today: Self.today, now: "2026-10-28T01:00")
        #expect(late?.text == "23:00 过了")
    }

    /// 和服务器 todos.test.ts 的推迟一样：2026-10-27 周二 16:10
    @Test func snoozeTargetsMatchTheServer() throws {
        let now = try #require(
            Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 16, minute: 10)))
        let target = { (preset: SnoozePreset) in preset.target(now: now, today: Self.today) }
        #expect(target(.hour) == ("2026-10-27", "17:10"))
        #expect(target(.tonight) == ("2026-10-27", "20:00"))
        #expect(target(.tomorrow) == ("2026-10-28", "09:00"))
        #expect(target(.saturday) == ("2026-10-31", "10:00"))
        #expect(target(.monday) == ("2026-11-02", "09:00"))
        // 周六说「这个周六」是下周六；23:30 的「1 小时后」到了明天
        #expect(SnoozePreset.saturday.target(now: now, today: "2026-10-31") == ("2026-11-07", "10:00"))
        let late = try #require(
            Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 23, minute: 31)))
        #expect(SnoozePreset.hour.target(now: late, today: Self.today) == ("2026-10-28", "00:35"))
    }

    @Test func repeatWordsMatchTheServer() {
        #expect(API.Repeat.daily.text == "每天")
        #expect(API.Repeat.weekdays.text == "工作日")
        #expect(API.Repeat.weekly([0, 2, 4]).text == "每周一、三、五")
        #expect(API.Repeat.monthly(15).text == "每月 15 号")
    }

    @Test func whenWords() {
        #expect(TodoBoard.when(day: Self.today, time: "15:00", today: Self.today) == "今天 15:00")
        #expect(TodoBoard.when(day: "2026-10-28", time: nil, today: Self.today) == "明天")
        #expect(TodoBoard.when(day: "2026-11-02", time: "09:00", today: Self.today) == "11月2日 周一 09:00")
    }

    /// 今天这一组：日程穿插在待办里，按钟点排，全天的最前，没时间的待办在后面
    @Test func todayMergesCalendar() {
        let events = [
            CalendarItem(
                id: "a", title: "评审会", start: "2026-10-27T14:00", end: "2026-10-27T15:30", allDay: false, calendar: "工作"
            ),
            CalendarItem(
                id: "b", title: "纪念日", start: "2026-10-27T00:00", end: "2026-10-28T00:00", allDay: true,
                calendar: "生日"),
        ]
        let items = TodayItem.merge(
            [row(2, "取快递", day: Self.today, at: "18:00"), row(3, "回邮件", day: Self.today)], events: events)
        #expect(items.map(\.id) == ["event.b", "event.a", "todo.2", "todo.3"])
        #expect(TodayItem.time(events[0]) == "14:00–15:30")
        #expect(TodayItem.time(events[1]) == "全天 · 日历")
        // 日历里那件和说过的待办是同一件（钟点差 15 分钟以内、名字像）：只显示待办
        let twin = CalendarItem(
            id: "c", title: "取快递", start: "2026-10-27T18:05", end: "2026-10-27T18:20", allDay: false, calendar: "生活")
        let merged = TodayItem.merge([row(2, "取快递", day: Self.today, at: "18:00")], events: [twin])
        #expect(merged.map(\.id) == ["todo.2"])
    }

    /// 假服务器认时间（界面测试用的那几句）：和真服务器回的位置、标题一样
    @Test func stubParsesTheTestSentences() {
        let when = StubServer.State.parseWhen("明天下午三点取快递", today: Self.today)
        #expect(when["day"] as? String == "2026-10-28")
        #expect(when["time"] as? String == "15:00")
        #expect(when["spans"] as? [[Int]] == [[0, 2], [2, 6]])
        #expect(when["title"] as? String == "取快递")
        let weekly = StubServer.State.parseWhen("每周五晚上八点给爸妈打视频", today: Self.today)
        #expect(weekly["time"] as? String == "20:00")
        #expect(weekly["day"] as? String == "2026-10-30")
        #expect(weekly["title"] as? String == "给爸妈打视频")
    }
}
