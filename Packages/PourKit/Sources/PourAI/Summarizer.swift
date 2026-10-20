import CryptoKit
public import Foundation
public import PourCore
public import PourData

/// 「今天」日子头下面的一句话总结（照服务器 server/src/ai/summary.ts）：
/// - 记录变了才重新生成：按这一天能说的记录（不算待办、待确认的）算一个指纹，指纹没变就用缓存
/// - 防抖：连着说了好几句，等最后一次变化 15 秒后才生成一次；打开某一天时没有总结或者旧了，马上生成
/// - 问不到（网关没开、AI 出错）就不显示，不打扰
public actor Summarizer {
    static let quietPeriod: Duration = .seconds(15)
    static let soon: Duration = .milliseconds(500)

    private let store: PourStore
    private let gateway: GatewayClient
    private var pending: [DayString: Task<Void, Never>] = [:]

    public init(store: PourStore, gateway: GatewayClient) {
        self.store = store
        self.gateway = gateway
    }

    /// 这一天的记录变了：等安静下来再生成
    public func changed(_ day: DayString) {
        schedule(day, after: Self.quietPeriod)
    }

    /// 打开某一天：还没有总结、或者记录已经变了，就尽快生成（已经在排队的不打断）
    public func ensure(_ day: DayString) {
        guard pending[day] == nil, (try? isStale(day)) == true else { return }
        schedule(day, after: Self.soon)
    }

    /// 现在就生成（测试用）；返回是不是真的问了 AI
    @discardableResult
    public func generate(_ day: DayString) async throws -> Bool {
        let records = try worthSaying(day)
        guard !records.isEmpty else {
            try store.removeSummary(of: day)
            return false
        }
        let hash = Self.fingerprint(records)
        if try store.summary(of: day)?.inputHash == hash { return false }
        let text = try await gateway.summarize(day: day, records: records)
        if text.isEmpty {
            try store.removeSummary(of: day)
        } else {
            try store.saveSummary(text, of: day, inputHash: hash)
        }
        return true
    }

    private func schedule(_ day: DayString, after delay: Duration) {
        pending[day]?.cancel()
        pending[day] = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.run(day)
        }
    }

    private func run(_ day: DayString) async {
        pending[day] = nil
        _ = try? await generate(day)
    }

    private func isStale(_ day: DayString) throws -> Bool {
        let records = try worthSaying(day)
        guard !records.isEmpty else { return try store.summary(of: day) != nil }
        return try store.summary(of: day)?.inputHash != Self.fingerprint(records)
    }

    /// 这一天能说的记录：不算待办（还没到做的时候）、不算待确认的（可能不对）
    private func worthSaying(_ day: DayString) throws -> [Entry] {
        try store.snapshot(of: day).entries.filter {
            if case .todo = $0.data { return false }
            return !$0.needsConfirmation
        }
    }

    /// 指纹：这些记录的内容（顺序固定），内容一样指纹就一样
    static func fingerprint(_ records: [Entry]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let parts = records.map { record -> String in
            let data = (try? encoder.encode(record.data)).flatMap { String(bytes: $0, encoding: .utf8) } ?? ""
            return "\(record.day)|\(data)"
        }
        let digest = SHA256.hash(data: Data(parts.joined(separator: "\n").utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

extension GatewayClient {
    /// 问网关要这一天的一句话总结；没有可说的回空字符串
    public func summarize(day: DayString, records: [Entry]) async throws(GatewayError) -> String {
        struct Request: Encodable {
            let version: Int
            let day: DayString
            let records: [BackgroundPackage.Existing]
        }
        struct Response: Decodable { let summary: String }
        let body = Request(
            version: BackgroundPackage.contractVersion, day: day,
            records: records.map { .init(id: $0.id, day: $0.day, data: $0.data, question: $0.question) })
        let data = try await post("v1/summary", body: body, timeout: 60)
        do {
            return try JSONDecoder().decode(Response.self, from: data).summary
        } catch {
            throw .invalidResponse("总结看不懂：\(error.localizedDescription)")
        }
    }
}
