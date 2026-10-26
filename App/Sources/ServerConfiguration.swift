import Foundation
import PourAPI
import PourPlatform

/// 服务器在哪：界面测试用假服务器（-uiTest）；启动参数 -serverURL 可以临时指定（对照演示数据时用）；
/// 设置里改过的地址在钥匙串里；都没有就用 Info.plist 的 PourServerURL
/// （Config/Base.xcconfig 的 POUR_SERVER_URL；装到手机时 install-device.sh 换成这台 Mac 在局域网里的名字）
enum ServerConfiguration {
    static let fallback = "http://127.0.0.1:5188"
    static let addressKey = "server.address"
    /// 这台设备的钥匙（配对时服务器给的，docs/模块/产品优化.md R8）：换了服务器地址就作废
    static let deviceKeyKey = "server.deviceKey"

    static var builtIn: URL {
        let configured = Bundle.main.object(forInfoDictionaryKey: "PourServerURL") as? String ?? ""
        return URL(string: configured.isEmpty ? fallback : configured) ?? URL(fileURLWithPath: "/")
    }

    static var address: URL { Keychain.read(addressKey).flatMap(URL.init(string:)) ?? builtIn }

    static func client(arguments: [String]) -> APIClient {
        #if DEBUG
            // 界面测试、画布样张：App 里的假服务器
            if arguments.contains("-uiTest") || CanvasSamples.isOn { return StubServer.client() }
        #endif
        if let index = arguments.firstIndex(of: "-serverURL"), index + 1 < arguments.count,
            let url = URL(string: arguments[index + 1])
        {
            return APIClient(baseURL: url)
        }
        return APIClient(baseURL: address) { Keychain.read(deviceKeyKey) }
    }

    /// 设置里改了地址：上一台服务器给的钥匙不再用（到新的那台要重新输 PIN）
    static func remember(address: URL) {
        Keychain.save(address.absoluteString, for: addressKey)
        Keychain.delete(deviceKeyKey)
    }

    /// 配对成功：把这台设备的钥匙存进钥匙串（只在这台手机上，不跟 iCloud 同步）
    static func remember(deviceKey: String?) {
        guard let deviceKey, !deviceKey.isEmpty else { return }
        Keychain.save(deviceKey, for: deviceKeyKey)
    }
}
