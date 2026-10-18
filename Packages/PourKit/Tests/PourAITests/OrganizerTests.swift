import Foundation
import PourAI
import PourCore
import PourData
import Testing

/// 假网关：按顺序回预先准备好的结果，记下收到的背景包（不发真实请求）
final class FakeGateway: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var replies: [(status: Int, body: String)] = []
    nonisolated(unsafe) static var received: [BackgroundPackage] = []
    nonisolated(unsafe) static var unreachable = false

    static let gateway = URL(string: "http://127.0.0.1:5480") ?? URL(fileURLWithPath: "/")

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if Self.unreachable {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        if let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
            stream.close()
            if let background = try? JSONDecoder().decode(BackgroundPackage.self, from: data) {
                Self.received.append(background)
            }
        }
        let reply: (status: Int, body: String) = Self.replies.isEmpty ? (500, "{}") : Self.replies.removeFirst()
        let url = request.url ?? Self.gateway
        if let response = HTTPURLResponse(url: url, statusCode: reply.status, httpVersion: nil, headerFields: nil) {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func client() -> GatewayClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FakeGateway.self]
        return GatewayClient(baseURL: gateway, session: URLSession(configuration: config))
    }

    static func change(noteId: String, _ creates: String, reply: String = "") -> String {
        #"{"version":1,"noteId":"\#(noteId)","intents":["record"],"#
            + #""creates":\#(creates),"reply":"\#(reply)","steps":[]}"#
    }
}

@Suite("理解服务", .serialized)
struct OrganizerTests {
    let shanghai = TimeZone(identifier: "Asia/Shanghai") ?? .gmt

    init() {
        FakeGateway.replies = []
        FakeGateway.received = []
        FakeGateway.unreachable = false
    }

    @Test func organizesANoteIntoRecords() async throws {
        let store = try PourStore.inMemory()
        let date = Date(timeIntervalSince1970: 1_792_281_600)  // 2026-10-18 00:00 UTC = 上海 08:00
        let note = try store.addNote("早上跑了五公里", at: date, timeZone: shanghai)
        let run =
            #"[{"day":"2026-10-18","data":{"kind":"event","category":"run","label":"跑步","#
            + #""metrics":[{"name":"距离","value":5,"unit":"公里"}],"people":[],"things":[],"places":[]},"#
            + #""span":"早上跑了五公里","confidence":0.95}]"#
        FakeGateway.replies = [(200, FakeGateway.change(noteId: note.id, run))]
        let organizer = Organizer(store: store, gateway: FakeGateway.client(), now: { date })
        await organizer.drain()

        let day = try store.snapshot(of: "2026-10-18")
        #expect(day.notes.first?.status == .done)
        #expect(day.entries.count == 1)
        // 背景包：原话、本地钟点、预置类别都带上了
        let sent = try #require(FakeGateway.received.first)
        #expect(sent.note.text == "早上跑了五公里")
        #expect(sent.note.localTime == "2026-10-18T08:00")
        #expect(sent.categories.count == 9)
    }

    @Test func waitsForTheNetworkWhenTheGatewayIsUnreachable() async throws {
        let store = try PourStore.inMemory()
        let date = Date(timeIntervalSince1970: 1_792_281_600)
        let note = try store.addNote("早上跑了五公里", at: date, timeZone: shanghai)
        FakeGateway.unreachable = true
        let organizer = Organizer(store: store, gateway: FakeGateway.client(), now: { date })
        await organizer.drain()
        #expect(try store.snapshot(of: "2026-10-18").notes.first?.status == .waitingForNetwork)
        #expect(try store.nextRetryDate() == date.addingTimeInterval(5))
        // 一联网就马上整理
        FakeGateway.unreachable = false
        FakeGateway.replies = [(200, FakeGateway.change(noteId: note.id, "[]", reply: "好的"))]
        await organizer.networkCameBack()
        await organizer.drain()
        let organized = try store.snapshot(of: "2026-10-18").notes.first
        #expect(organized?.status == .done)
        #expect(organized?.reply == "好的")
    }

    @Test func retriesAWhileThenWaitsForYou() async throws {
        let store = try PourStore.inMemory()
        var clock = Date(timeIntervalSince1970: 1_792_281_600)
        try store.addNote("早上跑了五公里", at: clock, timeZone: shanghai)
        let timeout = #"{"error":{"code":"timeout","message":"大模型超过 90 秒没有回应。","retryable":true}}"#
        FakeGateway.replies = [(504, timeout), (504, timeout), (504, timeout)]
        for _ in 0..<3 {
            let now = clock
            await Organizer(store: store, gateway: FakeGateway.client(), now: { now }).drain()
            clock = clock.addingTimeInterval(120)
        }
        let note = try #require(try store.snapshot(of: "2026-10-18").notes.first)
        #expect(note.status == .failed)
        #expect(note.problem?.hasPrefix("没整理成：AI 这次没有回应") == true)
    }

    @Test func problemsThatNeedYouAreSaidPlainly() async throws {
        let store = try PourStore.inMemory()
        let date = Date(timeIntervalSince1970: 1_792_281_600)
        try store.addNote("早上跑了五公里", at: date, timeZone: shanghai)
        FakeGateway.replies = [
            (502, #"{"error":{"code":"insufficient_balance","message":"大模型账户余额不足。充值后会自动继续整理。","retryable":false}}"#)
        ]
        await Organizer(store: store, gateway: FakeGateway.client(), now: { date }).drain()
        let note = try #require(try store.snapshot(of: "2026-10-18").notes.first)
        #expect(note.status == .failed)
        #expect(note.problem == "没整理成：大模型账户余额不足。充值后会自动继续整理。")
    }
}
