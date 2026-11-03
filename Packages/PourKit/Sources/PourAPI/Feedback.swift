public import Foundation

// 反馈（POST /api/feedback，3.0 第 10 步）
extension APIClient {
    /// 发一条反馈：一句话、在哪一页、版本、截图（PNG）；回来建好的 GitHub 问题地址（没填令牌是 nil）和轻提示
    public func sendFeedback(
        text: String, page: String, app: String, server: String?, screenshot: Data?
    ) async throws(APIError) -> (issue: String?, toast: String) {
        struct Out: Decodable {
            let issue: String?
            let toast: String
        }
        var body: [String: JSONValue] = ["text": .string(text), "page": .string(page), "app": .string(app)]
        if let server { body["server"] = .string(server) }
        if let screenshot { body["screenshot"] = .string(screenshot.base64EncodedString()) }
        let out: Out = try await request("POST", "/api/feedback", json: .object(body))
        return (out.issue, out.toast)
    }
}
