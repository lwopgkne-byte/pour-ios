import Foundation

// MARK: - 演示数据（docs/模块/演示数据.md）

extension AppModel {
    /// 电脑上的 Pour 在用演示数据：画布上是演示里那个人的生活
    var demo: Bool { mode == "demo" }

    /// 换了真实数据、演示数据：日程换成演示的（或者回到这台手机的日历），小组件、锁屏马上重新拿
    func modeChanged() {
        calendar.useDemo(demo)
        loadCalendar()
        refreshWidgets()
    }

    /// 接上健康的小卡：演示数据时不出现（演示里是那个人手表的数据，你手机上的不送过去）
    var showHealthHint: Bool { !demo && health.showHint }
}
