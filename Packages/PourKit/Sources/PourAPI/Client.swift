public import Foundation

/// 服务器出的问题
public enum APIError: Error, Hashable, Sendable {
    /// 没连上：电脑没开、Pour 没在运行、不在同一个 WiFi
    case unreachable
    /// 要先输入 PIN（局域网访问开了 PIN）
    case needPin
    /// 服务器说的错：code 给程序判断，message 是给人看的一句话
    case server(status: Int, code: String, message: String)

    /// 给人看的一句话
    public var message: String {
        switch self {
        case .unreachable: "没连上电脑上的服务。请确认电脑开着、Pour 在运行，并且手机和电脑在同一个 WiFi。"
        case .needPin: "需要输入 PIN。"
        case .server(_, _, let message): message
        }
    }
}

/// 服务器的客户端：所有业务规则和 AI 都在服务器上，手机只读写它的接口
public actor APIClient {
    public let baseURL: URL
    /// 不是 private：下载文件（导出）也用它，带着登录 PIN 以后的 cookie
    let session: URLSession

    public init(baseURL: URL, session: URLSession? = nil) {
        self.baseURL = baseURL
        if let session {
            self.session = session
        } else {
            // 登录 PIN 以后的令牌在 cookie 里：用系统的 cookie 存储，下次打开还在
            let config = URLSessionConfiguration.default
            config.httpCookieStorage = .shared
            config.httpShouldSetCookies = true
            config.timeoutIntervalForRequest = 20
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - 生活画布

    public func meta() async throws(APIError) -> API.Meta { try await get("/api/meta") }
    public func day(_ date: String) async throws(APIError) -> API.DayView { try await get("/api/day/\(date)") }
    public func notes(ofDay date: String) async throws(APIError) -> [API.Note] {
        let page: API.NotesPage = try await get("/api/notes?day=\(date)")
        return page.notes
    }

    /// 最近的几段话（对话面板）：从早到晚；before 是更早的一页
    public func recentNotes(limit: Int = 30, before: Int? = nil) async throws(APIError) -> API.NotesPage {
        try await get("/api/notes?limit=\(limit)\(before.map { "&before=\($0)" } ?? "")")
    }

    public func categories() async throws(APIError) -> [API.Category] {
        let page: API.CategoriesPage = try await get("/api/categories")
        return page.categories
    }

    public func trend(of entryId: Int) async throws(APIError) -> API.Trend {
        try await get("/api/entries/\(entryId)/trend")
    }

    // MARK: - 说一句、改

    /// 说一句：原话交给服务器排队整理；clientId 防重复（同一段话重发不记两遍）。
    /// day：补记——看以前的某一天时说的，记到那一天（docs/模块/产品优化.md R1.1）
    @discardableResult
    public func send(_ text: String, clientId: String, day: String? = nil) async throws(APIError) -> API.Note {
        var body = ["text": text, "clientId": clientId]
        if let day { body["day"] = day }
        return try await request("POST", "/api/notes", body: body)
    }

    public func undo(note id: Int) async throws(APIError) {
        let _: Empty = try await request("POST", "/api/notes/\(id)/undo")
    }

    public func retry(note id: Int) async throws(APIError) {
        let _: Empty = try await request("POST", "/api/notes/\(id)/retry")
    }

    /// 原地修改（字段名照服务器 update：start、duration_min、metrics……）
    public func update(entry id: Int, fields: [String: JSONValue]) async throws(APIError) {
        let _: Empty = try await request("PATCH", "/api/entries/\(id)", json: .object(["fields": .object(fields)]))
    }

    public func confirm(entry id: Int) async throws(APIError) {
        let _: Empty = try await request("PATCH", "/api/entries/\(id)", json: .object(["confirm": .bool(true)]))
    }

    public func setDone(entry id: Int, _ done: Bool) async throws(APIError) {
        let _: Empty = try await request("PATCH", "/api/entries/\(id)", json: .object(["done": .bool(done)]))
    }

    public func delete(entry id: Int) async throws(APIError) {
        let _: Empty = try await request("DELETE", "/api/entries/\(id)")
    }

    public func restore(entry id: Int) async throws(APIError) {
        let _: Empty = try await request("POST", "/api/entries/\(id)/restore")
    }

    /// 输入 PIN（局域网访问开了 PIN 时）：成功以后令牌在 cookie 里
    public func login(pin: String) async throws(APIError) {
        let _: Empty = try await request("POST", "/api/auth/login", body: ["pin": pin])
    }

    // MARK: -

    struct Empty: Decodable {}

    // 下面这几个不是 private：每一页的接口写在 PourAPI 里它自己的文件（像 Messages.swift），也用它们发请求

    func get<T: Decodable>(_ path: String) async throws(APIError) -> T {
        try await request("GET", path)
    }

    func request<T: Decodable>(
        _ method: String, _ path: String, body: [String: String]? = nil
    ) async throws(APIError) -> T {
        try await request(method, path, json: body.map { .object($0.mapValues { .string($0) }) })
    }

    func request<T: Decodable>(_ method: String, _ path: String, json: JSONValue?) async throws(APIError) -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw .unreachable }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "content-type")
            request.httpBody = try? JSONEncoder().encode(json)
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .unreachable
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let info = try? JSONDecoder().decode(ErrorBody.self, from: data)
            if status == 401 && info?.error == "need_pin" { throw .needPin }
            throw .server(
                status: status, code: info?.error ?? "http_\(status)", message: info?.message ?? "请求没有成功（\(status)）。")
        }
        if T.self == Empty.self, let empty = Empty() as? T { return empty }
        do {
            return try JSONDecoder().decode(T.self, from: data.isEmpty ? Data("{}".utf8) : data)
        } catch {
            throw .server(status: status, code: "decode", message: "看不懂服务器的回复：\(error.localizedDescription)")
        }
    }

    private struct ErrorBody: Decodable {
        let error: String?
        let message: String?
    }
}

/// 发给服务器的 JSON（改字段时用：数、字、列表、对象都有）
public enum JSONValue: Encodable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    public func encode(to encoder: any Encoder) throws {
        var box = encoder.singleValueContainer()
        switch self {
        case .string(let value): try box.encode(value)
        case .number(let value): try box.encode(value)
        case .bool(let value): try box.encode(value)
        case .array(let value): try box.encode(value)
        case .object(let value): try box.encode(value)
        case .null: try box.encodeNil()
        }
    }
}
