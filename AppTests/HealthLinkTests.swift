import Foundation
import PourAPI
import PourCore
import PourPlatform
import Synchronization
import Testing

@testable import Pour

/// 接健康（docs/模块/产品优化.md R5）：点了「接上」才读、读了送到电脑上的 Pour；画布上那一天有健康来的和步数；断开就删
@Suite("接健康")
@MainActor
struct HealthLinkTests {
    @Test func uploadKeepsWhatWasRead() {
        let start = Date(timeIntervalSince1970: 1_793_000_000)
        let snapshot = HealthSnapshot(
            from: start, to: start.addingTimeInterval(3600),
            steps: [.init(start: start, count: 1200)],
            sleep: [.init(start: start, end: start.addingTimeInterval(1800), stage: "asleep")],
            workouts: [
                .init(
                    id: "w", activity: "running", start: start, end: start.addingTimeInterval(1980), minutes: 33,
                    kilometers: 5.1)
            ])
        let upload = HealthLink.upload(snapshot)
        #expect(upload.from == "2026-10-26T07:33:20Z")
        #expect(upload.steps.map(\.count) == [1200])
        #expect(upload.sleep.first?.stage == "asleep")
        #expect(upload.workouts.first?.activity == "running")
        #expect(upload.workouts.first?.kilometers == 5.1)
    }

    @Test func connectSendsAndTheCanvasShowsIt() async throws {
        let client = StubServer.client()
        let health = HealthLink.forTests("pour.tests.health.connect")
        #expect(health.showHint)
        #expect(await health.sync(client) == nil)
        #expect(!health.connected, "没点「接上」不读")
        #expect(await health.connect(client) == nil)
        #expect(health.connected && !health.showHint)
        let today = PourDate.logicalDay(Date(), in: .current)
        let day = try await client.day(today)
        #expect(day.health?.steps == 8234)
        #expect(day.entries.contains { $0.fromHealthApp && $0.category == "run" && $0.id < 0 })
        #expect(await health.disconnect(client) == nil)
        #expect(!health.connected)
        #expect(try await client.day(today).health == nil)
    }

    /// 系统只给读接上那一刻往前 30 天的：从「现在」往前算，不从那天零点算（不然服务器以为最早那天读全了）
    @Test func readsBackFromNowNotFromMidnight() async {
        let source = RecordingHealth()
        let name = "pour.tests.health.window"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let health = HealthLink(source: source, defaults: defaults)
        let client = StubServer.client()
        _ = await health.connect(client)
        let now = Date(timeIntervalSince1970: 1_793_000_000)
        _ = await health.sync(client, days: 8, force: true, now: now)
        #expect(source.from.withLock { $0 } == Calendar.current.date(byAdding: .day, value: -8, to: now))
    }
}

/// 记下 App 从哪一刻开始读
private final class RecordingHealth: HealthSource {
    let from = Mutex<Date?>(nil)
    var isAvailable: Bool { true }

    func requestAccess() async -> Bool { true }

    func read(from: Date, to: Date) async throws -> HealthSnapshot {
        self.from.withLock { $0 = from }
        return HealthSnapshot(from: from, to: to, steps: [], sleep: [], workouts: [])
    }
}
