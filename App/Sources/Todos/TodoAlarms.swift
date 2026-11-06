import AppIntents
import Foundation
import PourPlatform

/// 闹钟上点「停止」（产品主人 2026-11-06：响铃的待办）：这件算做完了——叫我起床的，叫醒了就是做完了；
/// 重复的（每天 7 点叫我起床）做完了服务器生成下一次，重排时接着排上明天的闹钟。
/// 系统在 App 的进程里跑（App 没开着就在后台叫醒 App），和通知上的「完成」走同一条路：App 开着先改界面，
/// 没开着直接发到电脑上的 Pour，连不上排在手机上，下次打开自动发
struct AlarmStopIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "停止响铃"
    /// 不放进快捷指令里（只给闹钟用）
    static let isDiscoverable = false

    @Parameter(title: "待办") var todo: Int

    init() {}

    init(todo: Int) {
        self.todo = todo
    }

    func perform() async throws -> some IntentResult {
        await TodoNotifications.handle(.done, todo)
        return .result()
    }
}
