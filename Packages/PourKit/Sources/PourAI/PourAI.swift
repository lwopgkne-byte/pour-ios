public import Foundation
public import PourCore

// AI 层：网关客户端、理解服务（M2 起）；问答、端侧语音和向量以后再加（docs/04-AI能力与程序适配方案.md）。
// 接口契约 v2（docs/03 第 8 节）：手机发「背景包」，网关回「改动包」。格式和 gateway/src/contract.ts 一字不差，
// PourAITests 拿网关导出的样例（gateway/contract/example-*.json）核对。v2：带上最近的对话；改、删、之前已记过。
// v3：类别带颜色和顺序；改动包带上这段话新建的类别。
// v4：问了要不要删的那几条（awaitingDelete）记在这段话上、下一句带回去：回答「对」时网关照着删

/// 背景包：整理一段话要用的全部背景，从本机数据库拼出来
public struct BackgroundPackage: Codable, Hashable, Sendable {
    public static let contractVersion = 4

    public struct NotePart: Codable, Hashable, Sendable {
        public var id: String
        public var text: String
        /// 说这句话时手机上的本地钟点（网关不认时区，只用这个）
        public var localTime: LocalDateTime
        public var timeZone: String
        /// 按日界线算的「今天」
        public var day: DayString
    }

    public struct CategoryPart: Codable, Hashable, Sendable {
        public var key: String
        public var name: String
        public var emoji: String
        public var parent: String?
        public var measure: String
        public var synonyms: [String]
        public var color: String
        public var order: Int
    }

    /// 已有的一条记录：AI 判断是不是同一件事、补充哪一条
    public struct Existing: Codable, Hashable, Sendable {
        public var id: String
        public var day: DayString
        public var data: RecordData
        public var question: String?
    }

    /// 最近的一段对话：回答「是的」「刚才那个」时，AI 才知道指的是哪条
    public struct Turn: Codable, Hashable, Sendable {
        public struct Action: Codable, Hashable, Sendable {
            public var action: NoteAction.Kind
            public var recordId: String
            /// 那条记录现在的样子（一句话）
            public var text: String
        }

        public var text: String
        public var localTime: LocalDateTime
        /// done 整理好了、pending 还没整理、failed 没整理成
        public var status: String
        public var actions: [Action]
        public var reply: String?
        public var questions: [String]
        public var undone: Bool
        /// 这段话问了要不要删、还在等回答的那几条
        public var awaitingDelete: [String]
    }

    public var version: Int
    public var note: NotePart
    public var dayBoundary: Int
    public var categories: [CategoryPart]
    public var existing: [Existing]
    public var dialogue: [Turn]

    public init(
        note: Note, categories: [LifeCategory], existing: [Entry], dialogue: [Turn] = [],
        dayBoundary: Int = PourDate.defaultBoundary
    ) {
        version = Self.contractVersion
        self.note = NotePart(
            id: note.id, text: note.text, localTime: note.localTime, timeZone: note.timeZone, day: note.day)
        self.dayBoundary = dayBoundary
        self.categories = categories.map {
            CategoryPart(
                key: $0.key, name: $0.name, emoji: $0.emoji, parent: $0.parent, measure: $0.measure,
                synonyms: $0.synonyms, color: $0.color, order: $0.order)
        }
        self.existing = existing.map { Existing(id: $0.id, day: $0.day, data: $0.data, question: $0.question) }
        self.dialogue = dialogue
    }
}

/// 改动包：理解一段话的全部结果，手机在一个事务里整体写入
public struct ChangePackage: Codable, Hashable, Sendable {
    public struct Step: Codable, Hashable, Sendable {
        public var step: String
        public var skill: String?
        public var skillVersion: String?
        public var durationMs: Double
        public var promptTokens: Int?
        public var cacheHitTokens: Int?
        public var completionTokens: Int?
        public var error: String?
    }

    public var version: Int
    public var noteId: String
    /// 记录、提问、目标、纠正、聊天
    public var intents: [String]
    public var creates: [NewEntry]
    public var updates: [NoteChanges.Updated]
    public var deletes: [NoteChanges.Mention]
    public var duplicates: [NoteChanges.Mention]
    /// 要问你的话（拿不准删哪条时先问）
    public var questions: [String]
    /// 问了要不要删的那几条
    public var awaitingDelete: [String]
    /// 这段话新建的类别（生活领域、新活动）
    public var newCategories: [LifeCategory]
    /// 给你的一句话（聊天的回应）
    public var reply: String
    public var steps: [Step]

    /// 写进数据库的样子
    public var changes: NoteChanges {
        NoteChanges(
            creates: creates, updates: updates, deletes: deletes, duplicates: duplicates, questions: questions,
            awaitingDelete: awaitingDelete, reply: reply, newCategories: newCategories)
    }
}

/// 网关出了什么事
public enum GatewayError: Error, Hashable, Sendable {
    /// 连不上：没网，或者网关没开
    case unreachable
    /// 等太久没回音
    case timedOut
    /// 网关说的错：code 给程序判断，message 是给人看的一句话，retryable 是过一会儿再试有没有用
    case server(code: String, message: String, retryable: Bool)
    /// 回来的东西看不懂（版本对不上之类）
    case invalidResponse(String)
}

/// 网关的状态（设置里看：连没连上、用哪个模型、密钥能不能用；密钥本身永远不出现）
public struct GatewayHealth: Hashable, Sendable {
    public var reachable: Bool
    public var model: String?
    /// set 填了、missing 没填、valid 能用、invalid 不对、unchecked 没查成
    public var key: String?
    public var problem: String?
}

/// 网关的客户端：背景包进、改动包出
public struct GatewayClient: Sendable {
    /// 网关在哪、带什么令牌：每次发请求时现取（真机配对完、改了地址马上生效）
    public struct Endpoint: Sendable {
        public var baseURL: URL
        /// 真机配对换来的令牌（存在手机的钥匙串里）；模拟器连本机不用
        public var token: String?

        public init(baseURL: URL, token: String? = nil) {
            self.baseURL = baseURL
            self.token = token
        }
    }

    let endpoint: @Sendable () -> Endpoint
    var session: URLSession

    public init(baseURL: URL, devToken: String? = nil, session: URLSession = .shared) {
        endpoint = { Endpoint(baseURL: baseURL, token: devToken) }
        self.session = session
    }

    public init(session: URLSession = .shared, endpoint: @escaping @Sendable () -> Endpoint) {
        self.endpoint = endpoint
        self.session = session
    }

    public var baseURL: URL { endpoint().baseURL }

    /// 用网关显示的 6 位配对码换一个令牌（真机第一次连这台 Mac）
    public func pair(code: String, device: String) async throws(GatewayError) -> String {
        struct Request: Encodable {
            let code: String
            let device: String
        }
        struct Response: Decodable { let token: String }
        let data = try await post("v1/pair", body: Request(code: code, device: device), timeout: 15)
        do {
            return try JSONDecoder().decode(Response.self, from: data).token
        } catch {
            throw .invalidResponse("配对的回复看不懂：\(error.localizedDescription)")
        }
    }

    /// 问一下网关在不在；deep 时网关真的问大模型一句，看密钥能不能用
    public func health(deep: Bool = false) async -> GatewayHealth {
        let endpoint = self.endpoint()
        var components = URLComponents(
            url: endpoint.baseURL.appendingPathComponent("health"), resolvingAgainstBaseURL: false)
        if deep { components?.queryItems = [URLQueryItem(name: "deep", value: "1")] }
        guard let url = components?.url else { return GatewayHealth(reachable: false) }
        var request = URLRequest(url: url)
        request.timeoutInterval = deep ? 30 : 5
        if let token = endpoint.token { request.setValue("Bearer \(token)", forHTTPHeaderField: "authorization") }
        struct Body: Decodable {
            let model: String?
            let key: String?
            let problem: String?
        }
        guard let (data, _) = try? await session.data(for: request),
            let body = try? JSONDecoder().decode(Body.self, from: data)
        else { return GatewayHealth(reachable: false) }
        return GatewayHealth(reachable: true, model: body.model, key: body.key, problem: body.problem)
    }

    public func understand(_ background: BackgroundPackage) async throws(GatewayError) -> ChangePackage {
        // 网关等大模型最多 90 秒，这里多给一点
        let data = try await post("v1/understand", body: background, timeout: 100)
        let change: ChangePackage
        do {
            change = try JSONDecoder().decode(ChangePackage.self, from: data)
        } catch {
            throw .invalidResponse("改动包看不懂：\(error.localizedDescription)")
        }
        guard change.version == BackgroundPackage.contractVersion else {
            throw .invalidResponse("网关的接口版本是 \(change.version)，手机是 \(BackgroundPackage.contractVersion)")
        }
        return change
    }

    /// 发一个请求：带上开发令牌；连不上、超时、网关说的错都翻成 GatewayError
    func post(_ path: String, body: some Encodable, timeout: TimeInterval) async throws(GatewayError) -> Data {
        let endpoint = self.endpoint()
        var request = URLRequest(url: endpoint.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        if let token = endpoint.token { request.setValue("Bearer \(token)", forHTTPHeaderField: "authorization") }
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw .invalidResponse("请求写不出来：\(error.localizedDescription)")
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw .timedOut
        } catch {
            throw .unreachable
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            if let body = try? JSONDecoder().decode(GatewayProblem.self, from: data) {
                throw .server(code: body.error.code, message: body.error.message, retryable: body.error.retryable)
            }
            throw .server(code: "http_\(status)", message: "网关出错了（\(status)）。", retryable: status >= 500)
        }
        return data
    }
}

/// 网关出错时回的样子：{ error: { code, message, retryable } }
private struct GatewayProblem: Decodable {
    struct Problem: Decodable {
        let code: String
        let message: String
        let retryable: Bool
    }

    let error: Problem
}
