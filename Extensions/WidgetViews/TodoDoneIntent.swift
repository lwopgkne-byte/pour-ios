import AppIntents
import PourAPI
import PourPlatform
import WidgetKit

/// 小组件上勾一件待办（docs/模块/产品优化.md R7）：不用打开 App，直接告诉服务器做完了，小组件跟着刷新
struct TodoDoneIntent: AppIntent {
    static let title: LocalizedStringResource = "做完了"
    static let isDiscoverable = false

    @Parameter(title: "待办")
    var entryId: Int

    init() {}

    init(entryId: Int) {
        self.entryId = entryId
    }

    func perform() async throws -> some IntentResult {
        try? await SharedClient.make().setDone(entry: entryId, true)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
