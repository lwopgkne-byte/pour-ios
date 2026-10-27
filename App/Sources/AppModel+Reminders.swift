import Foundation
import PourAPI
import PourData
import PourPlatform

// MARK: - 提醒

extension AppModel {
    /// 看到的待办里要提醒的，手机自己排系统通知。演示数据的待办不排（docs/模块/演示数据.md）：
    /// 演示里那个人的「10:00 给客户回电话」不该到点在你手机上响；你自己的已经排好的照常响
    func noteReminders(_ view: API.DayView) {
        guard remindersOn, !demo else { return }
        reminders[view.day] = view.entries.compactMap { entry in
            guard case .todo(let todo) = entry.data, !todo.done, let time = todo.remindAt else { return nil }
            return Reminder(id: String(entry.id), content: todo.content, time: time)
        }
        let all = reminders.values.flatMap { $0 }
        Task { await Reminders.sync(all) }
    }
}
