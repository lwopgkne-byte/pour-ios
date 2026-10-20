public import Foundation
public import PourCore
public import PourData

/// 理解服务：一段一段地整理原话（docs/归档/03 第 5.1 节）。
/// 原话先存进本机数据库、马上出现在「今天」；这里按先后排队，拼背景包 → 问网关 → 改动包在一个事务里写回去。
/// 连不上就等网络，AI 一时没回应就过一会儿再试；说不清的错误留给你点「再试一次」
public actor Organizer {
    /// 连不上时多久再试：越试越久，最长一分钟（一联网会马上再试，不等这个）
    static func backoff(attempt: Int) -> TimeInterval { min(60, 5 * pow(2, Double(max(0, attempt - 1)))) }
    /// AI 一时没回应：最多自动再试几次，之后等你点「再试一次」
    static let automaticRetries = 2

    private let store: PourStore
    private let gateway: GatewayClient
    private let now: @Sendable () -> Date
    private var running = false
    private var kickedWhileRunning = false
    private var wakeUp: Task<Void, Never>?

    public init(store: PourStore, gateway: GatewayClient, now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.gateway = gateway
        self.now = now
    }

    /// 有新原话、联网了、App 回到前台：叫一声，排着队的都整理掉
    public func kick() {
        if running {
            kickedWhileRunning = true
            return
        }
        running = true
        Task { await drain() }
    }

    /// 一联网：等网络的原话马上再试
    public func networkCameBack() {
        try? store.retryWaitingNow()
        kick()
    }

    /// 整理完排着的全部原话；测试里等它做完
    public func drain() async {
        running = true
        repeat {
            kickedWhileRunning = false
            while let note = try? store.nextNoteToOrganize(now: now()) {
                await organize(note)
            }
        } while kickedWhileRunning
        running = false
        scheduleWakeUp()
    }

    private func organize(_ note: Note) async {
        do {
            try store.markOrganizing(note.id)
            let categories = try store.categories()
            let background = BackgroundPackage(
                note: note, categories: categories, existing: try store.existingEntries(around: note.day),
                dialogue: try dialogue(before: note, categories: categories))
            let change = try await gateway.understand(background)
            let package = try JSONEncoder().encode(change)
            try store.apply(change.changes, toNote: note.id, package: package, at: now())
        } catch let error as GatewayError {
            handle(error, note: note)
        } catch {
            try? store.markFailed(note.id, problem: "没整理成：\(error.localizedDescription)")
        }
    }

    private func handle(_ error: GatewayError, note: Note) {
        let attempt = (try? store.attempts(of: note.id)) ?? 1
        switch error {
        case .unreachable, .timedOut:
            try? store.markWaitingForNetwork(note.id, retryAt: now().addingTimeInterval(Self.backoff(attempt: attempt)))
        case .server(_, _, retryable: true) where attempt <= Self.automaticRetries:
            try? store.requeue(note.id, retryAt: now().addingTimeInterval(Self.backoff(attempt: attempt)))
        case .server(_, let message, retryable: true):
            try? store.markFailed(note.id, problem: "没整理成：AI 这次没有回应。\(message)")
        case .server(_, let message, retryable: false):
            try? store.markFailed(note.id, problem: "没整理成：\(message)")
        case .invalidResponse(let detail):
            try? store.markFailed(note.id, problem: "没整理成：\(detail)")
        }
    }

    /// 这段话之前的几段对话：说了什么、记下改了删了哪几条（那条记录现在的一句话）、回了什么、还在问什么
    private func dialogue(before note: Note, categories: [LifeCategory]) throws -> [BackgroundPackage.Turn] {
        let (notes, mentioned) = try store.recentTurns(before: note)
        return notes.map { said in
            let actions = said.actions.compactMap { action -> BackgroundPackage.Turn.Action? in
                guard let entry = mentioned[action.entryId] else { return nil }
                let line = RecordLine(entry.data, categories: categories, said: said.localTime, today: said.day)
                let text = [line.title, line.person.map { "和\($0)" }, line.value].compactMap { $0 }.joined(
                    separator: " · ")
                return .init(action: action.kind, recordId: entry.id, text: text)
            }
            // 还在问的：这段话问你的，加上它记下、改过、还没确认的那几条的追问
            let asking = said.actions.compactMap { mentioned[$0.entryId] }.filter { !$0.deleted }.compactMap(\.question)
            let status = said.status == .done ? "done" : said.status == .failed ? "failed" : "pending"
            return .init(
                text: said.text, localTime: said.localTime, status: status, actions: actions, reply: said.reply,
                questions: said.questions + asking, undone: said.undoneAt != nil, awaitingDelete: said.awaitingDelete)
        }
    }

    /// 有原话在等重试：到点叫醒自己
    private func scheduleWakeUp() {
        wakeUp?.cancel()
        guard let date = try? store.nextRetryDate() else { return }
        let delay = max(0.5, date.timeIntervalSince(now()))
        wakeUp = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self?.kick()
        }
    }
}
