import Foundation
import PourAPI
import PourPlatform

/// App 的扩展（小组件、分享）和 Siri 连服务器（docs/模块/产品优化.md R7）：地址在 App 组里（App 每次打开写一次），
/// 钥匙在钥匙串的共享组里（配对时存的，ServerConfiguration.remember）。App、小组件、分享三个目标都编译这一份
enum SharedClient {
    static let fallback = URL(string: "http://127.0.0.1:5188") ?? URL(fileURLWithPath: "/")
    static let deviceKeyKey = "server.deviceKey"

    static func make() -> APIClient {
        APIClient(baseURL: SharedStore.address ?? fallback) {
            Keychain.read(deviceKeyKey, group: SharedStore.keychainGroup)
        }
    }

    /// 说一段话：发给服务器；连不上就先存在 App 组里，Pour 打开时再发（和没网时说的话一样不丢）。回来的是给人看的一句
    static func say(_ text: String) async -> String {
        do {
            try await make().send(text, clientId: UUID().uuidString)
            return "发给 Pour 了"
        } catch {
            SharedStore.addPendingShare(text)
            return "连不上电脑上的 Pour，先存在手机上，打开 Pour 时再发"
        }
    }
}
