import Foundation
import Observation
import PourAPI
import PourPlatform

/// 接健康（docs/模块/产品优化.md R5）：这台手机接上没有、什么时候读一次送到电脑上的 Pour。
/// 只读步数、睡眠、锻炼三样；归到哪天、和你说的是不是同一次，都由服务器定（shared/src/health-app.ts）
@MainActor
@Observable
final class HealthLink {
    private let source: any HealthSource
    private let defaults: UserDefaults
    /// 这台手机上点过「接上」。系统不告诉 App 你给没给读：没给的话读出来是空的，画布上什么都不加
    private(set) var connected: Bool
    /// 画布底下那张「接上健康」的小卡点掉了（设置里还能接）
    private(set) var hintClosed: Bool
    private var lastSync: Date?
    private var syncing = false

    static let connectedKey = "health.connected"
    static let hintKey = "health.hintClosed"
    /// 开 App、回到前台时读一次；这么久之内送过就不再送
    static let interval: TimeInterval = 180

    init(source: any HealthSource, defaults: UserDefaults = .standard) {
        self.source = source
        self.defaults = defaults
        connected = defaults.bool(forKey: Self.connectedKey)
        hintClosed = defaults.bool(forKey: Self.hintKey)
    }

    /// 这台设备上有健康 App
    var available: Bool { source.isAvailable }
    /// 画布底下要不要放那张小卡
    var showHint: Bool { available && !connected && !hintClosed }

    /// 点「接上」：问系统能不能读（第一次弹系统那一页），问完了读最近一个月的送过去
    func connect(_ client: APIClient) async -> APIError? {
        guard await source.requestAccess() else { return nil }
        connected = true
        defaults.set(true, forKey: Self.connectedKey)
        return await sync(client, days: 30, force: true)
    }

    /// 读最近几天的送过去（健康 App 里删了的，服务器那边也跟着没了）；连不上电脑时下次再送
    @discardableResult
    func sync(_ client: APIClient, days: Int = 8, force: Bool = false, now: Date = Date()) async -> APIError? {
        guard connected, !syncing else { return nil }
        if !force, let lastSync, now.timeIntervalSince(lastSync) < Self.interval { return nil }
        syncing = true
        defer { syncing = false }
        let start = Calendar.current.startOfDay(for: now)
        let from = Calendar.current.date(byAdding: .day, value: -days, to: start) ?? start
        let snapshot: HealthSnapshot
        do {
            snapshot = try await source.read(from: from, to: now)
        } catch {
            // 读不了（手机锁着时健康的数据是加密的）：下次打开再读
            return nil
        }
        do {
            try await client.putHealth(Self.upload(snapshot))
            lastSync = now
            return nil
        } catch {
            return error
        }
    }

    /// 断开：不再读，电脑上的 Pour 里送过去的全部删掉（系统里的读取权限要在「设置 → 健康」里关）
    func disconnect(_ client: APIClient) async -> APIError? {
        connected = false
        lastSync = nil
        defaults.set(false, forKey: Self.connectedKey)
        do {
            try await client.forgetHealth()
            return nil
        } catch {
            return error
        }
    }

    func closeHint() {
        hintClosed = true
        defaults.set(true, forKey: Self.hintKey)
    }

    /// 读到的 → 送给服务器的样子（时刻写成 ISO，分钟、公里照原样）
    static func upload(_ snapshot: HealthSnapshot) -> API.HealthUpload {
        let stamp = API.HealthUpload.stamp
        return API.HealthUpload(
            from: stamp(snapshot.from), to: stamp(snapshot.to),
            steps: snapshot.steps.map { .init(start: stamp($0.start), count: $0.count) },
            sleep: snapshot.sleep.map { .init(start: stamp($0.start), end: stamp($0.end), stage: $0.stage) },
            workouts: snapshot.workouts.map { workout in
                .init(
                    id: workout.id, activity: workout.activity, start: stamp(workout.start), end: stamp(workout.end),
                    durationMin: workout.minutes, kilometers: workout.kilometers)
            })
    }
}
