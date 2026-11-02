public import Foundation
public import PourCore
import UserNotifications

#if canImport(CoreLocation)
    import CoreLocation
#endif

/// 目标的通知（docs/3.0/01-需求文档.md 9.10「提醒」、07 开发任务清单 7.6）：「如果就」（按时间：每个工作日 18:30；
/// 按地点：到家的时候）、每周回顾（默认周日 20:00）、先停一个月回来的前一天。和待办的提醒一样手机自己排，
/// 到点不用连网、不靠服务器；点了通知打开那个目标、每周回顾（userInfo 里的 path）
public enum GoalNotices {
    /// 目标的通知都用这个开头（不动别的通知）
    public static let prefix = "pour.goal."

    /// 一条要排的
    public struct Notice: Hashable, Sendable {
        public enum When: Hashable, Sendable {
            /// 每周这几天（0 周一 … 6 周日；空是每天）的这个钟点，一直重复
            case weekly(days: [Int], hour: Int, minute: Int)
            /// 只一次：本地钟点「2026-11-27T20:00」；过了的不排
            case once(LocalDateTime)
            /// 到了这个地方（家）：每次到都提醒
            case arrive(latitude: Double, longitude: Double)
        }

        /// 「ifthen.4」「weekly」「resume.4」
        public var key: String
        public var title: String
        public var body: String
        public var when: When
        /// 点了打开哪：「/goals/4」「/goals/weekly」
        public var path: String

        public init(key: String, title: String, body: String, when: When, path: String) {
            self.key = key
            self.title = title
            self.body = body
            self.when = when
            self.path = path
        }
    }

    /// 到家算多大一圈（米）
    static let radius = 150.0

    /// 照这几条重排（先撤掉以前排的目标通知）；第一次有要排的才问能不能发通知
    public static func sync(_ notices: [Notice], now: Date = Date(), calendar: Calendar = .current) async {
        let center = UNUserNotificationCenter.current()
        let ours = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
        let all = notices.flatMap { requests($0, now: now, calendar: calendar) }
        guard !all.isEmpty else { return }
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        for request in all { try? await center.add(request) }
    }

    /// 要占几个系统通知（每个工作日是 5 个；系统一个 App 最多 64 个，待办的提醒让出这么多）
    public static func slots(_ notices: [Notice], now: Date = Date(), calendar: Calendar = .current) -> Int {
        notices.reduce(0) { $0 + requests($1, now: now, calendar: calendar).count }
    }

    /// 一条变成几个系统通知
    static func requests(_ notice: Notice, now: Date, calendar: Calendar) -> [UNNotificationRequest] {
        let content = UNMutableNotificationContent()
        content.title = notice.title
        content.body = notice.body
        content.sound = .default
        content.userInfo = ["path": notice.path]
        return triggers(notice, now: now, calendar: calendar).map { suffix, trigger in
            UNNotificationRequest(identifier: prefix + notice.key + suffix, content: content, trigger: trigger)
        }
    }

    /// 什么时候响：每周几天的各排一个（系统的重复只认一个星期几），每天的一个，一次的一个，到家的一个
    static func triggers(_ notice: Notice, now: Date, calendar: Calendar) -> [(String, UNNotificationTrigger)] {
        switch notice.when {
        case .weekly(let days, let hour, let minute):
            if days.isEmpty || Set(days).count == 7 {
                let parts = DateComponents(hour: hour, minute: minute)
                return [("", UNCalendarNotificationTrigger(dateMatching: parts, repeats: true))]
            }
            return Set(days).sorted().map { day in
                let parts = DateComponents(hour: hour, minute: minute, weekday: weekday(day))
                return (".\(day)", UNCalendarNotificationTrigger(dateMatching: parts, repeats: true))
            }
        case .once(let local):
            guard let parts = Reminders.components(local), let date = calendar.date(from: parts), date > now else {
                return []
            }
            return [("", UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))]
        case .arrive(let latitude, let longitude):
            #if os(iOS)
                let region = CLCircularRegion(
                    center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), radius: radius,
                    identifier: prefix + notice.key)
                region.notifyOnEntry = true
                region.notifyOnExit = false
                return [("", UNLocationNotificationTrigger(region: region, repeats: true))]
            #else
                return []
            #endif
        }
    }

    /// 0 周一 … 6 周日 → 系统的星期几（1 周日、2 周一 … 7 周六）
    static func weekday(_ day: Int) -> Int { (day + 1) % 7 + 1 }

    /// 点了通知：目标的通知打开哪（别的通知是 nil）
    public static func path(identifier: String, userInfo: [AnyHashable: Any]) -> String? {
        guard identifier.hasPrefix(prefix) else { return nil }
        return userInfo["path"] as? String
    }
}
