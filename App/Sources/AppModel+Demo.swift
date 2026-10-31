import Foundation

// MARK: - 演示数据（docs/模块/演示数据.md）

extension AppModel {
    /// 电脑上的 Pour 在用演示数据：画布上是演示里那个人的生活
    var demo: Bool { mode == "demo" }

    /// 换了真实数据、演示数据：日程换成演示的（或者回到这台手机的日历），小组件、锁屏马上重新拿
    func modeChanged() {
        // 没网时别让另一边（真实 / 演示）的页面冒出来
        client.cache.clear()
        calendar.useDemo(demo)
        loadCalendar()
        refreshWidgets()
    }

    /// 接上健康的小卡：演示数据时不出现（演示里是那个人手表的数据，你手机上的不送过去）
    var showHealthHint: Bool { !demo && health.showHint }

    /// 切换真实数据、演示数据（设置 → 数据、「我的」页头的「演示数据」小标签）：服务器会重新启动，
    /// 等它回来再整个重新拿。成了返回 true；没成已经说过一句了
    @discardableResult
    func switchData(to mode: String, regenerate: Bool = false) async -> Bool {
        toast(mode == "demo" ? "正在切换到演示数据…" : "正在回到真实数据…")
        do {
            try await client.switchData(to: mode, regenerate: regenerate)
            try? await Task.sleep(for: .milliseconds(800))
            for _ in 0..<60 {
                if let meta = try? await client.meta(), meta.mode == mode { break }
                try? await Task.sleep(for: .milliseconds(500))
            }
            await refreshAll()
            return true
        } catch {
            toast(error.readable)
            return false
        }
    }
}
