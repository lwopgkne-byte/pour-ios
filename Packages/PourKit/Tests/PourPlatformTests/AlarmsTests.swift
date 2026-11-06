import Foundation
import Testing

@testable import PourPlatform

/// 响铃的待办怎么排成闹钟（产品主人 2026-11-06：「7点叫我起床」到点要像闹钟一样响）
@Suite("响铃：排成闹钟")
struct AlarmsTests {
    private let calendar = Calendar(identifier: .gregorian)
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 6, hour: 22)) ?? .distantPast
    }

    private func item(_ id: Int, _ time: String, alarm: Bool = true) -> Reminder {
        Reminder(id: String(id), content: "第 \(id) 件", time: time, alarm: alarm)
    }

    /// 只排响铃的、还没到点的，最近的在前；通知的、过了的不排
    @Test func onlyRingingUpcoming() {
        let items = [
            item(1, "2026-11-07T07:00"), item(2, "2026-11-06T21:00"), item(3, "2026-11-06T23:00", alarm: false),
            item(4, "2026-11-06T22:30"),
        ]
        let plan = Alarms.plan(items, existing: [], now: now, calendar: calendar)
        #expect(plan.schedule.map(\.reminder.id) == ["4", "1"])
        #expect(plan.covered == ["4", "1"])
        #expect(plan.cancel.isEmpty)
    }

    /// 同一件同一时刻的编号每次一样（排着的不动）；改了时间是另一个（旧的撤掉、新的排上）
    @Test func sameTimeSameAlarm() {
        let wake = item(1, "2026-11-07T07:00")
        #expect(Alarms.id(for: wake) == Alarms.id(for: wake))
        #expect(Alarms.id(for: wake) != Alarms.id(for: item(1, "2026-11-07T07:30")))
        #expect(Alarms.id(for: wake) != Alarms.id(for: item(2, "2026-11-07T07:00")))
        let moved = item(1, "2026-11-07T07:30")
        let plan = Alarms.plan(
            [moved], existing: [.init(id: Alarms.id(for: wake), waiting: true)], now: now, calendar: calendar)
        #expect(plan.cancel == [Alarms.id(for: wake)])
        #expect(plan.schedule.map(\.id) == [Alarms.id(for: moved)])
        let again = Alarms.plan(
            [moved], existing: [.init(id: Alarms.id(for: moved), waiting: true)], now: now, calendar: calendar)
        #expect(again.cancel.isEmpty && again.schedule.isEmpty && again.covered == ["1"])
    }

    /// 正在响、稍后提醒倒计时中的不撤（那件已经不在单子上了：到点了、过了）
    @Test func ringingOnesStay() {
        let gone = UUID()
        let plan = Alarms.plan([], existing: [.init(id: gone, waiting: false)], now: now, calendar: calendar)
        #expect(plan.cancel.isEmpty)
    }

    /// 最多排 limit 个，多出来的交回去发通知
    @Test func extraOnesBecomeNotifications() {
        let items = (0..<(Alarms.limit + 3)).map { item($0, String(format: "2026-11-07T%02d:00", $0 % 24)) }
        let plan = Alarms.plan(items, existing: [], now: now, calendar: calendar)
        #expect(plan.schedule.count == Alarms.limit)
        #expect(plan.covered.count == Alarms.limit)
    }
}
