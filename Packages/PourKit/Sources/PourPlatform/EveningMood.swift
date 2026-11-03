public import Foundation
import UserNotifications

/// 晚上问一句心情（docs/3.0/01-需求文档.md 6.4，设置里打开，默认关）：手机自己排每天晚上的通知，和「晚上的倾倒提醒」
/// 合成一种——今天没说过话问「今天过得怎么样」，说过话、没说心情问「今天心情怎么样」，都说过了不问。
/// 按住通知直接选一档（很好 … 很差）或者「说两句…」（系统的回复框，打字或说话），不用打开 App
public enum EveningMood {
    /// 晚上问心情的通知都用这个开头（不动别的通知）
    static let prefix = "pour.mood.evening."
    static let categoryId = "pour.mood"
    static let say = "pour.mood.say"
    static let names = ["很差", "不太好", "一般", "挺好", "很好"]

    /// 通知上选了什么：一档、说了一段话、点了通知本身（打开心情页）
    public enum Answer: Sendable, Equatable {
        case level(Int)
        case said(String)
        case open
    }

    /// 一个晚上：哪天（「2026-11-01」）、问什么
    public struct Evening: Hashable, Sendable {
        public var day: String
        public var title: String

        public init(day: String, title: String) {
            self.day = day
            self.title = title
        }
    }

    /// 通知上的按钮：很好在最上面（按住时一列排下来），最后是「说两句…」
    static func category() -> UNNotificationCategory {
        let levels = (1...5).reversed().map { level in
            UNNotificationAction(identifier: "pour.mood.\(level)", title: names[level - 1], options: [])
        }
        let reply = UNTextInputNotificationAction(
            identifier: say, title: "说两句…", options: [], textInputButtonTitle: "记下", textInputPlaceholder: "今天怎么样")
        return UNNotificationCategory(
            identifier: categoryId, actions: levels + [reply], intentIdentifiers: [], options: [])
    }

    static func answer(_ response: UNNotificationResponse) -> Answer {
        if response.actionIdentifier == say {
            let text = (response as? UNTextInputNotificationResponse)?.userText ?? ""
            return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .open : .said(text)
        }
        if response.actionIdentifier.hasPrefix("pour.mood."),
            let level = Int(response.actionIdentifier.dropFirst("pour.mood.".count)), (1...5).contains(level)
        {
            return .level(level)
        }
        return .open
    }

    /// 照这几个晚上重排（time 是「21:30」）；已经过了的不排；第一次排时问能不能发通知
    public static func sync(_ evenings: [Evening], time: String, now: Date = Date(), calendar: Calendar = .current)
        async
    {
        await clear()
        let clock = time.split(separator: ":").compactMap { Int($0) }
        guard clock.count == 2, !evenings.isEmpty else { return }
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        for evening in evenings {
            let day = evening.day.split(separator: "-").compactMap { Int($0) }
            guard day.count == 3 else { continue }
            let parts = DateComponents(year: day[0], month: day[1], day: day[2], hour: clock[0], minute: clock[1])
            guard let date = calendar.date(from: parts), date > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = evening.title
            content.body = "按住这条通知直接选一档，或者说两句"
            content.sound = .default
            content.categoryIdentifier = categoryId
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(
                UNNotificationRequest(identifier: prefix + evening.day, content: content, trigger: trigger))
        }
    }

    /// 撤掉排好的（关了这一项、今天说过心情了）
    public static func clear() async {
        let center = UNUserNotificationCenter.current()
        let ours = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
    }

    /// 排好了几个晚上
    public static func pending() async -> Int {
        await UNUserNotificationCenter.current().pendingNotificationRequests().filter {
            $0.identifier.hasPrefix(prefix)
        }.count
    }
}
