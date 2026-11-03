import Foundation
import WidgetKit

// MARK: - 小组件、控制中心（docs/模块/产品优化.md R7）

extension AppModel {
    /// 小组件、控制中心的「说一句」：回到画布、收起对话，输入框看到 voicePending 就开始听
    func requestVoice() {
        goHome()
        chatOpen = false
        search = nil
        voicePending = true
    }

    /// 记录、待办变了：桌面小组件、锁屏马上重新拿（系统会把太密的合在一起）
    func refreshWidgets() {
        guard remindersOn else { return }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
