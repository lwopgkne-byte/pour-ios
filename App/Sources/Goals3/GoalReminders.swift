import CoreLocation
import Foundation
import PourAPI
import PourPlatform

/// 服务器给的目标提醒单子 → 手机排的通知（docs/3.0/01-需求文档.md 9.10「提醒」、07 开发任务清单 7.6）：
/// 「如果就」（暂停的、在设置里关了的不排；到家的时候要先知道家在哪）、每周回顾、先停一个月回来的前一天
enum GoalReminders {
    static func notices(_ list: API.GoalReminderList, home: HomePlace.Point?) -> [GoalNotices.Notice] {
        var out: [GoalNotices.Notice] = []
        for item in list.ifthen where !item.paused && item.remind.off != true {
            let title = item.plan ?? "「\(item.title)」：照你定的如果就做"
            let body = "「\(item.title)」· 你定的如果就"
            let path = "/goals/\(item.id)"
            if item.remind.kind == "place" {
                guard let home else { continue }
                out.append(
                    .init(
                        key: "ifthen.\(item.id)", title: title, body: body,
                        when: .arrive(latitude: home.latitude, longitude: home.longitude), path: path))
            } else if let clock = item.remind.at.flatMap(clock) {
                out.append(
                    .init(
                        key: "ifthen.\(item.id)", title: title, body: body,
                        when: .weekly(days: item.remind.days ?? [], hour: clock.hour, minute: clock.minute), path: path)
                )
            }
        }
        if let weekly = list.weekly, let clock = clock(weekly.time) {
            out.append(
                .init(
                    key: "weekly", title: "每周回顾", body: "3 分钟：这周怎么样、要调一调的、下周最重要的一件",
                    when: .weekly(days: [weekly.weekday], hour: clock.hour, minute: clock.minute), path: "/goals/weekly"
                ))
        }
        for item in list.resume {
            out.append(
                .init(
                    key: "resume.\(item.id)", title: "明天「\(item.title)」接着算了", body: item.text, when: .once(item.at),
                    path: "/goals/\(item.id)"))
        }
        return out
    }

    /// 「18:30」→ 18、30
    static func clock(_ text: String) -> (hour: Int, minute: Int)? {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { return nil }
        return (parts[0], parts[1])
    }
}

/// 「到家的时候」提醒要知道家在哪：在家的时候点一下，用现在的位置（只存在这台手机上，不送到电脑上）
enum HomePlace {
    struct Point: Codable, Hashable, Sendable {
        var latitude: Double
        var longitude: Double
    }

    private static let key = "pour.home.place"

    static var saved: Point? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(Point.self, from: $0) }
    }

    static func save(_ point: Point?) {
        if let point, let data = try? JSONEncoder().encode(point) {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// 现在在哪：没问过先问（用的时候才定位一次）；不让定位、20 秒还没定到是 nil
    @MainActor
    static func locate() async -> Point? {
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }
        let deadline = Date().addingTimeInterval(20)
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if update.authorizationDenied || update.authorizationDeniedGlobally || Date() > deadline { return nil }
                if let location = update.location, location.horizontalAccuracy >= 0,
                    location.horizontalAccuracy < 200
                {
                    return Point(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
                }
            }
        } catch {
            return nil
        }
        return nil
    }
}
