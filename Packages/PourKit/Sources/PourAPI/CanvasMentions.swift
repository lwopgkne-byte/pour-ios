import Foundation

/// 「说到的」小胶囊旁边写什么（产品主人 2026-10-21：画布跟着说的话长；服务器 SPEC 7.3）
extension CanvasPlan {
    /// 第一次说到写「第一次」；这周说到两天以上写「这周 N 天」（数的是天数，从周一算起：设计评审 2026-10-23 说
    /// 「这周第 3 次」分不清是几次、几条还是几天）；别的不写（只说过这一次又不是第一次的，不打扰）
    public static func mentionNote(_ history: API.MentionHistory?) -> String? {
        guard let history else { return nil }
        if history.firstTime { return "第一次" }
        return history.weekDays >= 2 ? "这周 \(history.weekDays) 天" : nil
    }

    /// 一个名字以前说到过多少：kind 是 person / thing / place / tag
    public static func history(_ mentions: [API.MentionHistory]?, kind: String, name: String) -> API.MentionHistory? {
        mentions?.first { $0.kind == kind && $0.name == name }
    }
}
