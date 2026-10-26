import Foundation
import PourAPI

// MARK: - 版本（docs/模块/产品优化.md R8）

extension AppModel {
    /// 电脑上的 Pour 比这个 App 要的旧（没有接口版本的是 2.7.0 以前的）：说清楚要更新，不往下拿（拿到的看不懂会出错）。
    /// 反过来手机上的太旧，服务器回 426，那句话照样写在这里
    func serverProblem(_ meta: API.Meta) -> String? {
        serverVersion = meta
        return Self.serverProblem(api: meta.api?.version)
    }

    static func serverProblem(api: Int?) -> String? {
        (api ?? 0) < APIClient.apiVersion ? "电脑上的 Pour 要更新到 2.7.0 以上，手机上的这个版本才能用。" : nil
    }

    /// 设置里「电脑上的 Pour」那一行：「2.7.0 · 接口第 1 版」
    var serverVersionText: String? {
        guard let meta = serverVersion, let server = meta.server else { return nil }
        return meta.api.map { "\(server) · 接口第 \($0.version) 版" } ?? server
    }
}
