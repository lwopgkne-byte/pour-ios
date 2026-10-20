import Foundation
import Network
import Observation
import PourAPI
import PourCore
import PourData
import PourPlatform

/// App 的状态（产品主人 2026-10-19 选 B）：数据、业务规则和 AI 全在 Pour 服务器上，手机读写它的接口。
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
    /// 对话里的系统消息：提醒、预警、每日回顾、周报月报（和原话按时间排在一起）
    private(set) var messages: [API.SystemMessage] = []
    /// 几点算新的一天（分钟；系统消息按它分到哪一天）
    private(set) var dayBoundary = PourDate.defaultBoundary
    private(set) var categories: [API.Category] = []
    /// 没连上服务器时说一句（连上了是 nil）
    private(set) var offline: String?
    /// 电脑上的 Pour 开了 PIN、这台手机还没输过：整个 App 先显示输入 PIN 的那一页
    private(set) var needsPin = false
    /// 还没交给服务器的话：没网时先存在手机上，连上了自动发
    private(set) var outbox: [Outbox] = []

    var draft = ""
    /// 正在看哪一页（左上角菜单换）
    var page: Page = .canvas
    /// 这一页要先打开哪一篇：页面地址（对话里点「昨天的回顾好了」→「/review/2026-10-18」），那一页看完清掉
    var pagePath: String?
    /// 要搜什么（右上角的搜索、「/找 三体」）：不是 nil 就打开搜索
    var search: String?
    /// 对话面板开着没有（发出去就向上展开）
    var chatOpen = false
    /// 打开详情的那条记录
    var detail: EntryRef?
    /// 打开的目标详情（画布上的目标、卡片底下那一行、回顾、目标页，点了都打开它）
    var goalDetail: GoalRef?
    /// 记录、目标变了（整理完一段话、改了记录、改了目标）就加一：目标页、钱、回顾这些页看到就重新拿
    private(set) var dataVersion = 0
    /// 轻提示（「已删除 · 撤销」「密钥已保存」），4 秒后自己消失
    private(set) var notice: Notice?
    /// 服务器是在用真实数据（real）还是演示数据（demo，页面顶上有一条横幅）
    private(set) var mode = "real"
    /// 大模型的状态：没连大模型时画布上有「连接大模型」
    private(set) var llm: API.LlmStatus?
    /// 「回顾」列表：早上画布上那一行「昨天的回顾好了 →」看昨天的看过没有
    private(set) var reviews: [API.ReviewItem] = []
    /// 正在生成的回答：一边生成一边推过来，整理完之前在对话里逐字显示
    private(set) var answers: [Int: String] = [:]
    /// 别处改了设置（电脑上、另一台手机）就加一：设置页看到就重新拿
    private(set) var settingsVersion = 0

    private var events: Task<Void, Never>?
    private var noticeTimer: Task<Void, Never>?
    private var noticeAction: (() -> Void)?
    private let network = NWPathMonitor()
    private(set) var remindersOn = false
    /// 看过的日子里要提醒的待办（按日子存，换着看也不丢）
    var reminders: [String: [Reminder]] = [:]

    init(client: APIClient) {
        self.client = client
        let today = PourDate.logicalDay(Date(), in: .current)
        self.today = today
        shownDay = today
        outbox = OutboxStore.load()
    }

    static func launch() -> AppModel {
        let arguments = ProcessInfo.processInfo.arguments
        // 界面测试每次从头开始：上一个测试没发出去的话不留到这一个
        if arguments.contains("-uiTest") { UserDefaults.standard.removeObject(forKey: OutboxStore.key) }
        let model = AppModel(client: ServerConfiguration.client(arguments: arguments))
        model.start()
        // 开发时对照演示数据：-day 2026-10-15 直接打开那一天
        if let index = arguments.firstIndex(of: "-day"), index + 1 < arguments.count {
            model.show(arguments[index + 1])
        }
        return model
    }

    private func start() {
        // 界面测试不排通知（会弹「允许通知」把界面挡住）
        // 对照演示数据时（-serverURL）也不排
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
            dayBoundary = meta.dayBoundary
            mode = meta.mode ?? "real"
            if meta.today != today {
                let wasToday = shownDay == today
                today = meta.today
                if wasToday { shownDay = meta.today }
            }
            categories = try await client.categories()
            offline = nil
            needsPin = false
        } catch {
            offline = error.message
            needsPin = error == .needPin
            return
        }
        await reloadDay()
        await reloadChat()
        await reloadStatus()
    }

    /// 大模型的状态、回顾列表：拿不到就先留着上次的，不影响说话和看画布
    func reloadStatus() async {
        if let fresh = try? await client.llmStatus() { llm = fresh }
        if let fresh = try? await client.reviewList() { reviews = fresh }
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
            return
        }
        await reloadMessages()
    }

    /// 系统消息：从对话里已经拿到的最早那段话开始；对话的历史都拿完了就要最近的
    private func reloadMessages() async {
        let since = chatHasMore ? chat.first?.createdAt : nil
        // 拿不到就先留着上次的：系统消息不影响说话和看画布
        if let fresh = try? await client.messages(since: since) { messages = fresh }
    }

    /// 对话往上翻：更早的一页
    func loadEarlierChat() async {
        guard chatHasMore, let first = chat.first else { return }
        if let page = try? await client.recentNotes(limit: 30, before: first.id) {
            chat = page.notes + chat
            chatHasMore = page.hasMore ?? false
            await reloadMessages()
        }
    }

    /// 一直听着服务器的推送：变了什么就重新拿什么；断了等一会儿再接
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

    /// 每种推送要重新拿哪些
    private func handle(_ event: ServerEvent) async {
        switch event.type {
        case "notes-changed":
            await notesChanged(statusOnly: event.statusOnly)
        case "entries-changed":
            dataVersion += 1
            if let fresh = try? await client.categories() { categories = fresh }
            await reloadDay()
        case "goals-changed":
            dataVersion += 1
            await reloadDay()
        case "summary-changed":
            await reloadDay()
        case "messages-changed", "settings-changed":
            if event.type == "settings-changed" { settingsVersion += 1 }
            await reloadMessages()
            await reloadStatus()
        case "answer-delta":
            grow(answer: event)
        default:
            break
        }
    }

    /// 原话的状态变了；整理完了（不只是状态）的话记录、类别、目标都可能变了
    private func notesChanged(statusOnly: Bool) async {
        if !statusOnly {
            dataVersion += 1
            if let fresh = try? await client.categories() { categories = fresh }
        }
        await reloadDay()
        await reloadChat()
        // 排队的数量、为什么在排队
        if let fresh = try? await client.llmStatus() { llm = fresh }
    }

    /// 在手机上改了记录、目标：马上让各页重新拿（服务器的推送随后也会来）
    func dataChanged() {
        dataVersion += 1
        Task { await reloadDay() }
    }

    /// 回答又长出来一截（null 是这段回答结束了：清空，整理好的结果里有完整的）
    private func grow(answer event: ServerEvent) {
        guard let noteId = event.noteId else { return }
        answers[noteId] = event.text.map { (answers[noteId] ?? "") + $0 } ?? ""
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

    /// 打开一个页面地址（对话里的回顾、周报月报链接，pour://open?path=…）：换到那一页，收起对话
    func open(_ path: String) {
        if path.hasPrefix("/review") { page = .review }
        if path.hasPrefix("/money") { page = .money }
        if path.hasPrefix("/library") { page = .library }
        if path.hasPrefix("/about") { page = .about }
        if path.hasPrefix("/settings") { page = .settings }
        pagePath = path
        chatOpen = false
    }

}

// MARK: - 改

extension AppModel {
    /// 对话里收据后面的「撤销」：这段话整理出的记录都撤掉，原话留着
    func undo(note id: Int) { act { client in try await client.undo(note: id) } }

    /// 没整理成的，点「重试」
    func retry(note id: Int) { act { client in try await client.retry(note: id) } }

    func confirm(_ entryId: Int) { act { client in try await client.confirm(entry: entryId) } }

    func setDone(_ entryId: Int, _ done: Bool) { act { client in try await client.setDone(entry: entryId, done) } }

    /// 详情里原地改（字段名照服务器：label、start、duration_min、metrics……）
    func update(_ entryId: Int, _ fields: [String: JSONValue]) {
        act { client in try await client.update(entry: entryId, fields: fields) }
    }

    func delete(_ entryId: Int) {
        detail = nil
        act { client in try await client.delete(entry: entryId) }
        // 轻提示上的「撤销」：删掉的放回来
        toast("已删除", action: "撤销") { [weak self] in
            self?.act { client in try await client.restore(entry: entryId) }
        }
    }

    /// 「连接大模型」上的「知道了，开始整理」：同意把原话发给大模型整理
    func acceptConsent() { act { client in try await client.acceptConsent() } }

    /// 「连接大模型」上的「跳过」：不再出现，以后在设置里填
    func dismissSetup() { act { client in try await client.dismissSetup() } }

    /// 说一声：一句话，右边可以有一个操作；4 秒后自己消失，新的顶掉旧的
    func toast(_ message: String, action: String? = nil, perform: (() -> Void)? = nil) {
        notice = Notice(message: message, action: action)
        noticeAction = perform
        noticeTimer?.cancel()
        noticeTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }

    /// 点了轻提示右边的操作
    func performNotice() {
        let action = noticeAction
        notice = nil
        noticeAction = nil
        noticeTimer?.cancel()
        action?()
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
            await reloadStatus()
        }
    }
}

// MARK: - 说一句、提醒

extension AppModel {
    /// 发出去：原话先存在手机上，马上出现在对话里；交给服务器排队整理
    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        // 在手机上直接做的命令（/找 /今天 /周报 /撤销）：不发给 AI
        if let slash = Show.parseSlash(text), slash.command.intent == nil {
            Task { await run(slash.command, slash.rest) }
            return
        }
        outbox.append(Outbox(clientId: UUID().uuidString, text: text, createdAt: Date()))
        OutboxStore.save(outbox)
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
            OutboxStore.save(outbox)
        }
        await reloadChat()
        await reloadDay()
    }

}
