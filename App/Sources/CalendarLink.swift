import Foundation
import Observation
import PourAPI
import PourCore
import PourPlatform

/// 接日历（docs/模块/产品优化.md R6）：这台手机接上没有、正在看的那天有哪些日程。
/// 只读，不改日历；日程只在这台手机上，不送到电脑上的 Pour。
/// 演示数据时（docs/模块/演示数据.md）不读这台手机的日历：日程是演示里那个人的，电脑上的 Pour 给
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
    /// 电脑上的 Pour 在用演示数据：日程是演示的，接上日历的小卡不出现
    private(set) var demo = false

    static let connectedKey = "calendar.connected"
    static let hintKey = "calendar.hintClosed"

    init(source: any CalendarSource, defaults: UserDefaults = .standard) {
        self.source = source
        self.defaults = defaults
        connected = defaults.bool(forKey: Self.connectedKey) && source.authorized
        hintClosed = defaults.bool(forKey: Self.hintKey)
    }

    var showHint: Bool { !demo && !connected && !hintClosed }

    /// 换了真实数据、演示数据：看过的日程都不要了（演示的不留到真实数据里，你的日程也不留到演示里）
    func useDemo(_ isOn: Bool) {
        guard isOn != demo else { return }
        demo = isOn
        items = [:]
    }

    /// 点「接上」：问系统能不能读日历（第一次弹系统那一页）；给了就记下
    func connect() async -> Bool {
        let granted = await source.requestAccess()
        connected = granted
        defaults.set(granted, forKey: Self.connectedKey)
        return granted
    }

    /// 断开：不再读（系统给的权限在 iPhone 的「设置 → 日历」里关）；演示的日程不是这台手机的，留着
    func disconnect() {
        connected = false
        if !demo { items = [:] }
        defaults.set(false, forKey: Self.connectedKey)
    }

    func closeHint() {
        hintClosed = true
        defaults.set(true, forKey: Self.hintKey)
    }

    /// 读这一天的日程：按日界线算的那一天（凌晨 4 点前的算前一天）。演示数据时不读
    func load(_ day: DayString, boundary: Int) async {
        guard !demo, connected, let from = Self.start(of: day, boundary: boundary),
            let until = Self.start(of: PourDate.addDays(day, 1), boundary: boundary)
        else { return }
        let events = await source.events(from: from, to: until)
        // 读的时候切到了演示数据：你的日程不放进去
        guard !demo else { return }
        items[day] = events
    }

    /// 演示数据这一天的日程（电脑上的 Pour 太旧、没有这个接口就是空的）
    func loadDemo(_ day: DayString, from client: APIClient) async {
        guard demo else { return }
        let events = (try? await client.demoCalendar(day)) ?? []
        guard demo else { return }
        items[day] = events
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
