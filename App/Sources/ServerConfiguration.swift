import Foundation
import PourAPI
import PourPlatform

/// 服务器在哪：界面测试用假服务器（-uiTest）；启动参数 -serverURL 可以临时指定（对照演示数据时用）；
/// 设置里改过的地址在钥匙串里；都没有就用 Info.plist 的 PourServerURL
/// （Config/Base.xcconfig 的 POUR_SERVER_URL；装到手机时 install-device.sh 换成这台 Mac 在局域网里的名字）
enum ServerConfiguration {
    static let fallback = "http://127.0.0.1:5188"
    static let addressKey = "server.address"

    static var builtIn: URL {
        let configured = Bundle.main.object(forInfoDictionaryKey: "PourServerURL") as? String ?? ""
        return URL(string: configured.isEmpty ? fallback : configured) ?? URL(fileURLWithPath: "/")
    }

    static var address: URL { Keychain.read(addressKey).flatMap(URL.init(string:)) ?? builtIn }

    static func client(arguments: [String]) -> APIClient {
        #if DEBUG
            if arguments.contains("-uiTest") { return StubServer.client() }
        #endif
        if let index = arguments.firstIndex(of: "-serverURL"), index + 1 < arguments.count,
            let url = URL(string: arguments[index + 1])
        {
            return APIClient(baseURL: url)
        }
        return APIClient(baseURL: address)
    }

    /// 设置里改了地址
    static func remember(address: URL) {
        Keychain.save(address.absoluteString, for: addressKey)
    }
}
