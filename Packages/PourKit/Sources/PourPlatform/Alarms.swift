public import Foundation

/// 响铃的待办（产品主人 2026-11-06：「提醒一定叫得到」）：说「7点叫我起床」的，手机排成系统闹钟（iOS 26 起的 AlarmKit），
/// 到点像系统闹钟一样响——静音、睡眠和专注模式下也响，锁屏、灵动岛上「停止」「稍后提醒」。普通通知做不到：
/// 免费签名下「时间敏感」当普通通知，专注模式一开就不出来，只「叮」一声也叫不醒人。
/// 「停止」算这件做完了（重复的接着排下一次）；「稍后提醒」过 10 分钟再响。没给闹钟权限、排不上的照旧发通知（Reminders）
public enum Alarms {
    /// 最多排几个（系统有上限，到了会报 maximumLimitReached）：只排最近的，响了一个、打开 App 时往后补
    public static let limit = 20
    /// 「稍后提醒」过多久再响
    public static let snooze: TimeInterval = 10 * 60

    /// 现在排着的一个闹钟：只是排着、还没到点（waiting）的才能撤——正在响、稍后提醒倒计时中的不动
    public struct Existing: Sendable, Hashable {
        public let id: UUID
        public let waiting: Bool

        public init(id: UUID, waiting: Bool) {
            self.id = id
            self.waiting = waiting
        }
    }

    /// 要排上的一个：闹钟的编号、哪件待办、什么时候响
    public struct Item: Sendable, Hashable {
        public let id: UUID
        public let reminder: Reminder
        public let date: Date
    }

    /// 这一次怎么排：撤掉哪些、排上哪些；闹钟管着的待办（这些不再发通知）
    public struct Plan: Sendable, Equatable {
        public var cancel: [UUID]
        public var schedule: [Item]
        public var covered: Set<String>
    }

    /// 照要响铃的待办算怎么排：最近的 limit 个；已经排着、编号一样（同一件、同一时刻）的不动；
    /// 不要了的（做完了、删了、改了时间、关了响铃）撤掉；排不下的（多于 limit）交回去发通知
    public static func plan(
        _ items: [Reminder], existing: [Existing], now: Date = Date(), calendar: Calendar = .current
    ) -> Plan {
        let wanted = items.filter(\.alarm).compactMap { item -> Item? in
            guard let parts = Reminders.components(item.time), let date = calendar.date(from: parts), date > now else {
                return nil
            }
            return Item(id: id(for: item), reminder: item, date: date)
        }
        .sorted { $0.date < $1.date }
        .prefix(limit)
        let keep = Set(wanted.map(\.id))
        let have = Set(existing.map(\.id))
        return Plan(
            cancel: existing.filter { $0.waiting && !keep.contains($0.id) }.map(\.id),
            schedule: wanted.filter { !have.contains($0.id) },
            covered: Set(wanted.map(\.reminder.id)))
    }

    /// 一件待办的一个时刻对应一个闹钟编号（每次算出来都一样）：改了时间就是另一个，旧的撤掉、新的排上
    public static func id(for item: Reminder) -> UUID {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        var bytes: [UInt8] = []
        for round in 0..<2 {
            for byte in Array("pour.alarm.\(round).\(item.id).\(item.time)".utf8) {
                hash = (hash ^ UInt64(byte)) &* 0x0100_0000_01b3
            }
            bytes += (0..<8).map { UInt8(truncatingIfNeeded: hash >> ($0 * 8)) }
        }
        // 第 13 位写 5（按名字算出来的），第 17 位写 8–b
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        let parts = [0..<8, 8..<12, 12..<16, 16..<20, 20..<32].map { range in
            String(hex.dropFirst(range.lowerBound).prefix(range.count))
        }
        return UUID(uuidString: parts.joined(separator: "-")) ?? UUID()
    }

    /// 闹钟能不能用：没问过、开着、关着（待办页底下写「闹钟没打开」）
    public enum Permission: Sendable {
        case notAsked, allowed, denied
    }
}

#if canImport(AlarmKit)
    public import AlarmKit
    public import AppIntents
    import OSLog
    public import SwiftUI

    /// 排闹钟的日志：只记个数、权限、出错的种类，不记待办的字（隐私，同 App 的 Log）
    private let log = Logger(subsystem: "com.lwopgkne.pour", category: "alarms")

    /// 闹钟上带的：哪件待办（锁屏上倒计时那一块用不到，留着以后点开打开这件）
    public struct PourAlarm: AlarmMetadata {
        public var todo: Int

        public init(todo: Int) {
            self.todo = todo
        }
    }

    extension Alarms {
        public static func permission() -> Permission {
            switch AlarmManager.shared.authorizationState {
            case .notDetermined: .notAsked
            case .denied: .denied
            case .authorized: .allowed
            @unknown default: .denied
            }
        }

        /// 排着、还没到点的闹钟有几个（待办页标题下面「N 个提醒已排好」算进去）
        public static func waiting() -> Int {
            ((try? AlarmManager.shared.alarms) ?? []).filter { $0.state == .scheduled }.count
        }

        /// 照现在要响铃的待办重排闹钟，回闹钟管着的待办（这些不再发通知）。
        /// ask：App 在前台、有要响铃的才问一次权限（后台不问，先发通知）；没给权限的什么都不排，全部交回去发通知。
        /// stop：点「停止」时跑的（App 给：算这件做完了）
        public static func sync(
            _ items: [Reminder], ask: Bool, tint: Color, stop: (Int) -> any LiveActivityIntent, now: Date = Date()
        ) async -> Set<String> {
            let manager = AlarmManager.shared
            let wanted = items.filter(\.alarm).count
            if ask, wanted > 0, manager.authorizationState == .notDetermined {
                do {
                    _ = try await manager.requestAuthorization()
                } catch {
                    log.error("问闹钟权限出错：\(String(describing: error), privacy: .public)")
                }
            }
            guard manager.authorizationState == .authorized else {
                if wanted > 0 {
                    log.info(
                        "闹钟没打开（\(String(describing: manager.authorizationState), privacy: .public)），\(wanted) 件发通知")
                }
                return []
            }
            let existing = ((try? manager.alarms) ?? []).map { Existing(id: $0.id, waiting: $0.state == .scheduled) }
            let plan = plan(items, existing: existing, now: now)
            log.info("闹钟：要 \(wanted)，已有 \(existing.count)，撤 \(plan.cancel.count)，排 \(plan.schedule.count)")
            for id in plan.cancel { try? manager.cancel(id: id) }
            var covered = plan.covered
            for (index, item) in plan.schedule.enumerated() {
                do {
                    let todo = Int(item.reminder.id) ?? 0
                    _ = try await manager.schedule(
                        id: item.id, configuration: configuration(item, todo: todo, tint: tint, stop: stop(todo)))
                } catch AlarmManager.AlarmError.maximumLimitReached {
                    // 到了系统的上限：剩下的发通知
                    log.error("闹钟到了系统的上限，剩下 \(plan.schedule.count - index) 件发通知")
                    plan.schedule[index...].forEach { covered.remove($0.reminder.id) }
                    break
                } catch {
                    log.error("排闹钟出错：\(String(describing: error), privacy: .public)")
                    covered.remove(item.reminder.id)
                }
            }
            return covered
        }

        /// 一个闹钟：到点响、标题是这件事；「稍后提醒」过 10 分钟再响（锁屏、灵动岛上倒计时）
        private static func configuration(
            _ item: Item, todo: Int, tint: Color, stop: any LiveActivityIntent
        ) -> AlarmManager.AlarmConfiguration<PourAlarm> {
            let later = AlarmButton(text: "稍后提醒", textColor: .white, systemImageName: "zzz")
            let presentation = AlarmPresentation(
                alert: .init(
                    title: "\(item.reminder.content)", secondaryButton: later, secondaryButtonBehavior: .countdown),
                countdown: .init(title: "\(item.reminder.content)"))
            return AlarmManager.AlarmConfiguration(
                countdownDuration: .init(preAlert: nil, postAlert: snooze), schedule: .fixed(item.date),
                attributes: AlarmAttributes(
                    presentation: presentation, metadata: PourAlarm(todo: todo), tintColor: tint),
                stopIntent: stop)
        }
    }
#endif
