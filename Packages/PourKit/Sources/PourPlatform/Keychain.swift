public import Foundation
import Security

/// 钥匙串（系统能力层）：存真机配对换来的网关令牌这类不能放进 App 包、不能放在普通设置里的东西。
/// 只在这台手机上（不跟 iCloud 同步），解锁过一次以后后台也读得到（整理排队时要用）
public enum Keychain {
    private static let service = "com.lwopgkne.pour"

    /// group：钥匙串共享组（App 和小组件、分享扩展一起用，SharedStore.keychainGroup）；nil 是只有这个 App 自己
    public static func read(_ key: String, group: String? = nil) -> String? {
        var query = base(key, group: group)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(bytes: data, encoding: .utf8)
    }

    @discardableResult
    public static func save(_ value: String, for key: String, group: String? = nil) -> Bool {
        delete(key, group: group)
        var query = base(key, group: group)
        query[kSecValueData as String] = Data(value.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    public static func delete(_ key: String, group: String? = nil) -> Bool {
        let status = SecItemDelete(base(key, group: group) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private static func base(_ key: String, group: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        if let group { query[kSecAttrAccessGroup as String] = group }
        return query
    }
}
