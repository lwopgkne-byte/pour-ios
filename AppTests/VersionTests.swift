import Foundation
import PourAPI
import Testing

@testable import Pour

/// 版本号（docs/模块/产品优化.md R8）：每个请求说自己照哪一版接口写的、自己是哪个版本；电脑上的 Pour 太旧时说清楚
@Suite("版本号")
@MainActor
struct VersionTests {
    @Test func everyRequestSaysItsVersion() async throws {
        let client = StubServer.client()
        _ = try await client.meta()
        #expect(StubServer.seenHeader("X-Pour-Api") == String(APIClient.apiVersion))
        #expect(StubServer.seenHeader("X-Pour-App")?.hasPrefix("Pour iOS ") == true)
    }

    @Test func oldServerIsSaidClearly() {
        // 2.7.0 以前的服务器没有接口版本
        #expect(AppModel.serverProblem(api: nil)?.contains("要更新") == true)
        #expect(AppModel.serverProblem(api: APIClient.apiVersion) == nil)
        #expect(AppModel.serverProblem(api: APIClient.apiVersion + 1) == nil)
    }
}
