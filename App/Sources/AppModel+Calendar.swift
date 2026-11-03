import Foundation
import PourCore

// MARK: - 日历（docs/模块/产品优化.md R6）

extension AppModel {
    /// 点「接上」：问系统要权限，给了就读正在看的那天
    func connectCalendar() {
        Task {
            if await calendar.connect() {
                // 演示数据时待办里是演示的日程：你的日程回到真实数据才出现
                toast(demo ? "接上了：回到真实数据后，日程会出现在待办里" : "接上了：日程会出现在待办里")
                await calendar.load(shownDay, boundary: dayBoundary)
            } else {
                toast("没拿到读日历的权限：在 iPhone 的「设置 → 隐私与安全性 → 日历」里给 Pour")
            }
        }
    }

    /// 读正在看的那天的日程（换一天、回到前台、换了真实 / 演示数据时）：演示数据时是演示里那个人的（docs/模块/演示数据.md）
    func loadCalendar() {
        let day = shownDay
        let boundary = dayBoundary
        if calendar.demo {
            let client = self.client
            Task { await calendar.loadDemo(day, from: client) }
        } else {
            Task { await calendar.load(day, boundary: boundary) }
        }
    }

    /// 待办页：读今天的日程（穿插在「今天」里、今天的时间线；画布在看别的日子时也要今天的）
    func loadTodayEvents() {
        let day = today
        let boundary = dayBoundary
        if calendar.demo {
            let client = self.client
            Task { await calendar.loadDemo(day, from: client) }
        } else {
            Task { await calendar.load(day, boundary: boundary) }
        }
    }

    /// 正在看的那天的日程（没接日历是空的；演示数据时是演示的）
    var shownEvents: [CalendarItem] { calendar.items[shownDay] ?? [] }
}
