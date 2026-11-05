public import Foundation
public import PourCore

#if os(iOS)
    import EventKit
#endif

/// 从哪读日历（docs/模块/产品优化.md R6）：平时是系统的日历；界面测试用假的（App 里的 FakeCalendar）。只读，不改日历
public protocol CalendarSource: Sendable {
    /// 给过读日历的权限没有（系统告诉 App）
    var authorized: Bool { get }
    /// 问系统能不能读日历：第一次弹系统的权限页
    func requestAccess() async -> Bool
    /// [from, to) 里的日程，按开始排
    func events(from: Date, to: Date) async -> [CalendarItem]
}

#if os(iOS)
    /// 系统的日历（含订阅的节假日、生日）
    public actor EventKitSource: CalendarSource {
        private let store = EKEventStore()

        public init() {}

        public nonisolated var authorized: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }

        public func requestAccess() async -> Bool {
            (try? await store.requestFullAccessToEvents()) ?? false
        }

        public func events(from: Date, to: Date) async -> [CalendarItem] {
            guard authorized else { return [] }
            let predicate = store.predicateForEvents(withStart: from, end: to, calendars: nil)
            return store.events(matching: predicate).sorted { $0.startDate < $1.startDate }.map { event in
                CalendarItem(
                    id: event.calendarItemIdentifier, title: event.title ?? "",
                    start: PourDate.localDateTime(event.startDate, in: .current),
                    end: PourDate.localDateTime(event.endDate, in: .current), allDay: event.isAllDay,
                    calendar: event.calendar?.title ?? "")
            }
        }
    }
#endif
