public import Foundation

/// 设置页用到的接口（网页版 pages/*Settings.tsx 里的 api.get / post / put / patch / del）
extension APIClient {
    // MARK: - 大模型

    public func llmStatus() async throws(APIError) -> API.LlmStatus { try await get("/api/llm/status") }

    /// 改模型、每月上限、自动入库的把握程度（三个之一）
    public func llmSettings(_ fields: [String: JSONValue]) async throws(APIError) {
        let _: Empty = try await request("POST", "/api/llm/settings", json: .object(fields))
    }

    /// 「你说的话会发送到大模型服务器整理」点了确认
    public func acceptConsent() async throws(APIError) {
        let _: Empty = try await request("POST", "/api/llm/consent")
    }

    public func testLLM() async throws(APIError) -> API.TestResult { try await request("POST", "/api/llm/test") }

    // MARK: - 提醒和推送

    public func reminders() async throws(APIError) -> API.ReminderStatus { try await get("/api/reminders") }

    /// 改提醒：只传改了的那几项，回来的是改完的全部
    public func saveReminders(_ patch: [String: JSONValue]) async throws(APIError) -> API.ReminderStatus {
        try await request("PUT", "/api/reminders", json: .object(patch))
    }

    /// 「试一下」：morning、evening、warning、weekly、monthly
    public func tryReminder(_ kind: String) async throws(APIError) -> API.TryResult {
        try await request("POST", "/api/reminders/try/\(kind)")
    }

    public func testPush() async throws(APIError) -> [API.PushResult] {
        let reply: API.PushTest = try await request("POST", "/api/push/test")
        return reply.results
    }

    // MARK: - AI 准不准

    public func growth() async throws(APIError) -> API.Growth { try await get("/api/growth") }
    public func auditStatus() async throws(APIError) -> API.AuditStatus { try await get("/api/audit/status") }
    public func evals() async throws(APIError) -> API.Evals { try await get("/api/evals") }
    public func candidates() async throws(APIError) -> API.Candidates { try await get("/api/eval-candidates") }

    // MARK: - 类别

    public func categoriesPage() async throws(APIError) -> API.CategoriesPage { try await get("/api/categories") }

    /// 改名、图标、颜色、上级、同义词
    public func updateCategory(_ key: String, _ fields: [String: JSONValue]) async throws(APIError) {
        let _: Empty = try await request("PATCH", "/api/categories/\(key)", json: .object(fields))
    }

    public func mergeCategory(_ key: String, into target: String) async throws(APIError) {
        let _: Empty = try await request("POST", "/api/categories/\(key)/merge", body: ["into": target])
    }

    public func deleteCategory(_ key: String) async throws(APIError) {
        let _: Empty = try await request("DELETE", "/api/categories/\(key)")
    }

    /// 「其他」里的按现在的规则重新归类
    public func tidyOther() async throws(APIError) {
        let _: Empty = try await request("POST", "/api/categories/other/tidy", json: .object([:]))
    }

    // MARK: - 局域网访问、数据

    public func lan() async throws(APIError) -> API.LanInfo { try await get("/api/settings/lan") }
    public func dataStatus() async throws(APIError) -> API.DataStatus { try await get("/api/data/status") }

    public func backup() async throws(APIError) {
        let _: Empty = try await request("POST", "/api/data/backup")
    }

    /// 日界线：几点以前算前一天（分钟）
    public func setDayBoundary(_ minutes: Int) async throws(APIError) {
        let _: Empty = try await request(
            "POST", "/api/settings/day-boundary", json: .object(["minutes": .number(Double(minutes))]))
    }

    public func reparseEstimate(from: String, until: String) async throws(APIError) -> API.ReparseEstimate {
        try await request("POST", "/api/data/reparse/estimate", body: ["from": from, "to": until])
    }

    /// 开始重新解析，回来的是有几段话
    public func reparse(from: String, until: String) async throws(APIError) -> Int {
        let reply: Reparsed = try await request("POST", "/api/data/reparse", body: ["from": from, "to": until])
        return reply.notes
    }

    /// 切换真实数据、演示数据（服务器会重新启动）
    public func switchData(to mode: String, regenerate: Bool = false) async throws(APIError) {
        let _: Empty = try await request(
            "POST", "/api/data/mode", json: .object(["mode": .string(mode), "regenerate": .bool(regenerate)]))
    }

    /// 导出全部数据的地址（zip）
    public var exportURL: URL { baseURL.appending(path: "api/data/export") }

    struct Reparsed: Decodable {
        let notes: Int
    }
}
