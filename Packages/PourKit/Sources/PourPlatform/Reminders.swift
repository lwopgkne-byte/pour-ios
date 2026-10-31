public import Foundation
public import PourCore
import Synchronization
import UserNotifications

/// 待办的提醒（3.0 红线，docs/3.0/01-需求文档.md 4.4、06 交互细节 2.6）：手机自己排系统通知，到点不用连网、不靠服务器。
/// 服务器给一张全部的单子（没做完、带提醒、还没到点的，最近的 60 条；系统一个 App 最多 64 个），
/// 每次打开、记录变了、后台刷新都照它重排：新的排上、改了时间的跟着改、做完和删掉的撤掉。
/// 通知上四个按钮「完成 · 10 分钟后 · 1 小时后 · 明天早上」，点了不用打开 App（交给 listen 的那个处理）
public enum Reminders {
    /// Pour 排的通知都用这个开头（不动别的通知）
    static let prefix = "pour.todo."
    /// 通知的分类：带那四个按钮
    static let category = "pour.todo"
    /// 最多排几条（系统最多 64 个，留几个给别的）
    public static let limit = 60

    /// 通知上点了什么：四个按钮，或者点了通知本身（打开待办）
    public enum Action: String, CaseIterable, Sendable {
        case done = "pour.todo.done"
        case tenMinutes = "pour.todo.10min"
        case hour = "pour.todo.hour"
        case tomorrow = "pour.todo.tomorrow"
        case open = "com.apple.UNNotificationDefaultActionIdentifier"

        /// 按钮上的字（点了通知本身没有按钮）
        var title: String? {
            switch self {
            case .done: "完成"
            case .tenMinutes: "10 分钟后"
            case .hour: "1 小时后"
            case .tomorrow: "明天早上"
            case .open: nil
            }
        }
    }

    /// 照现在要提醒的待办重排；已经过了的不排。第一次有要提醒的才问能不能发通知
    public static func sync(_ items: [Reminder], now: Date = Date(), calendar: Calendar = .current) async {
        let center = UNUserNotificationCenter.current()
        let upcoming = items.compactMap { item -> (Reminder, DateComponents)? in
            guard let parts = components(item.time), let date = calendar.date(from: parts), date > now else {
                return nil
            }
            return (item, parts)
        }
        .prefix(limit)
        let ours = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
        guard !upcoming.isEmpty else { return }
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        for (item, parts) in upcoming {
            let content = UNMutableNotificationContent()
            content.title = item.content
            content.body = item.said.map { "你 \($0)说的" } ?? "你说过这时候提醒你"
            content.sound = .default
            content.categoryIdentifier = category
            // 时间敏感：专注模式下也出来（要苹果开发者计划的权限；免费签名时系统当普通通知，见 docs/3.0/进度.md）
            content.interruptionLevel = .timeSensitive
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(
                UNNotificationRequest(identifier: prefix + item.id, content: content, trigger: trigger))
        }
    }

    /// 通知开着没有：没问过、开着、关着（待办页底下写「通知关着」）
    public enum Permission: Sendable {
        case notAsked, allowed, denied
    }

    public static func permission() async -> Permission {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .notDetermined: .notAsked
        case .denied: .denied
        default: .allowed
        }
    }

    /// 已经排上的 Pour 的提醒：编号 → 什么时候到点（待办页底下、界面测试看排上了几条）
    public static func pending() async -> [String: Date] {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        var found: [String: Date] = [:]
        for request in requests where request.identifier.hasPrefix(prefix) {
            let trigger = request.trigger as? UNCalendarNotificationTrigger
            found[String(request.identifier.dropFirst(prefix.count))] = trigger?.nextTriggerDate()
        }
        return found
    }

    /// 「2026-10-19T10:35」→ 当地的年月日时分（墙上的钟点，不经过时区换算）
    static func components(_ local: String) -> DateComponents? {
        let numbers = local.split(whereSeparator: { "-T:".contains($0) }).compactMap { Int($0) }
        guard numbers.count == 5 else { return nil }
        return DateComponents(
            year: numbers[0], month: numbers[1], day: numbers[2], hour: numbers[3], minute: numbers[4])
    }

    /// 启动时：App 开着的时候到点也弹出来（系统默认不弹）；注册通知上的四个按钮；
    /// 点了按钮、点了通知交给 handler（App 没开着时系统在后台叫醒 App 来做，要在启动完以前设好）
    @MainActor
    public static func listen(_ handler: @escaping @Sendable (Action, Int) async -> Void) {
        let buttons = Action.allCases.compactMap { action in
            action.title.map { UNNotificationAction(identifier: action.rawValue, title: $0, options: []) }
        }
        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([
            UNNotificationCategory(identifier: category, actions: buttons, intentIdentifiers: [], options: [])
        ])
        NotificationDelegate.shared.handler.withLock { $0 = handler }
        center.delegate = NotificationDelegate.shared
    }
}

/// 系统交来的通知。用带完成回调的那一版、在主线程上回：async 的那一版在后台线程上回，系统接着更新界面时
/// UIKit 断言崩溃——点通知上的按钮就崩（2026-11-01 界面测试 testNotificationDone 查出来的）
private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = NotificationDelegate()
    let handler = Mutex<(@Sendable (Reminders.Action, Int) async -> Void)?>(nil)

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        guard identifier.hasPrefix(Reminders.prefix), let id = Int(identifier.dropFirst(Reminders.prefix.count)),
            let action = Reminders.Action(rawValue: response.actionIdentifier),
            let handler = handler.withLock({ $0 })
        else {
            completionHandler()
            return
        }
        nonisolated(unsafe) let done = completionHandler
        Task { @MainActor in
            await handler(action, id)
            done()
        }
    }
}

/// 一条要提醒的待办：哪条、提醒什么、几点（本地钟点）、哪天说的（「10月26日」）
public struct Reminder: Hashable, Sendable {
    public var id: String
    public var content: String
    public var time: LocalDateTime
    public var said: String?

    public init(id: String, content: String, time: LocalDateTime, said: String? = nil) {
        self.id = id
        self.content = content
        self.time = time
        self.said = said
    }
}
