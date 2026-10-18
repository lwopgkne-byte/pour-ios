public import Foundation
public import PourCore

// AI 层：网关客户端、理解服务（M2 起）；问答、端侧语音和向量以后再加（docs/04-AI能力与程序适配方案.md）。
// 接口契约 v1（docs/03 第 8 节）：手机发「背景包」，网关回「改动包」。格式和 gateway/src/contract.ts 一字不差，
// PourAITests 拿网关导出的样例（gateway/contract/example-*.json）核对

/// 背景包：整理一段话要用的全部背景，从本机数据库拼出来
public struct BackgroundPackage: Codable, Hashable, Sendable {
    public static let contractVersion = 1

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
    }

    /// 已有的一条记录：AI 判断是不是同一件事、补充哪一条
    public struct Existing: Codable, Hashable, Sendable {
        public var id: String
        public var day: DayString
        public var data: RecordData
        public var question: String?
    }

    public var version: Int
    public var note: NotePart
    public var dayBoundary: Int
    public var categories: [CategoryPart]
    public var existing: [Existing]

    public init(note: Note, categories: [LifeCategory], existing: [Entry], dayBoundary: Int = PourDate.defaultBoundary)
    {
        version = Self.contractVersion
        self.note = NotePart(
            id: note.id, text: note.text, localTime: note.localTime, timeZone: note.timeZone, day: note.day)
        self.dayBoundary = dayBoundary
        self.categories = categories.map {
            CategoryPart(
                key: $0.key, name: $0.name, emoji: $0.emoji, parent: $0.parent, measure: $0.measure,
                synonyms: $0.synonyms)
        }
        self.existing = existing.map { Existing(id: $0.id, day: $0.day, data: $0.data, question: $0.question) }
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
    /// 给你的一句话（聊天的回应）
    public var reply: String
    public var steps: [Step]
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
    public var baseURL: URL
    /// 局域网里的网关要开发令牌（上架前换成设备证明）
    public var devToken: String?
    var session: URLSession

    public init(baseURL: URL, devToken: String? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.devToken = devToken
        self.session = session
    }

    /// 问一下网关在不在；deep 时网关真的问大模型一句，看密钥能不能用
    public func health(deep: Bool = false) async -> GatewayHealth {
        var components = URLComponents(url: baseURL.appendingPathComponent("health"), resolvingAgainstBaseURL: false)
        if deep { components?.queryItems = [URLQueryItem(name: "deep", value: "1")] }
        guard let url = components?.url else { return GatewayHealth(reachable: false) }
        var request = URLRequest(url: url)
        request.timeoutInterval = deep ? 30 : 5
        if let devToken { request.setValue("Bearer \(devToken)", forHTTPHeaderField: "authorization") }
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
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/understand"))
        request.httpMethod = "POST"
        // 网关等大模型最多 90 秒，这里多给一点
        request.timeoutInterval = 100
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        if let devToken { request.setValue("Bearer \(devToken)", forHTTPHeaderField: "authorization") }
        do {
            request.httpBody = try JSONEncoder().encode(background)
        } catch {
            throw .invalidResponse("背景包写不出来：\(error.localizedDescription)")
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
            struct Body: Decodable {
                struct Problem: Decodable {
                    let code: String
                    let message: String
                    let retryable: Bool
                }
                let error: Problem
            }
            if let body = try? JSONDecoder().decode(Body.self, from: data) {
                throw .server(code: body.error.code, message: body.error.message, retryable: body.error.retryable)
            }
            throw .server(code: "http_\(status)", message: "网关出错了（\(status)）。", retryable: status >= 500)
        }
        do {
            let change = try JSONDecoder().decode(ChangePackage.self, from: data)
            guard change.version == BackgroundPackage.contractVersion else {
                throw GatewayError.invalidResponse(
                    "网关的接口版本是 \(change.version)，手机是 \(BackgroundPackage.contractVersion)")
            }
            return change
        } catch let error as GatewayError {
            throw error
        } catch {
            throw .invalidResponse("改动包看不懂：\(error.localizedDescription)")
        }
    }
}
