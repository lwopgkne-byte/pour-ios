#if DEBUG
    import Foundation
    import PourCore
    import PourPlatform

    /// 界面测试用的日历（启动参数 -uiTest）：不弹系统的权限页；今天有一个全天的「小李生日」、15:00 看牙医
    final class FakeCalendar: CalendarSource, @unchecked Sendable {
        private let lock = NSLock()
        private var granted = false

        var authorized: Bool { lock.withLock { granted } }

        func requestAccess() async -> Bool {
            lock.withLock { granted = true }
            return true
        }

        func events(from: Date, to: Date) async -> [CalendarItem] {
            let day = PourDate.logicalDay(from, in: .current)
            return [
                CalendarItem(
                    id: "birthday", title: "小李生日", start: "\(day)T00:00", end: "\(PourDate.addDays(day, 1))T00:00",
                    allDay: true, calendar: "生日"),
                CalendarItem(
                    id: "dentist", title: "看牙医", start: "\(day)T15:00", end: "\(day)T16:00", allDay: false,
                    calendar: "家里"),
            ]
        }
    }
#endif
