import Foundation

// 设置页里点开看的：你改过的地方（评测候选）、处理日志（网页版 lib/queries.ts 的 Candidate、RunSummary、StepDetail）
extension API {
    /// 你改过的一处：原话、改过之后的正确结果、通用的还是你个人的
    public struct Candidate: Codable, Hashable, Sendable, Identifiable {
        public struct Expected: Codable, Hashable, Sendable {
            public var kind: String
            public var category: String?
            public var label: String?
            public var start: String?
            public var end: String?
            public var durationMin: Int?
            public var values: [Double]?
            public var due: String?
            public var done: Bool?
        }

        public var id: Int
        public var noteId: Int
        public var text: String
        public var createdAt: String
        public var expected: [Expected]
        /// general 通用的、personal 你个人的；nil 是 AI 还在看，或者大模型用不了
        public var scope: String?
        public var scopeWhy: String?
        /// ai、me
        public var scopeBy: String?
        public var phrase: String?
        public var meaning: String?
    }

    /// 处理日志的一次整理
    public struct RunSummary: Codable, Hashable, Sendable, Identifiable {
        public var id: Int
        public var noteId: Int
        public var noteText: String
        public var startedAt: String
        public var outcome: String?
        public var error: String?
        public var durationMs: Int
        public var totalTokens: Int
        public var promptTokens: Int
        public var cacheHitTokens: Int
        public var completionTokens: Int
        public var costCny: Double
        /// 在 DeepSeek 的高峰时段（价格翻倍）
        public var peak: Bool
    }

    /// 一次整理里的一步：发给大模型的、它回的、用了多久
    public struct StepDetail: Codable, Hashable, Sendable, Identifiable {
        public var id: Int
        public var step: String
        public var skill: String?
        public var skillVersion: String?
        public var input: String?
        public var output: String?
        public var result: String?
        public var error: String?
        public var durationMs: Int
        public var promptTokens: Int
        public var cacheHitTokens: Int
        public var completionTokens: Int
    }

    struct Runs: Decodable {
        let runs: [RunSummary]
    }

    struct Steps: Decodable {
        let steps: [StepDetail]
    }
}

extension APIClient {
    public func candidateList() async throws(APIError) -> API.Candidates { try await get("/api/eval-candidates") }

    /// 收进检查清单（你个人的会顺便记住那个说法）
    public func addCandidate(_ id: Int) async throws(APIError) {
        let _: Empty = try await request("POST", "/api/eval-candidates/\(id)/add")
    }

    /// 改成通用的 / 你个人的
    public func setCandidateScope(_ id: Int, _ scope: String) async throws(APIError) {
        let _: Empty = try await request("POST", "/api/eval-candidates/\(id)/scope", body: ["scope": scope])
    }

    public func ignoreCandidate(_ id: Int) async throws(APIError) {
        let _: Empty = try await request("DELETE", "/api/eval-candidates/\(id)")
    }

    /// 最近 50 次整理
    public func runs() async throws(APIError) -> [API.RunSummary] {
        let page: API.Runs = try await get("/api/llm/runs")
        return page.runs
    }

    public func runSteps(_ id: Int) async throws(APIError) -> [API.StepDetail] {
        let page: API.Steps = try await get("/api/llm/runs/\(id)")
        return page.steps
    }
}
