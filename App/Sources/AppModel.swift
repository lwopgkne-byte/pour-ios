import Foundation
import Network
import Observation
import PourAPI
import PourCore
import PourData
import PourPlatform

/// App 的状态（产品主人 2026-10-19 选 B）：数据、业务规则和 AI 全在网页版的服务器上，手机读写它的接口。
/// 说一句：原话先存在手机上（没网也不丢）→ 交给服务器 → 服务器整理完推过来「变了」→ 手机重新拿这一天
@MainActor
@Observable
final class AppModel {
    let client: APIClient

    /// 服务器按日界线算的今天
    private(set) var today: String
    /// 画布正在看哪一天
    private(set) var shownDay: String
    /// 正在看的那一天（还没拿到是 nil）
    private(set) var day: API.DayView?
    /// 这一天说的话（画布上「正在整理…」那一行）
    private(set) var dayNotes: [API.Note] = []
    /// 对话面板：最近说的话，从早到晚
    private(set) var chat: [API.Note] = []
    private(set) var chatHasMore = false
    private(set) var categories: [API.Category] = []
    /// 没连上服务器时说一句（连上了是 nil）
    private(set) var offline: String?
    /// 还没交给服务器的话：没网时先存在手机上，连上了自动发（网页版 chat.tsx 的 outbox）
    private(set) var outbox: [Outbox] = []

    var draft = ""
    /// 正在看哪一页（左上角菜单换）
    var page: Page = .canvas
    /// 对话面板开着没有（网页版 Composer：发出去就向上展开）
    var chatOpen = false
    /// 打开详情的那条记录
    var detail: EntryRef?
    /// 删掉一条之后的轻提示（「已删除 · 撤销」，几秒后自己消失）
    private(set) var undoable: Undoable?

    private var events: Task<Void, Never>?
    private var undoTimer: Task<Void, Never>?
    private let network = NWPathMonitor()
    private var remindersOn = false
    /// 看过的日子里要提醒的待办（按日子存，换着看也不丢）
    private var reminders: [String: [Reminder]] = [:]

    /// 一段还没交给服务器的话
    struct Outbox: Codable, Hashable, Identifiable {
        let clientId: String
        let text: String
        let createdAt: Date
        /// 连不上、服务器拒了：说清楚，自动重试
        var failed: String?

        var id: String { clientId }
    }

    struct EntryRef: Identifiable, Hashable {
        let id: Int
    }

    struct Undoable: Equatable {
        let entryId: Int
        let message: String
        let id = UUID()
    }

    init(client: APIClient) {
        self.client = client
        let today = PourDate.logicalDay(Date(), in: .current)
        self.today = today
        shownDay = today
        outbox = Self.loadOutbox()
    }

    static func launch() -> AppModel {
        let arguments = ProcessInfo.processInfo.arguments
        let model = AppModel(client: ServerConfiguration.client(arguments: arguments))
        model.start()
        // 开发时对照网页版：-day 2026-10-15 直接打开那一天
        if let index = arguments.firstIndex(of: "-day"), index + 1 < arguments.count {
            model.show(arguments[index + 1])
        }
        return model
    }

    private func start() {
        // 界面测试不排通知（会弹「允许通知」把界面挡住）
        // 对照网页版演示数据时（-serverURL）也不排
        let arguments = ProcessInfo.processInfo.arguments
        remindersOn = !arguments.contains("-uiTest") && !arguments.contains("-serverURL")
        if remindersOn { Reminders.showWhileOpen() }
        network.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in await self?.reconnected() }
        }
        network.start(queue: DispatchQueue(label: "pour.network"))
        listen()
        Task { await refreshAll() }
    }

    /// 回到前台：重新拿一遍（过了日界线就换成新的一天），没发出去的接着发
    func becameActive() {
        Task { await reconnected() }
    }

    private func reconnected() async {
        await refreshAll()
        await flushOutbox()
    }

    // MARK: - 拿数据

    /// 全部重新拿：今天是哪天、类别表、正在看的这一天、对话
    func refreshAll() async {
        do {
            let meta = try await client.meta()
            if meta.today != today {
                let wasToday = shownDay == today
                today = meta.today
                if wasToday { shownDay = meta.today }
            }
            categories = try await client.categories()
            offline = nil
        } catch {
            offline = error.message
            return
        }
        await reloadDay()
        await reloadChat()
    }

    private func reloadDay() async {
        let target = shownDay
        do {
            async let view = client.day(target)
            async let notes = client.notes(ofDay: target)
            let (loadedView, loadedNotes) = try await (view, notes)
            guard target == shownDay else { return }
            day = loadedView
            dayNotes = loadedNotes
            offline = nil
            noteReminders(loadedView)
        } catch let error as APIError {
            offline = error.message
        } catch {
            offline = APIError.unreachable.message
        }
    }

    private func reloadChat() async {
        do {
            let page = try await client.recentNotes(limit: 30)
            chat = page.notes
            chatHasMore = page.hasMore ?? false
        } catch {
            offline = error.message
        }
    }

    /// 对话往上翻：更早的一页
    func loadEarlierChat() async {
        guard chatHasMore, let first = chat.first else { return }
        if let page = try? await client.recentNotes(limit: 30, before: first.id) {
            chat = page.notes + chat
            chatHasMore = page.hasMore ?? false
        }
    }

    /// 一直听着服务器的推送（网页版 useServerEvents）：变了什么就重新拿什么；断了等一会儿再接
    private func listen() {
        events?.cancel()
        let client = self.client
        events = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    for try await event in client.events() { await self?.handle(event) }
                } catch {}
                try? await Task.sleep(for: .seconds(3))
                await self?.refreshAll()
            }
        }
    }

    /// 每种推送要重新拿哪些（网页版 keysToRefresh）
    private func handle(_ event: ServerEvent) async {
        switch event.type {
        case "notes-changed":
            if !event.statusOnly, let fresh = try? await client.categories() { categories = fresh }
            await reloadDay()
            await reloadChat()
        case "entries-changed":
            if let fresh = try? await client.categories() { categories = fresh }
            await reloadDay()
        case "summary-changed", "goals-changed":
            await reloadDay()
        default:
            break
        }
    }

    /// 换到某一天看（不能看还没到的日子）
    func show(_ target: String) {
        let next = min(target, today)
        guard next != shownDay else { return }
        shownDay = next
        day = nil
        dayNotes = []
        Task { await reloadDay() }
    }

    // MARK: - 说一句

    /// 发出去：原话先存在手机上，马上出现在对话里；交给服务器排队整理
    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        outbox.append(Outbox(clientId: UUID().uuidString, text: text, createdAt: Date()))
        saveOutbox()
        chatOpen = true
        if shownDay != today { show(today) }
        Task { await flushOutbox() }
    }

    /// 把手机上存着的话交给服务器（同一段话带着同一个编号，重发不会记两遍）
    func flushOutbox() async {
        for item in outbox {
            do {
                try await client.send(item.text, clientId: item.clientId)
                outbox.removeAll { $0.clientId == item.clientId }
                offline = nil
            } catch {
                if let index = outbox.firstIndex(where: { $0.clientId == item.clientId }) {
                    outbox[index].failed = error.message
                }
            }
            saveOutbox()
        }
        await reloadChat()
        await reloadDay()
    }

    private static let outboxKey = "pour.outbox"

    private static func loadOutbox() -> [Outbox] {
        guard let data = UserDefaults.standard.data(forKey: outboxKey) else { return [] }
        return (try? JSONDecoder().decode([Outbox].self, from: data)) ?? []
    }

    private func saveOutbox() {
        UserDefaults.standard.set(try? JSONEncoder().encode(outbox), forKey: Self.outboxKey)
    }

    // MARK: - 改

    /// 对话里收据后面的「撤销」：这段话整理出的记录都撤掉，原话留着
    func undo(note id: Int) { act { client in try await client.undo(note: id) } }

    /// 没整理成的，点「重试」
    func retry(note id: Int) { act { client in try await client.retry(note: id) } }

    func confirm(_ entryId: Int) { act { client in try await client.confirm(entry: entryId) } }

    func setDone(_ entryId: Int, _ done: Bool) { act { client in try await client.setDone(entry: entryId, done) } }

    /// 详情里原地改（字段名照网页版：label、start、duration_min、metrics……）
    func update(_ entryId: Int, _ fields: [String: JSONValue]) {
        act { client in try await client.update(entry: entryId, fields: fields) }
    }

    func delete(_ entryId: Int) {
        detail = nil
        act { client in try await client.delete(entry: entryId) }
        undoable = Undoable(entryId: entryId, message: "已删除")
        undoTimer?.cancel()
        undoTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.undoable = nil
        }
    }

    /// 轻提示上的「撤销」：删掉的放回来
    func undo() {
        guard let undo = undoable else { return }
        undoable = nil
        undoTimer?.cancel()
        act { client in try await client.restore(entry: undo.entryId) }
    }

    /// 做一件事，做完重新拿这一天（服务器的推送也会来，这里不等它）
    private func act(_ work: @escaping @Sendable (APIClient) async throws -> Void) {
        let client = self.client
        Task {
            do {
                try await work(client)
            } catch let error as APIError {
                offline = error.message
            } catch {
                offline = APIError.unreachable.message
            }
            await reloadDay()
            await reloadChat()
        }
    }

    // MARK: - 提醒

    /// 看到的待办里要提醒的，手机自己排系统通知
    private func noteReminders(_ view: API.DayView) {
        guard remindersOn else { return }
        reminders[view.day] = view.entries.compactMap { entry in
            guard case .todo(let todo) = entry.data, !todo.done, let time = todo.remindAt else { return nil }
            return Reminder(id: String(entry.id), content: todo.content, time: time)
        }
        let all = reminders.values.flatMap { $0 }
        Task { await Reminders.sync(all) }
    }
}

/// 服务器在哪：界面测试用假服务器（-uiTest）；启动参数 -serverURL 可以临时指定（对照网页版演示数据时用）；
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
