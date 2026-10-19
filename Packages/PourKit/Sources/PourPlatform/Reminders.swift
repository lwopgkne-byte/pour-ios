public import Foundation
public import PourData
import UserNotifications

/// 待办的提醒：手机自己排系统通知，到点不用连网、不靠服务器（docs/03 第 5.5 节「本地排好」）。
/// 每次记录变了就照数据库重排一遍：新的排上、改了时间的跟着改、做完和删掉的撤掉
public enum Reminders {
    /// Pour 排的通知都用这个开头（不动别的通知）
    static let prefix = "pour.todo."

    /// 照现在要提醒的待办重排；已经过了的不排。第一次有要提醒的才问能不能发通知
    public static func sync(_ items: [Reminder], now: Date = Date(), calendar: Calendar = .current) async {
        let center = UNUserNotificationCenter.current()
        let upcoming = items.compactMap { item -> (Reminder, DateComponents)? in
            guard let parts = components(item.time), let date = calendar.date(from: parts), date > now else {
                return nil
            }
            return (item, parts)
        }
        let ours = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
        guard !upcoming.isEmpty else { return }
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        for (item, parts) in upcoming {
            let content = UNMutableNotificationContent()
            content.title = item.content
            content.body = "你说过这时候提醒你"
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(
                UNNotificationRequest(identifier: prefix + item.id, content: content, trigger: trigger))
        }
    }

    /// 「2026-10-19T10:35」→ 当地的年月日时分（墙上的钟点，不经过时区换算）
    static func components(_ local: String) -> DateComponents? {
        let numbers = local.split(whereSeparator: { "-T:".contains($0) }).compactMap { Int($0) }
        guard numbers.count == 5 else { return nil }
        return DateComponents(
            year: numbers[0], month: numbers[1], day: numbers[2], hour: numbers[3], minute: numbers[4])
    }

    /// App 开着的时候到点也弹出来（系统默认不弹）
    public static func showWhileOpen() {
        UNUserNotificationCenter.current().delegate = ForegroundBanner.shared
    }
}

private final class ForegroundBanner: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = ForegroundBanner()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
