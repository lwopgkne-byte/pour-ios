import Foundation
import Observation
import PourAPI

// MARK: - 目标（3.0 第 7 步，docs/3.0/01-需求文档.md 第 9 章、06 交互细节第 12 节）

/// 目标这一块的状态（AppModel.goals）：开着的弹层（定目标、花 1 分钟想清楚、聊聊怎么调、每周回顾）、刚定好的那一个
@Observable
@MainActor
final class GoalsState {
    var sheet: GoalSheet?
    /// 刚定好的目标：首页那张卡亮一下、环转一下（一次）
    var fresh: Int?
    /// 按住菜单里点了「改」：打开那个目标、滚到设置
    var editing: Int?
}

/// 目标的弹层
enum GoalSheet: Identifiable, Hashable {
    /// 定目标；带着一句（还没有目标时的建议「定这个」、领域页的建议）直接去理解
    case define(String?)
    /// 花 1 分钟想清楚；step 是只改那一句（0 为什么 · 1 拦住我的 · 2 如果就）
    case woop(Int, step: Int?)
    /// 聊聊怎么调
    case grow(Int)
    /// 每周回顾
    case weekly

    var id: String {
        switch self {
        case .define(let text): "define:\(text ?? "")"
        case .woop(let id, let step): "woop:\(id):\(step ?? -1)"
        case .grow(let id): "grow:\(id)"
        case .weekly: "weekly"
        }
    }
}

extension AppModel {
    /// 打开一个目标（推进来一页）：记录详情、目标详情开着就先收起
    func openGoal(_ id: Int) {
        guard detail != nil || goalDetail != nil else {
            open("/goals/\(id)")
            return
        }
        detail = nil
        goalDetail = nil
        Task { [weak self] in
            // 等弹层收下去再推（同时动两层系统会拒绝）
            try? await Task.sleep(for: .milliseconds(450))
            self?.open("/goals/\(id)")
        }
    }

    /// 暂停 / 继续 / 标记完成 / 放下 / 再试试 / 改回进行中：不弹确认框，轻提示带「撤销」
    func goalAct(_ id: Int, _ action: String, until: String? = nil, why: String? = nil) {
        goalChange { try await $0.goalAct(id, action, until: until, why: why) }
    }

    /// 改名称、目标值、我在乎的、补假、少提醒、提醒、三句话
    func goalSet(_ id: Int, _ change: GoalChange) {
        goalChange { try await $0.goalSet(id, change) }
    }

    /// 勾里程碑：最后一步勾掉就是做完（成功的触感在页面上）
    func goalMilestone(_ id: Int, index: Int, done: Bool) {
        goalChange { try await $0.goalMilestone(id, index: index, done: done) }
    }

    /// 回答「算不算」
    func goalAnswer(_ id: Int, counts: Bool) {
        goalChange { try await $0.goalAnswer(id, counts: counts) }
    }

    /// GROW 选了一个办法：马上生效
    func applyGrow(_ id: Int, key: String, restart: Bool, remind: API.GoalRemind?, ifthen: String?) {
        goalChange { try await $0.applyGrow(id, key: key, restart: restart, remind: remind, ifthen: ifthen) }
    }

    /// 删一个目标：大目标连子目标一起删、一起撤销
    func deleteGoal(_ id: Int, title: String) {
        let client = self.client
        Task {
            do throws(APIError) {
                try await client.deleteGoal(id)
                dataChanged()
                toast("删了：\(title)", action: "撤销") { [weak self] in
                    self?.goalUndoWork { try await $0.restoreGoal(id) }
                }
            } catch {
                toast(error.message)
            }
        }
    }

    /// 每周回顾的「下周最重要的一件」放进待办：撤销是删掉这条待办
    func weeklyTodo(_ todo: API.WeeklyTodo) {
        let client = self.client
        Task {
            do throws(APIError) {
                let made = try await client.weeklyTodo(todo)
                dataChanged()
                toast(made.toast, action: "撤销") { [weak self] in
                    self?.goalUndoWork { try await $0.delete(entry: made.entryId) }
                }
            } catch {
                toast(error.message)
            }
        }
    }

    /// 这个季度打几分：撤销把原来的分放回去
    func careScore(_ key: String, _ value: Int) {
        let client = self.client
        Task {
            do throws(APIError) {
                let out = try await client.careScore(key, value)
                dataChanged()
                toast(out.toast, action: "撤销") { [weak self] in
                    self?.goalUndoWork { _ = try await $0.careScore(key, out.before) }
                }
            } catch {
                toast(error.message)
            }
        }
    }

    /// 改了以后：轻提示那一句 +「撤销」（恢复到改之前的版本）
    private func goalChange(_ work: @escaping @Sendable (APIClient) async throws -> API.GoalDone) {
        let client = self.client
        Task {
            do {
                let out = try await work(client)
                dataChanged()
                guard !out.undo.isEmpty else {
                    toast(out.toast)
                    return
                }
                toast(out.toast, action: "撤销") { [weak self] in
                    self?.goalUndoWork { try await $0.goalUndo(out.undo) }
                }
            } catch {
                toast((error as? APIError)?.message ?? APIError.unreachable.message)
            }
        }
    }

    /// 「到家的时候」提醒你「如果就」：用现在的位置当家（只存在手机上），重排提醒；定不到位置说怎么打开
    func setHomeHere() async -> Bool {
        guard let point = await HomePlace.locate() else {
            toast("没定到位置：在 iPhone 的「设置 → Pour → 位置」里选「使用 App 期间」，再点一次")
            return false
        }
        HomePlace.save(point)
        toast("记下了：这里是家 · 到家的时候提醒你「如果就」")
        syncReminders()
        return true
    }

    private func goalUndoWork(_ work: @escaping @Sendable (APIClient) async throws -> Void) {
        let client = self.client
        Task {
            do {
                try await work(client)
                dataChanged()
            } catch {
                toast((error as? APIError)?.message ?? APIError.unreachable.message)
            }
        }
    }
}
