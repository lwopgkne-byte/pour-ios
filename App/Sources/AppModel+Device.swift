import Foundation
import PourAPI
import PourPlatform

// MARK: - 设备登录（docs/模块/产品优化.md R8）

extension AppModel {
    /// 连上了真的服务器、钥匙串里还没有这台设备的钥匙（以前用 cookie 登录的）：换一把存起来，
    /// 以后小组件、分享也能用它连服务器。旧服务器没有这个接口就算了，一次打开只试一次
    func ensureDeviceKey() async {
        guard remindersOn, !Self.deviceKeyTried, Keychain.read(ServerConfiguration.deviceKeyKey) == nil else { return }
        Self.deviceKeyTried = true
        if let pairing = try? await client.pairDevice() { ServerConfiguration.remember(deviceKey: pairing.token) }
    }

    /// 这次打开已经试过换钥匙了
    nonisolated(unsafe) static var deviceKeyTried = false
}
