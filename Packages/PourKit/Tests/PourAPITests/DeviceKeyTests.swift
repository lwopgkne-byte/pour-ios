import Foundation
import PourAPI
import Synchronization
import Testing

/// 设备登录（docs/模块/产品优化.md R8）：有这台设备的钥匙，每个请求都带上；没有就不带（只靠 cookie）
@Suite("设备的钥匙", .serialized)
struct DeviceKeyTests {
    @Test func sendsTheKey() async throws {
        let withKey = APIClient(baseURL: URL(string: "http://pour")!, session: HeaderCatcher.session) { "abc123" }
        _ = try? await withKey.meta()
        #expect(HeaderCatcher.last() == "Bearer abc123")
        let without = APIClient(baseURL: URL(string: "http://pour")!, session: HeaderCatcher.session)
        _ = try? await without.meta()
        #expect(HeaderCatcher.last() == nil)
    }

    @Test func decodesPairing() throws {
        let fresh = try JSONDecoder().decode(
            API.Pairing.self, from: Data(#"{"ok":true,"token":"k","device":{"id":3,"name":"iPhone"}}"#.utf8))
        #expect(fresh.token == "k")
        #expect(fresh.device?.id == 3)
        // 旧服务器只回 ok：照样解得出来，没有钥匙
        let old = try JSONDecoder().decode(API.Pairing.self, from: Data(#"{"ok":true}"#.utf8))
        #expect(old.token == nil)
    }
}

/// 假服务器：记下最后一个请求的 Authorization，回一个空的 meta
final class HeaderCatcher: URLProtocol, @unchecked Sendable {
    private static let seen = Mutex<String?>(nil)

    static func last() -> String? { seen.withLock { $0 } }

    static var session: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HeaderCatcher.self]
        return URLSession(configuration: config)
    }

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let header = request.value(forHTTPHeaderField: "Authorization")
        Self.seen.withLock { $0 = header }
        let body = Data(#"{"today":"2026-10-26","dayBoundary":240}"#.utf8)
        guard let url = request.url,
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
