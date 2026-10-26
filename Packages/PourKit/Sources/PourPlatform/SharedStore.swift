public import Foundation

/// App 和它的扩展（桌面小组件、分享，docs/模块/产品优化.md R7）一起用的东西：服务器地址放在 App 组里，
/// 设备的钥匙放在钥匙串的共享组里。两个组的名字写在每个目标的 Info.plist 里（PourAppGroup、PourKeychainGroup），
/// 没写（单元测试、画廊）就是 nil，什么都不共享
public enum SharedStore {
    /// App 组：group.com.lwopgkne.pour.dev
    public static var appGroup: String? { Bundle.main.object(forInfoDictionaryKey: "PourAppGroup") as? String }

    /// 钥匙串共享组：<团队前缀>com.lwopgkne.pour.shared
    public static var keychainGroup: String? {
        Bundle.main.object(forInfoDictionaryKey: "PourKeychainGroup") as? String
    }

    /// App 组里的设置（没有 App 组就是 nil）
    public static var defaults: UserDefaults? { appGroup.flatMap(UserDefaults.init(suiteName:)) }

    /// 服务器地址：App 每次打开写一次，扩展读
    public static let addressKey = "server.address"
    /// 分享时连不上电脑：先存在这里，App 打开时交给服务器
    public static let pendingSharesKey = "share.pending"

    public static var address: URL? {
        defaults?.string(forKey: addressKey).flatMap(URL.init(string:))
    }

    public static func publish(address: URL) {
        defaults?.set(address.absoluteString, forKey: addressKey)
    }

    /// 分享扩展连不上电脑时存下的话（App 打开时取走，放进待发）
    public static func takePendingShares() -> [String] {
        let items = defaults?.stringArray(forKey: pendingSharesKey) ?? []
        if !items.isEmpty { defaults?.removeObject(forKey: pendingSharesKey) }
        return items
    }

    public static func addPendingShare(_ text: String) {
        var items = defaults?.stringArray(forKey: pendingSharesKey) ?? []
        items.append(text)
        defaults?.set(items, forKey: pendingSharesKey)
    }
}
