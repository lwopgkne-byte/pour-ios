import Foundation
import Network
import Observation
import PourAI
import PourCore
import PourData
import PourPlatform

/// App 的状态：本机数据库、理解服务、今天是哪一天、「今天」页看到的样子（M2a）。
/// 说一句话的流程：原话马上存进本机数据库、出现在「今天」→ 理解服务排队问网关 → 改动包写回来 → 收据凝结
@MainActor
@Observable
final class AppModel {
    enum Tab: Hashable { case today, review, about, money, search }

    let store: PourStore
    let organizer: Organizer
    let summarizer: Summarizer
    let gateway: GatewayClient

    /// 按日界线算的今天
    private(set) var today: DayString
    /// 「今天」页正在看哪一天（左右滑换日子）
    private(set) var shownDay: DayString
    /// 正在看的那一天的样子：一直观察着数据库
    private(set) var day: DaySnapshot
    /// 这次打开 App 以后说的、看着它整理的原话：整理好时收据逐张凝结
    private(set) var watching: Set<String> = []
    /// 刚发出去的那段话：「今天」页滚到它
    private(set) var lastSent: String?
    /// 打不开数据库、存不下这类大事（平时是 nil）
    private(set) var problem: String?

    var tab: Tab = .today
    var composing = false
    var draft = ""
    /// 对话面板开着没有（网页版 Composer：发出去就向上展开）
    var chatOpen = false
    /// 对话面板里的样子：最近说过的话（不分哪天）
    private(set) var chat = ChatSnapshot()
    private var chatObservation: Task<Void, Never>?
    /// 打开详情的那条记录
    var detail: EntryRef?
    /// 底部的撤销条（5 秒后自己消失）
    private(set) var undoable: Undoable?

    /// 能撤销的一次改动：一段话整理出的全部改动，或者详情里删掉的一条
    struct Undoable: Equatable {
        enum Target: Equatable {
            case note(String)
            case deletedEntry(String)
        }

        let target: Target
        let message: String
        let id = UUID()
    }

    /// 打开详情的记录（sheet 认它）
    struct EntryRef: Identifiable, Hashable {
        let id: String
    }

    private var observation: Task<Void, Never>?
    private var undoTimer: Task<Void, Never>?
    /// 撤销条留多久（规范 12：5 秒）
    static let undoWindow: Duration = .seconds(5)
    private let network = NWPathMonitor()
    /// 排不排待办的提醒（界面测试不排）
    private var remindersOn = false

    init(store: PourStore, gateway: GatewayClient) {
        self.store = store
        self.gateway = gateway
        organizer = Organizer(store: store, gateway: gateway)
        summarizer = Summarizer(store: store, gateway: gateway)
        let today = PourDate.logicalDay(Date(), in: .current)
        self.today = today
        shownDay = today
        day = DaySnapshot(day: today)
    }

    /// 打开 App：正式的数据库、配置里的网关。界面测试用内存里的数据库、假网关（-uiTest）
    static func launch() -> AppModel {
        let arguments = ProcessInfo.processInfo.arguments
        let gateway = GatewayConfiguration.client(arguments: arguments)
        let store: PourStore
        var problem: String?
        do {
            // -uiTest、-freshStore：从空的开始（内存里，关掉就没了）
            let fresh = arguments.contains("-uiTest") || arguments.contains("-freshStore")
            store = fresh ? try PourStore.inMemory() : try PourStore.openDefault()
        } catch {
            // 数据库打不开：先用内存里的让你能看，告诉你出了什么事
            Log.error("数据库打不开：\(error.localizedDescription)")
            problem = "本机数据库打不开：\(error.localizedDescription)。这次说的话不会保存。"
            do { store = try PourStore.inMemory() } catch { fatalError("连内存里的数据库都开不了：\(error)") }
        }
        let model = AppModel(store: store, gateway: gateway)
        model.problem = problem
        model.start()
        return model
    }

    private func start() {
        try? store.recoverInterrupted()
        // 界面测试不排通知（会弹「允许通知」把界面挡住）
        remindersOn = !ProcessInfo.processInfo.arguments.contains("-uiTest")
        if remindersOn { Reminders.showWhileOpen() }
        syncReminders()
        observeToday()
        observeChat()
        let organizer = self.organizer
        network.pathUpdateHandler = { path in
            guard path.status == .satisfied else { return }
            Task { await organizer.networkCameBack() }
        }
        network.start(queue: DispatchQueue(label: "pour.network"))
        Task { await organizer.kick() }
    }

    /// 回到前台：过了日界线就换成新的一天；有排着队的原话就接着整理
    func becameActive() {
        let now = PourDate.logicalDay(Date(), in: .current)
        if now != today {
            // 过了日界线：还在看「今天」的就跟着换成新的今天
            let wasToday = shownDay == today
            today = now
            if wasToday { shownDay = now }
            observeToday()
        }
        syncReminders()
        Task { await organizer.kick() }
    }

    /// 照数据库重排待办的提醒（记录一变就排：新的排上、改了的跟着改、做完删掉的撤掉）
    private func syncReminders() {
        guard remindersOn else { return }
        let items = (try? store.reminders()) ?? []
        Task { await Reminders.sync(items) }
    }

    private func observeChat() {
        chatObservation?.cancel()
        let stream = store.observeChat()
        chatObservation = Task { [weak self] in
            do {
                for try await snapshot in stream { self?.chat = snapshot }
            } catch {
                Log.error("观察对话出错：\(error.localizedDescription)")
            }
        }
    }

    /// 对话里收据后面的「撤销」：撤掉这段话整理出的全部记录，原话留着
    func undo(note noteId: String) {
        try? store.undo(noteId)
    }

    /// 待办打勾、取消打勾
    func setDone(_ entryId: String, _ done: Bool) {
        try? store.setDone(entryId, done)
    }

    /// 换到某一天看（不能看还没到的日子）
    func show(_ target: DayString) {
        let day = min(target, today)
        guard day != shownDay else { return }
        shownDay = day
        observeToday()
    }

    private func observeToday() {
        observation?.cancel()
        let shown = shownDay
        let summarizer = self.summarizer
        Task { await summarizer.ensure(shown) }
        let stream = store.observe(day: shown)
        observation = Task { [weak self] in
            do {
                for try await snapshot in stream { self?.receive(snapshot) }
            } catch {
                Log.error("观察今天的数据出错：\(error.localizedDescription)")
            }
        }
    }

    /// 新的一天的样子：记录变了就重排提醒、等安静下来重新总结
    private func receive(_ snapshot: DaySnapshot) {
        let sameDay = day.day == snapshot.day
        let recordsChanged = sameDay && day.entries != snapshot.entries
        day = snapshot
        if recordsChanged { syncReminders() }
        // 记录变了：等安静下来重新总结（连着说好几句只总结一次）
        if recordsChanged {
            let summarizer = self.summarizer
            let changed = snapshot.day
            Task { await summarizer.changed(changed) }
        }
        // 整理好以后不弹撤销条：撤销在对话里收据的后面（网页版就是这样）；删掉一条时才有轻提示
    }

    private func show(_ undo: Undoable) {
        undoable = undo
        undoTimer?.cancel()
        undoTimer = Task { [weak self] in
            try? await Task.sleep(for: Self.undoWindow)
            guard !Task.isCancelled else { return }
            self?.undoable = nil
        }
    }

    /// 点撤销条上的「撤销」
    func undo() {
        guard let undo = undoable else { return }
        undoable = nil
        undoTimer?.cancel()
        switch undo.target {
        case .note(let id): try? store.undo(id)
        case .deletedEntry(let id): try? store.restore(id)
        }
    }

    // MARK: - 详情里改

    func confirm(_ entryId: String) {
        try? store.confirm(entryId)
    }

    func delete(_ entryId: String) {
        try? store.delete(entryId)
        detail = nil
        show(Undoable(target: .deletedEntry(entryId), message: "已删掉 1 件事"))
    }

    // MARK: - 说一句

    /// 点追问的选项：当作说了这一句（打了一半的草稿留着）
    func answer(_ text: String) {
        say(text)
    }

    /// 发出去：原话马上存下（100 毫秒内出现在「今天」），收起键盘，回到「今天」，排队整理
    func send() {
        if say(draft) { draft = "" }
    }

    @discardableResult
    private func say(_ raw: String) -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        do {
            let note = try store.addNote(text)
            watching.insert(note.id)
            lastSent = note.id
            composing = false
            chatOpen = true
            tab = .today
            // 说的话都在「今天」凝结：在看别的日子就回到今天
            if note.day != today { today = note.day }
            if shownDay != note.day {
                shownDay = note.day
                observeToday()
            }
            Task { await organizer.kick() }
            return true
        } catch {
            problem = "这段话没存下：\(error.localizedDescription)"
            return false
        }
    }

    /// 没整理成的，点「再试一次」
    func retry(_ noteId: String) {
        watching.insert(noteId)
        try? store.retry(noteId)
        Task { await organizer.kick() }
    }
}

/// 网关在哪：界面测试用假网关（-uiTest）；启动参数 -gatewayURL 可以临时指定；
/// 真机配对时改过的地址和换来的令牌在钥匙串里；都没有就用 Info.plist 的 PourGatewayURL
/// （Config/Base.xcconfig 的 POUR_GATEWAY_URL；装到手机时 install-device.sh 换成这台 Mac 在局域网里的名字）。
/// 模拟器直接连这台 Mac 上的网关（127.0.0.1:5480），不用配对
enum GatewayConfiguration {
    static let fallback = "http://127.0.0.1:5480"
    static let addressKey = "gateway.address"
    static let tokenKey = "gateway.token"

    /// 安装时写进 App 的地址
    static var builtIn: URL {
        let configured = Bundle.main.object(forInfoDictionaryKey: "PourGatewayURL") as? String ?? ""
        return URL(string: configured.isEmpty ? fallback : configured) ?? URL(fileURLWithPath: "/")
    }

    /// 现在用的地址：配对时改过的优先
    static var address: URL { Keychain.read(addressKey).flatMap(URL.init(string:)) ?? builtIn }

    static var isPaired: Bool { Keychain.read(tokenKey) != nil }

    static func client(arguments: [String]) -> GatewayClient {
        #if DEBUG
            if arguments.contains("-uiTest") { return StubGateway.client() }
        #endif
        if let index = arguments.firstIndex(of: "-gatewayURL"), index + 1 < arguments.count,
            let url = URL(string: arguments[index + 1])
        {
            return GatewayClient(baseURL: url)
        }
        return GatewayClient { .init(baseURL: address, token: Keychain.read(tokenKey)) }
    }

    /// 配对成功：记下地址和令牌
    static func remember(address: URL, token: String) {
        Keychain.save(address.absoluteString, for: addressKey)
        Keychain.save(token, for: tokenKey)
    }
}
