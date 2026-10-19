import Foundation

// App 状态里用到的几种小东西
extension AppModel {
    /// 一段还没交给服务器的话
    struct Outbox: Codable, Hashable, Identifiable {
        let clientId: String
        let text: String
        let createdAt: Date
        /// 连不上、服务器拒了：说清楚，自动重试
        var failed: String?

        var id: String { clientId }
    }

    struct EntryRef: Identifiable, Hashable {
        let id: Int
    }

    struct Notice: Equatable {
        let message: String
        /// 右边的操作（「撤销」「打开对话」）；没有是 nil
        let action: String?
        let id = UUID()
    }
}
