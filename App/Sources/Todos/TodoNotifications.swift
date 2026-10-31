import BackgroundTasks
import Foundation
import PourAPI
import PourCore
import PourPlatform

/// 通知上的按钮和后台刷新（docs/3.0/06-交互细节.md 2.6、07 开发任务清单 2.15）：
/// 点「完成 · 10 分钟后 · 1 小时后 · 明天早上」不用打开 App——App 开着就交给 AppModel（界面跟着变），
/// 没开着时系统在后台叫醒 App，这里直接发到电脑上的 Pour；没连上就排在手机上（写操作队列），下次打开自动发
enum TodoNotifications {
    /// 正在用的 AppModel（AppModel.start 设上）
    @MainActor static weak var model: AppModel?
    /// 后台刷新提醒的任务名（Info.plist 的 BGTaskSchedulerPermittedIdentifiers）
    static let refreshTask = "pour.reminders.refresh"

    /// 启动时（App 的代理）：注册按钮、接住点了什么
    @MainActor
    static func listen() {
        Reminders.listen { action, id in await handle(action, id) }
    }

    static func handle(_ action: Reminders.Action, _ id: Int) async {
        let mapped: TodoAction =
            switch action {
            case .done: .done
            case .tenMinutes: .tenMinutes
            case .hour: .hour
            case .tomorrow: .tomorrow
            case .open: .open
            }
        if let model = await model {
            await model.perform(mapped, todo: id)
            return
        }
        // 点了通知本身：App 正在打开，外壳起来以后打开待办
        if mapped == .open {
            await MainActor.run { QuickActions.shared.pendingPath = "/todos" }
            return
        }
        let client = ServerConfiguration.client(arguments: ProcessInfo.processInfo.arguments)
        guard let send = request(mapped, id) else { return }
        let body = try? JSONEncoder().encode(send.json)
        do throws(APIError) {
            try await client.write(send.method, send.path, body: body)
        } catch .unreachable {
            var writes = WriteStore.load()
            writes.append(PendingWrite(id: UUID(), method: send.method, path: send.path, body: body, createdAt: Date()))
            WriteStore.save(writes)
        } catch {}
        await sync(client)
    }

    /// 通知上的按钮发什么（App 没开着时用；开着时 AppModel.perform 先改界面再发同样的）
    /// 一个要发的写操作
    struct Send {
        let method: String
        let path: String
        let json: JSONValue
    }

    static func request(_ action: TodoAction, _ id: Int, now: Date = Date()) -> Send? {
        switch action {
        case .done: return Send(method: "PATCH", path: "/api/entries/\(id)", json: .object(["done": .bool(true)]))
        case .tenMinutes:
            let local = PourDate.localDateTime(now.addingTimeInterval(600), in: .current)
            return Send(
                method: "POST", path: "/api/todos/\(id)/snooze",
                json: AppModel.dayAndTime(String(local.prefix(10)), String(local.suffix(5))))
        case .hour:
            return Send(method: "POST", path: "/api/todos/\(id)/snooze", json: .object(["preset": .string("hour")]))
        case .tomorrow:
            return Send(
                method: "POST", path: "/api/todos/\(id)/snooze", json: .object(["preset": .string("tomorrow")]))
        case .open: return nil
        }
    }

    /// 照服务器的提醒单子重排（拿不到就不动已经排好的）
    static func sync(_ client: APIClient) async {
        guard let list = try? await client.todoReminders() else { return }
        await Reminders.sync(
            list.map { Reminder(id: String($0.id), content: $0.content, time: $0.at, said: $0.said.map(Show.monthDay)) }
        )
    }

    /// 后台刷新（系统挑时候叫醒，大约一小时一次）：重排提醒，再约下一次
    static func refreshInBackground() async {
        schedule()
        let client = ServerConfiguration.client(arguments: ProcessInfo.processInfo.arguments)
        let demo = (try? await client.meta())?.mode == "demo"
        guard !demo else { return }
        await sync(client)
    }

    /// 约下一次后台刷新（进后台时）；界面测试、样张不约
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTask)
        request.earliestBeginDate = Date().addingTimeInterval(3600)
        Task { try? await BGTaskScheduler.shared.submitTaskRequest(request) }
    }
}
