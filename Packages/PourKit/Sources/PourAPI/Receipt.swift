public import Foundation

extension Show {
    /// 整行收据（formatReceipt）：「已记录：🏃 跑步 60 分钟 · 💡 2 条感悟；已删除：💼 被老板骂」。
    /// 每一项的字是服务器写好的（数字来自记下的记录），这里只按做了什么分组
    public static func receipt(_ items: [API.ReceiptItem]) -> String? {
        guard !items.isEmpty else { return nil }
        let groups: [(label: String, actions: [String])] = [
            ("已记录", ["created", "duplicate"]), ("已修改", ["updated"]), ("已完成", ["completed"]),
            ("已确认", ["confirmed"]), ("已删除", ["deleted"]),
        ]
        // 分组后每一项不用再重复动作：「删除 💼 被老板骂」→「💼 被老板骂」，「✅ 完成：看电影」→「✅ 看电影」
        func bare(_ item: API.ReceiptItem) -> String {
            var text = item.text
            for word in ["修改 ", "确认 ", "删除 "] where text.hasPrefix(word) { text.removeFirst(word.count) }
            if let range = text.range(of: " 完成："), text[text.startIndex..<range.lowerBound].count <= 2 {
                text.replaceSubrange(range, with: " ")
            }
            return text
        }
        var out: [String] = []
        for group in groups {
            let inGroup = items.filter { group.actions.contains($0.action) }
            guard !inGroup.isEmpty else { continue }
            let insights = inGroup.filter { $0.action == "created" && $0.kind == "insight" && !$0.pending }
            var parts = inGroup.filter { !insights.contains($0) }.map { $0.pending ? "\(bare($0))（待确认）" : bare($0) }
            if insights.count == 1, let only = insights.first { parts.append(only.text) }
            if insights.count > 1 { parts.append("💡 \(insights.count) 条感悟") }
            out.append("\(group.label)：\(parts.joined(separator: " · "))")
        }
        return out.joined(separator: "；")
    }

    /// 原话下面那个状态说的是实际做了什么（doneLabel）
    public static func doneLabel(_ result: API.NoteResult?) -> String {
        guard let result else { return "已处理" }
        if result.undone == true { return "已撤销" }
        if !result.questions.isEmpty || result.awaiting != nil { return "等你回答" }
        if result.answer != nil { return "已回答" }
        let actions = Set(result.receipt.map(\.action))
        if actions.contains("created") { return "已记录" }
        let single = ["deleted": "已删除", "updated": "已修改", "completed": "已完成", "confirmed": "已确认"]
        if actions.count == 1, let only = actions.first { return single[only] ?? "之前已记过" }
        if actions.count > 1 { return "已更新" }
        if !(result.goals ?? []).isEmpty { return "已更新目标" }
        return "已收到"
    }
}
