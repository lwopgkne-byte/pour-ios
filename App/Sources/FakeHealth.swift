#if DEBUG
    import Foundation
    import PourCore
    import PourPlatform

    /// 界面测试用的健康 App（启动参数 -uiTest）：不弹系统的权限页；今天走了 8,234 步、早上 7:02 跑了 33 分钟 5.1 公里，
    /// 前一晚 23:41 睡到 7:05
    struct FakeHealth: HealthSource {
        var isAvailable: Bool { true }

        func requestAccess() async -> Bool { true }

        func read(from: Date, to: Date) async throws -> HealthSnapshot {
            let today = PourDate.logicalDay(Date(), in: .current)
            let yesterday = PourDate.addDays(today, -1)
            let at = { (day: String, clock: String) in Self.date("\(day)T\(clock)") }
            return HealthSnapshot(
                from: from, to: to,
                steps: [
                    .init(start: at(today, "08:00"), count: 3000), .init(start: at(today, "12:00"), count: 2000),
                    .init(start: at(today, "18:00"), count: 3234),
                ],
                sleep: [.init(start: at(yesterday, "23:41"), end: at(today, "07:05"), stage: "asleep")],
                workouts: [
                    .init(
                        id: "fake-run", activity: "running", start: at(today, "07:02"), end: at(today, "07:35"),
                        minutes: 33, kilometers: 5.1)
                ])
        }

        /// 「2026-10-26T07:02」→ 这台手机时区里的那一刻
        static func date(_ local: String) -> Date {
            let parts = local.split(whereSeparator: { "-T:".contains($0) }).compactMap { Int($0) }
            let components = DateComponents(
                year: parts[0], month: parts[1], day: parts[2], hour: parts[3], minute: parts[4])
            return Calendar.current.date(from: components) ?? Date()
        }
    }

    extension HealthLink {
        /// 单元测试用：读假的，「接上没有」记在单独的一份设置里（不碰这台手机上真的）
        static func forTests(_ name: String = "pour.tests.health") -> HealthLink {
            let defaults = UserDefaults(suiteName: name) ?? .standard
            defaults.removePersistentDomain(forName: name)
            return HealthLink(source: FakeHealth(), defaults: defaults)
        }
    }
#endif
