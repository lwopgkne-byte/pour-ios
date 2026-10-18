import OSLog

/// 系统日志（docs/03 第 6.2 节）。这里只记出了什么事，**不记原话**：原话是你的隐私，日志里一个字都不放
enum Log {
    private static let app = Logger(subsystem: "com.lwopgkne.pour", category: "app")

    static func error(_ message: String) {
        app.error("\(message, privacy: .public)")
    }
}
