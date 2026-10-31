import Foundation
import Network
import Observation
import PourAPI
import PourCore
import PourPlatform

/// App 的状态（产品主人 2026-10-19 选 B）：数据、业务规则和 AI 全在 Pour 服务器上，手机读写它的接口。
/// 说一句：原话先存在手机上（没网也不丢）→ 交给服务器 → 服务器整理完推过来「变了」→ 手机重新拿这一天
@MainActor
@Observable
final class AppModel {
    let client: APIClient
    /// 健康 App（docs/模块/产品优化.md R5）：接上没有、读了送到电脑上的 Pour
    let health: HealthLink
    /// 日历（R6）：接上没有、看的那天有哪些日程（只在手机上）
    let calendar: CalendarLink

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
    var offline: String?
    /// 电脑上的 Pour 开了 PIN、这台手机还没输过：整个 App 先显示输入 PIN 的那一页
    private(set) var needsPin = false
    /// 还没交给服务器的话：没网时先存在手机上，连上了自动发
    var outbox: [Outbox] = []
    /// 还没交给服务器的写操作（勾待办、改常用……，AppModel+Writes）：界面先改了，没网时排在这里，连上了按顺序发
    var writes: [PendingWrite] = []
    /// 没连上、页面显示的是缓存：存下的时刻（顶上一条细条「没连上 · 显示的是 10:32 的」）；连上了是 nil
    var staleSince: Date?

    var draft = ""
    /// 别处要输入框弹出键盘（时间轴上点空当补记）：加一就弹
    private(set) var composeFocus = 0
    /// 小组件、控制中心的「说一句」（pour://voice）：输入框看到就开始听，听了就清掉
    var voicePending = false
    /// 推进来的页（3.0 外壳，docs/3.0/01-需求文档.md 2.5）：根是生活画布，别的页都推进这一个导航栈，返回一路回到画布
    var stack: [Route] = [] { didSet { sayBarHidden = false } }
    /// 往下翻页面时「说一句」收起，往上翻再出来（docs/3.0/01-需求文档.md 2.2；换一页总是出来）
    var sayBarHidden = false
    /// 别处要画布打开「跳到某一天」（「我的」里的日历格子）：加一就开
    var dayPickerRequest = 0
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
    /// 服务器是在用真实数据（real）还是演示数据（demo，页面顶上有一条横幅）；换了就换日程、刷新小组件（AppModel+Demo）
    private(set) var mode = "real" { didSet { if mode != oldValue { modeChanged() } } }
    /// 电脑上的 Pour 是哪个版本（设置里「这台手机」写着；docs/模块/产品优化.md R8）
    var serverVersion: API.Meta?
    /// 大模型的状态：没连大模型时画布上有「连接大模型」
    private(set) var llm: API.LlmStatus?
    /// 「回顾」列表：早上画布上那一行「昨天的回顾好了 →」看昨天的看过没有
    private(set) var reviews: [API.ReviewItem] = []
    /// 正在生成的回答：一边生成一边推过来，整理完之前在对话里逐字显示
    private(set) var answers: [Int: String] = [:]
    /// 别处改了设置（电脑上、另一台手机）就加一：设置页看到就重新拿
    private(set) var settingsVersion = 0

    private var events: Task<Void, Never>?
    /// 换了数据来源（画布样张开、关）：PourApp 看到它就换一个新的 AppModel
    var replaced = false
    private var noticeTimer: Task<Void, Never>?
    private var noticeAction: (() -> Void)?
    private let network = NWPathMonitor()
    private(set) var remindersOn = false
    /// 看过的日子里要提醒的待办（按日子存，换着看也不丢）
    var reminders: [String: [Reminder]] = [:]

    init(client: APIClient, health: HealthLink, calendar: CalendarLink) {
        self.client = client
        self.health = health
        self.calendar = calendar
        let today = PourDate.logicalDay(Date(), in: .current)
        self.today = today
        shownDay = today
        outbox = OutboxStore.load()
        // 分享扩展、Siri 连不上电脑时存在 App 组里的话：放进待发，连上了一起发（docs/模块/产品优化.md R7）
        for text in SharedStore.takePendingShares() {
            outbox.append(Outbox(clientId: UUID().uuidString, text: text, createdAt: Date()))
        }
        OutboxStore.save(outbox)
        writes = WriteStore.load()
    }

    // MARK: - 拿数据

    /// 全部重新拿：今天是哪天、类别表、正在看的这一天、对话
    func refreshAll() async {
        do {
            let meta = try await client.meta()
            if let problem = serverProblem(meta) {
                offline = problem
                return
            }
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
            await ensureDeviceKey()
            syncHealth()
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

    func reloadDay() async {
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

    func reloadChat() async {
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
            refreshWidgets()
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

    /// 先改界面（写操作队列，AppModel+Writes）：正在看的这一天里的某一条记录
    func patchEntry(_ id: Int, _ change: (inout API.Entry) -> Void) {
        guard var view = day, let index = view.entries.firstIndex(where: { $0.id == id }) else { return }
        change(&view.entries[index])
        day = view
    }

    /// 输入框里先填好一段（「14:00 到 15:30，」），弹出键盘接着说
    func compose(_ text: String) {
        draft = text
        composeFocus += 1
    }

}

// MARK: - 改

extension AppModel {
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
    func act(_ work: @escaping @Sendable (APIClient) async throws -> Void) {
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

// MARK: - 连上、断开

extension AppModel {
    /// 开始连服务器（AppModel+Launch）
    func start() {
        // 页面用了缓存（没连上）、又连上了：顶上的细条跟着出来、收起
        let report: @Sendable (Date?) -> Void = { [weak self] date in
            Task { @MainActor in self?.staleSince = date }
        }
        Task { await client.onStale(report) }
        // 界面测试不排通知（会弹「允许通知」把界面挡住）；对照演示数据时（-serverURL）、看画布样张时也不排
        let arguments = ProcessInfo.processInfo.arguments
        remindersOn = !arguments.contains("-uiTest") && !arguments.contains("-serverURL") && !CanvasSamples.isOn
        if remindersOn { Reminders.showWhileOpen() }
        network.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in await self?.reconnected() }
        }
        network.start(queue: DispatchQueue(label: "pour.network"))
        listen()
        Task { await refreshAll() }
    }

    /// 停掉连接：换数据来源前（PourApp 换 AppModel 时）
    func stop() {
        events?.cancel()
        network.cancel()
    }

    /// 回到前台：重新拿一遍（过了日界线就换成新的一天），没发出去的接着发
    func becameActive() {
        Task { await reconnected() }
    }

    private func reconnected() async {
        await refreshAll()
        await flushOutbox()
        await flushWrites()
    }
}
