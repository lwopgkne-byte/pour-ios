import Foundation
import PourCore

// MARK: - 日历（docs/模块/产品优化.md R6）

extension AppModel {
    /// 点「接上」：问系统要权限，给了就读正在看的那天
    func connectCalendar() {
        Task {
            if await calendar.connect() {
                toast("接上了：日程会出现在待办里")
                await calendar.load(shownDay, boundary: dayBoundary)
            } else {
                toast("没拿到读日历的权限：在 iPhone 的「设置 → 隐私与安全性 → 日历」里给 Pour")
            }
        }
    }

    /// 读正在看的那天的日程（换一天、回到前台时）
    func loadCalendar() {
        let day = shownDay
        let boundary = dayBoundary
        Task { await calendar.load(day, boundary: boundary) }
    }

    /// 正在看的那天的日程（没接日历是空的）
    var shownEvents: [CalendarItem] { calendar.items[shownDay] ?? [] }
}
