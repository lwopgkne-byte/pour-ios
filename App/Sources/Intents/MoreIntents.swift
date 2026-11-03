import AppIntents
import Foundation
import PourAPI

/// Siri 和快捷指令（3.0 第 10 步，docs/3.0/07-开发任务清单.md 10.4）：「记一笔」「记心情」打开 Pour 直接到数字键盘、记心情；
/// 「今天还有什么待办」不用打开 App，Siri 直接念
struct RecordMoneyIntent: AppIntent {
    static let title: LocalizedStringResource = "记一笔"
    static let description = IntentDescription("打开 Pour 的数字键盘记一笔。")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickActions.shared.pending = "pour.money"
        return .result()
    }
}

struct RecordMoodIntent: AppIntent {
    static let title: LocalizedStringResource = "记心情"
    static let description = IntentDescription("打开 Pour 记一下现在的心情。")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickActions.shared.pending = "pour.mood"
        return .result()
    }
}

struct TodayTodosIntent: AppIntent {
    static let title: LocalizedStringResource = "今天还有什么待办"
    static let description = IntentDescription("Pour 念一下今天还没做的待办。")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "\(await Self.sentence())")
    }

    /// 「今天还有 3 件：10:00 给客户回电话、交水费……」；连不上说连不上
    static func sentence() async -> String {
        guard let glance = try? await SharedClient.make().glance() else { return "连不上电脑上的 Pour。" }
        let today = glance.open.filter { !$0.overdue }
        guard !today.isEmpty else { return glance.total > 0 ? "今天的都做完了。" : "今天没有待办。" }
        let items = today.prefix(5).map { item in
            [item.remindAt, item.content].compactMap { $0 }.joined(separator: " ")
        }
        return "今天还有 \(today.count) 件：\(items.joined(separator: "、"))\(today.count > 5 ? "……" : "")。"
    }
}
