import Foundation
import PourAPI

/// 对一个目标的操作：确认、标记完成、原地修改、调整某个月、添加、删除（可撤销）
extension AppModel {
    /// 打开一条记录的详情；day 是它是哪一天的（不是画布正在看的那天时，详情自己去拿那一天）
    func openEntry(_ id: Int, day: String?) {
        detail = .init(id: id, day: day == shownDay ? nil : day)
    }

    func confirmGoal(_ id: Int) { goalAction { try await $0.confirmGoal(id) } }

    func setGoalDone(_ id: Int, _ done: Bool) { goalAction { try await $0.setGoalDone(id, done) } }

    /// 原地修改：出错抛出，给原地编辑的框说为什么
    func updateGoal(_ id: Int, _ fields: [String: JSONValue]) async throws(APIError) {
        try await client.updateGoal(id, fields)
        dataChanged()
    }

    /// 调整某个月的目标值；nil 是恢复按天数自动分配
    func adjustMonth(_ id: Int, month: String, target: Double?) {
        goalAction { try await $0.adjustMonth(id, month: month, target: target) }
    }

    func createGoal(_ body: [String: JSONValue]) async throws(APIError) {
        try await client.createGoal(body)
        dataChanged()
    }

    /// 删掉：轻提示上能「撤销」
    func removeGoal(_ id: Int) {
        let client = self.client
        Task { [self] in
            do {
                try await client.deleteGoal(id)
                dataChanged()
                toast("已删除目标", action: "撤销") { [weak self] in
                    self?.goalAction { try await $0.restoreGoal(id) }
                }
            } catch {
                toast(error.readable)
            }
        }
    }

    private func goalAction(_ work: @escaping @Sendable (APIClient) async throws -> Void) {
        let client = self.client
        Task {
            do {
                try await work(client)
                dataChanged()
            } catch let error as APIError {
                toast(error.message)
            } catch {
                toast(APIError.unreachable.message)
            }
        }
    }
}
