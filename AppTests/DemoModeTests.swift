import Foundation
import PourAPI
import PourCore
import Testing

@testable import Pour

/// 演示数据（docs/模块/演示数据.md）：演示时不读这台手机的日历，待办里放电脑上的 Pour 给的演示日程；
/// 换了真实 / 演示数据，看过的日程不留着；接上日历的小卡不出现
@Suite("演示数据")
@MainActor
struct DemoModeTests {
    @Test func demoCalendarReplacesThePhonesCalendar() async {
        let link = CalendarLink.forTests("pour.tests.calendar.demo")
        _ = await link.connect()
        let today = PourDate.logicalDay(Date(), in: .current)
        await link.load(today, boundary: 240)
        #expect(link.items[today]?.map(\.title) == ["小李生日", "看牙医"], "平时读这台手机的日历")

        link.useDemo(true)
        #expect(link.items.isEmpty, "切到演示数据：你的日程不留着")
        await link.load(today, boundary: 240)
        #expect(link.items[today] == nil, "演示数据时不读这台手机的日历")
        await link.loadDemo(today, from: StubServer.client())
        #expect(link.items[today]?.map(\.title) == ["结婚纪念日", "给客户回电话"])
        #expect(link.items[today]?.first?.allDay == true)
        link.disconnect()
        #expect(link.items[today]?.count == 2, "断开日历：演示的日程不是这台手机的，留着")

        link.useDemo(false)
        #expect(link.items.isEmpty, "回到真实数据：演示的日程不留着")
    }

    @Test func noConnectHintWhileDemo() {
        let link = CalendarLink.forTests("pour.tests.calendar.demo.hint")
        #expect(link.showHint)
        link.useDemo(true)
        #expect(!link.showHint, "演示数据时待办里已经是演示的日程，不问你接不接日历")
        link.useDemo(false)
        #expect(link.showHint)
    }

    /// 演示里的「给客户回电话」：日历里那一件和他说的待办是同一件，待办卡里只显示待办
    @Test func demoCallShowsOnce() async throws {
        let today = PourDate.logicalDay(Date(), in: .current)
        let events = try await StubServer.client().demoCalendar(today)
        let json = #"{"content":"给客户回电话","done":false,"remindAt":"\#(today)T10:00"}"#
        let todo = try JSONDecoder().decode(API.TodoData.self, from: Data(json.utf8))
        #expect(events.contains { AgendaPlan.same($0, todo) })
        #expect(!events.contains { $0.allDay && AgendaPlan.same($0, todo) })
    }
}
