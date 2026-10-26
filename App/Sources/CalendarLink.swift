import Foundation
import Observation
import PourCore
import PourPlatform

/// 接日历（docs/模块/产品优化.md R6）：这台手机接上没有、正在看的那天有哪些日程。
/// 只读，不改日历；日程只在这台手机上，不送到电脑上的 Pour
@MainActor
@Observable
final class CalendarLink {
    private let source: any CalendarSource
    private let defaults: UserDefaults
    /// 这台手机上点过「接上」，而且系统给了读日历的权限
    private(set) var connected: Bool
    /// 画布底下那张「接上日历」的小卡点掉了（设置里还能接）
    private(set) var hintClosed: Bool
    /// 看过的日子里的日程（按日子存）
    private(set) var items: [DayString: [CalendarItem]] = [:]

    static let connectedKey = "calendar.connected"
    static let hintKey = "calendar.hintClosed"

    init(source: any CalendarSource, defaults: UserDefaults = .standard) {
        self.source = source
        self.defaults = defaults
        connected = defaults.bool(forKey: Self.connectedKey) && source.authorized
        hintClosed = defaults.bool(forKey: Self.hintKey)
    }

    var showHint: Bool { !connected && !hintClosed }

    /// 点「接上」：问系统能不能读日历（第一次弹系统那一页）；给了就记下
    func connect() async -> Bool {
        let granted = await source.requestAccess()
        connected = granted
        defaults.set(granted, forKey: Self.connectedKey)
        return granted
    }

    /// 断开：不再读（系统给的权限在 iPhone 的「设置 → 日历」里关）
    func disconnect() {
        connected = false
        items = [:]
        defaults.set(false, forKey: Self.connectedKey)
    }

    func closeHint() {
        hintClosed = true
        defaults.set(true, forKey: Self.hintKey)
    }

    /// 读这一天的日程：按日界线算的那一天（凌晨 4 点前的算前一天）
    func load(_ day: DayString, boundary: Int) async {
        guard connected, let from = Self.start(of: day, boundary: boundary),
            let until = Self.start(of: PourDate.addDays(day, 1), boundary: boundary)
        else { return }
        items[day] = await source.events(from: from, to: until)
    }

    /// 这一天从几点开始（日界线）
    static func start(of day: DayString, boundary: Int) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let components = DateComponents(
            year: parts[0], month: parts[1], day: parts[2], hour: boundary / 60, minute: boundary % 60)
        return Calendar.current.date(from: components)
    }
}
