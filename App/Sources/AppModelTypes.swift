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
        /// 这条记录是哪一天的（回顾里打开别的日子的记录）；nil 是画布正在看的那一天
        var day: String?
        /// 从「钱」里点开的每个月固定扣的那一笔：详情里多一行「固定的 · 每个月几日 · 不再算固定的」
        var fixed: FixedPay?
    }

    struct GoalRef: Identifiable, Hashable {
        let id: Int
    }

    struct Notice: Equatable {
        let message: String
        /// 右边的操作（「撤销」「打开对话」）；没有是 nil
        let action: String?
        let id = UUID()
    }
}

/// 还没交给服务器的话存在手机上（UserDefaults）；界面测试（假服务器）的单独放：测试留下的话不会在平时打开时发给真的服务器
enum OutboxStore {
    /// 界面测试、画布样张（都是 App 里的假服务器）另存一份：它们说的话不能发到真的服务器上
    static var key: String {
        let stub = ProcessInfo.processInfo.arguments.contains("-uiTest") || CanvasSamples.isOn
        return stub ? "pour.outbox.uiTest" : "pour.outbox"
    }

    /// 真的服务器的那一份
    static let serverKey = "pour.outbox"

    static func load(from key: String = key) -> [AppModel.Outbox] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([AppModel.Outbox].self, from: data)) ?? []
    }

    static func save(_ items: [AppModel.Outbox], to key: String = key) {
        UserDefaults.standard.set(try? JSONEncoder().encode(items), forKey: key)
    }

    /// 画布样张里说的话：放进真的服务器的那一份，回到服务器的数据时发出去（产品主人 2026-10-26：
    /// 用语音说了今天做了什么，样张里的假服务器只回「好的，听到了」，没交给后台）
    static func queueForServer(_ text: String) {
        var items = load(from: serverKey)
        items.append(AppModel.Outbox(clientId: UUID().uuidString, text: text, createdAt: Date()))
        save(items, to: serverKey)
    }
}

/// 每个月固定扣的一笔：每个月几日扣、记录里的第几个数
struct FixedPay: Hashable {
    let dayOfMonth: Int
    let index: Int
}
