public import Foundation

/// 斜杠命令（shared commands.ts 原样）：输入「/」直接指定意图（/问 /记 /目标 /改，交给 AI），
/// 或者在手机上直接做（/搜索 /今天 /周报 /撤销，不发给 AI）
public struct SlashCommand: Hashable, Sendable {
    public let cmd: String
    /// 交给 AI 时指定的意图；nil 是在手机上直接做的
    public let intent: String?
    /// 直接做的是哪件事：search、today、report、undo
    public let action: String?
    public let label: String
    public let example: String
    /// 另一个叫法（/找 = /搜索）：只有写全了才列出来
    public let alias: Bool

    init(
        _ cmd: String, intent: String? = nil, action: String? = nil, _ label: String, _ example: String,
        alias: Bool = false
    ) {
        self.cmd = cmd
        self.intent = intent
        self.action = action
        self.label = label
        self.example = example
        self.alias = alias
    }
}

extension Show {
    public static let slashCommands: [SlashCommand] = [
        SlashCommand("/问", intent: "question", "提问", "/问 这周运动了几次"),
        SlashCommand("/记", intent: "record", "只记录", "/记 读了 30 页书"),
        SlashCommand("/目标", intent: "goal", "设目标", "/目标 每周运动 3 次"),
        SlashCommand("/改", intent: "correction", "纠错", "/改 刚才那次跑步是 5 公里"),
        SlashCommand("/搜索", action: "search", "找东西", "/搜索 三体"),
        SlashCommand("/找", action: "search", "找东西", "/找 三体", alias: true),
        SlashCommand("/今天", action: "today", "回到今天", "/今天"),
        SlashCommand("/周报", action: "report", "看最近的周报", "/周报"),
        SlashCommand("/撤销", action: "undo", "撤销上一段话", "/撤销"),
    ]

    /// 刚输入「/」还没写完命令时，可以用的命令（/^\/\S*$/）
    public static func slashMenu(_ text: String) -> [SlashCommand] {
        guard text.hasPrefix("/"), !text.contains(where: \.isWhitespace) else { return [] }
        return slashCommands.filter { $0.cmd.hasPrefix(text) && (!$0.alias || $0.cmd == text) }
    }

    /// 「/问 这周运动了几次」→ 命令和后面的内容；不是命令是 nil（长的命令先比：/目标 不要被当成别的）
    public static func parseSlash(_ text: String) -> (command: SlashCommand, rest: String)? {
        let trimmed = String(text.drop { $0.isWhitespace })
        guard trimmed.hasPrefix("/") else { return nil }
        for command in slashCommands.sorted(by: { $0.cmd.count > $1.cmd.count })
        where trimmed == command.cmd || trimmed.hasPrefix(command.cmd + " ")
            || trimmed.hasPrefix(command.cmd + "\u{3000}")
        {
            let rest = trimmed.dropFirst(command.cmd.count).trimmingCharacters(in: .whitespacesAndNewlines)
            return (command, rest)
        }
        return nil
    }

    /// 晚上（6 点到日界线）：输入框的示例换成「今天哪一刻觉得挺好？」（shared mood.ts 的 isEvening）
    public static func isEvening(_ now: Date, boundary: Int, calendar: Calendar = .current) -> Bool {
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return minutes >= 18 * 60 || minutes < boundary
    }
}

extension APIClient {
    /// 最近的周报、月报（/周报 打开最近的那一份）
    public func reports() async throws(APIError) -> [API.SystemMessage] {
        let page: Reports = try await get("/api/reports")
        return page.reports
    }

    struct Reports: Decodable {
        let reports: [API.SystemMessage]
    }
}
