import Foundation
import PourAPI
import PourPlatform

// MARK: - 提醒（3.0 红线，docs/3.0/01-需求文档.md 4.4）

extension AppModel {
    /// 照服务器的提醒单子重排系统通知：全部没做完、带提醒、还没到点的（最近 60 条），不再只排看过的那几天。
    /// 每次拿这一天（打开、回到前台、记录变了）都排一遍；一会儿内连着变了几次只排最后一次。
    /// 演示数据的不排（docs/模块/演示数据.md：演示里那个人的「10:00 给客户回电话」不该在你手机上响；你自己已经排好的照常响）
    func syncReminders() {
        guard remindersOn, !demo else { return }
        reminderSync?.cancel()
        let client = self.client
        reminderSync = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await TodoNotifications.sync(client)
            reminderState = ReminderState(
                permission: await Reminders.permission(), scheduled: await Reminders.pending().count)
        }
    }
}

/// 待办页底下那一行（提醒是红线：排上了几条、通知关着都让人看得见）
struct ReminderState: Equatable {
    let permission: Reminders.Permission
    /// 排上了几条
    let scheduled: Int

    /// 「手机上排好了 3 个提醒，到点就响」「通知关着：到点不会响……」；没什么要说的是 nil
    var text: String? {
        switch permission {
        case .denied: "通知关着：定了时间的待办到点不会响。在 iPhone 的「设置 → 通知 → Pour」里打开"
        case .allowed where scheduled > 0: "手机上排好了 \(scheduled) 个提醒，到点就响"
        default: nil
        }
    }
}
