import Foundation
import PourAPI

/// 对一个目标的操作（网页版 goals/use-goal-actions.ts）：确认、标记完成、原地修改、调整某个月、添加、删除（可撤销）
extension AppModel {
    /// 打开目标详情；记录详情开着就先收起它（网页版：从记录详情点相关目标，记录详情关掉、目标详情打开）
    func openGoal(_ id: Int) {
        guard detail != nil else {
            goalDetail = .init(id: id)
            return
        }
        detail = nil
        Task { [weak self] in
            // 等记录详情收下去再打开（同时弹两层系统会拒绝）
            try? await Task.sleep(for: .milliseconds(450))
            self?.goalDetail = .init(id: id)
        }
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
        Task {
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
