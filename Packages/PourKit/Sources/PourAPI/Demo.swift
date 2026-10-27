public import PourCore

/// 演示数据（docs/模块/演示数据.md）：演示时手机不读自己的日历（别人看演示时不该看到你的日程），
/// 待办卡里的日程从电脑上的 Pour 拿演示里那个人的
extension API {
    /// 演示的一天的日程：字段和手机上的日历一样（服务器的 server/src/data/demo-calendar.ts）
    public struct DemoCalendar: Decodable, Sendable {
        public struct Item: Decodable, Sendable {
            public let id: String
            public let title: String
            public let start: LocalDateTime
            public let end: LocalDateTime
            public let allDay: Bool
            public let calendar: String
        }

        public let day: DayString
        public let items: [Item]
    }
}

extension APIClient {
    /// 演示数据这一天的日程（真实数据没有这个接口，回 404；电脑上的 Pour 2.8.0 起有）
    public func demoCalendar(_ day: DayString) async throws(APIError) -> [CalendarItem] {
        let page: API.DemoCalendar = try await get("/api/demo/calendar?day=\(day)")
        return page.items.map { item in
            CalendarItem(
                id: item.id, title: item.title, start: item.start, end: item.end, allDay: item.allDay,
                calendar: item.calendar)
        }
    }
}
