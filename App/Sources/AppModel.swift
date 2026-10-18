import Foundation
import Network
import Observation
import PourAI
import PourCore
import PourData

/// App 的状态：本机数据库、理解服务、今天是哪一天、「今天」页看到的样子（M2a）。
/// 说一句话的流程：原话马上存进本机数据库、出现在「今天」→ 理解服务排队问网关 → 改动包写回来 → 收据凝结
@MainActor
@Observable
final class AppModel {
    enum Tab: Hashable { case today, review, about, money, search }

    let store: PourStore
    let organizer: Organizer
    let gateway: GatewayClient

    /// 按日界线算的今天
    private(set) var today: DayString
    /// 「今天」页看到的样子：一直观察着数据库
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

    private var observation: Task<Void, Never>?
    private let network = NWPathMonitor()

    init(store: PourStore, gateway: GatewayClient) {
        self.store = store
        self.gateway = gateway
        organizer = Organizer(store: store, gateway: gateway)
        let today = PourDate.logicalDay(Date(), in: .current)
        self.today = today
        day = DaySnapshot(day: today)
    }

    /// 打开 App：正式的数据库、配置里的网关。界面测试用内存里的数据库、假网关（-uiTest）
    static func launch() -> AppModel {
        let arguments = ProcessInfo.processInfo.arguments
        let gateway = GatewayConfiguration.client(arguments: arguments)
        let store: PourStore
        var problem: String?
        do {
            store = arguments.contains("-uiTest") ? try PourStore.inMemory() : try PourStore.openDefault()
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
        observeToday()
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
            today = now
            observeToday()
        }
        Task { await organizer.kick() }
    }

    private func observeToday() {
        observation?.cancel()
        let stream = store.observe(day: today)
        observation = Task { [weak self] in
            do {
                for try await snapshot in stream { self?.day = snapshot }
            } catch {
                Log.error("观察今天的数据出错：\(error.localizedDescription)")
            }
        }
    }

    // MARK: - 说一句

    /// 发出去：原话马上存下（100 毫秒内出现在「今天」），收起键盘，回到「今天」，排队整理
    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            let note = try store.addNote(text)
            watching.insert(note.id)
            lastSent = note.id
            draft = ""
            composing = false
            tab = .today
            if note.day != today {
                today = note.day
                observeToday()
            }
            Task { await organizer.kick() }
        } catch {
            problem = "这段话没存下：\(error.localizedDescription)"
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
/// 平时用 Info.plist 的 PourGatewayURL（Config/Base.xcconfig 的 POUR_GATEWAY_URL）。
/// 模拟器直接连这台 Mac 上的网关（127.0.0.1:5480）；真机要连 Mac 的局域网地址（M2a 之后接上）
enum GatewayConfiguration {
    static let fallback = "http://127.0.0.1:5480"

    static func url(arguments: [String]) -> URL {
        if let index = arguments.firstIndex(of: "-gatewayURL"), index + 1 < arguments.count,
            let url = URL(string: arguments[index + 1])
        {
            return url
        }
        let configured = Bundle.main.object(forInfoDictionaryKey: "PourGatewayURL") as? String ?? ""
        return URL(string: configured.isEmpty ? fallback : configured) ?? URL(fileURLWithPath: "/")
    }

    static func client(arguments: [String]) -> GatewayClient {
        #if DEBUG
            if arguments.contains("-uiTest") { return StubGateway.client() }
        #endif
        return GatewayClient(baseURL: url(arguments: arguments))
    }
}
