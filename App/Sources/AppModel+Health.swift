import Foundation
import PourAPI

// MARK: - 健康（docs/模块/产品优化.md R5）

extension AppModel {
    /// 点「接上」：问系统要权限，读最近一个月的送到电脑上的 Pour，再拿一遍这一天
    func connectHealth() {
        Task {
            if let error = await health.connect(client) {
                toast(Self.healthProblem(error))
                return
            }
            if health.connected { toast("接上了：步数、睡眠、锻炼会自动出现") }
            dataChanged()
        }
    }

    /// 开 App、回到前台时读一次（三分钟内读过就不读）；变了的那几天服务器会推「变了」
    func syncHealth() {
        Task { await health.sync(client) }
    }

    /// 断开：不再读；电脑上的 Pour 里送过去的全部删掉
    func disconnectHealth() {
        Task {
            if let error = await health.disconnect(client) {
                toast(Self.healthProblem(error))
                return
            }
            toast("断开了：电脑上的 Pour 里健康的数据都删掉了")
            dataChanged()
        }
    }

    /// 送不过去时说一句：电脑上的 Pour 太旧（没有这个接口）、连不上
    static func healthProblem(_ error: APIError) -> String {
        if case .server(let status, _, _) = error, status == 404 { return "电脑上的 Pour 要更新到 2.6.0 才能接健康" }
        return error.message
    }
}
