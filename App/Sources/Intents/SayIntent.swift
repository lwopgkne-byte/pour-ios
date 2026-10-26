import AppIntents

/// 快捷指令和 Siri 的「记一句」（docs/模块/产品优化.md R7）：说的话交给电脑上的 Pour 整理，不用打开 App。
/// 「嘿 Siri，用 Pour 记一句」——Siri 会问说什么
struct SayIntent: AppIntent {
    static let title: LocalizedStringResource = "记一句"
    static let description = IntentDescription("说一句话，交给 Pour 整理成记录。")

    @Parameter(title: "说什么", requestValueDialog: "说什么？")
    var text: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "\(await SharedClient.say(text))")
    }
}

/// 不用设置就能用的快捷指令
struct PourShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SayIntent(),
            phrases: ["用\(.applicationName)记一句", "\(.applicationName)记一句"],
            shortTitle: "记一句",
            systemImageName: "mic")
    }
}
