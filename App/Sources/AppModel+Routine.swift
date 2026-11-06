import Foundation
import PourAPI

/// 待办时间线这一块的状态（AppModel.timeline，产品主人 2026-11-06）：作息、作息弹框开着没有
@Observable
@MainActor
final class TimelineState {
    /// 作息（服务器 2.23.0）：没拿到是 nil（旧服务器、没网）——时间线照旧从 8 点画到 22 点
    var routine: API.Routine?
    /// 作息弹框开着
    var editing = false
}

extension AppModel {
    /// 拿作息（待办页打开时）；拿不到不动已有的
    func loadRoutine() async {
        guard let got = try? await client.routine() else { return }
        timeline.routine = got
    }

    /// 存作息（作息弹框点「保存」）：先改时间线再发；没存上改回去，说一句
    func saveRoutine(_ blocks: [API.RoutineBlock]) {
        let old = timeline.routine
        timeline.routine = API.Routine(blocks: blocks, custom: true)
        let client = self.client
        Task {
            do {
                timeline.routine = try await client.saveRoutine(blocks)
            } catch {
                timeline.routine = old
                toast("作息没存上：连不上电脑上的 Pour，等会儿再试")
            }
        }
    }
}
