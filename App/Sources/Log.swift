import OSLog

/// 系统日志（docs/归档/03 第 6.2 节）。这里只记出了什么事，**不记原话**：原话是你的隐私，日志里一个字都不放
enum Log {
    private static let app = Logger(subsystem: "com.lwopgkne.pour", category: "app")
    /// 最近几次出错（只在这台手机的内存里，反馈时带上；不记原话）
    @MainActor private(set) static var recent: [String] = []

    static func error(_ message: String) {
        app.error("\(message, privacy: .public)")
        Task { @MainActor in recent = Array((recent + [message]).suffix(10)) }
    }
}
