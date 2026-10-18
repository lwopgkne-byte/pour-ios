#if DEBUG
    import Foundation
    import PourAI
    import PourCore

    /// 界面测试用的假网关（只在 Debug 版里，启动参数 -uiTest）：不连网、不花钱，按原话里的字回一个改动包。
    /// 「跑」→ 跑步 5 公里；「面」→ 吃面 ¥32 · 和小王（待确认）；「对」→ 确认等着的那条；
    /// 「断网」→ 连不上；「余额」→ 余额不足；别的 → 只回一句话。
    /// 回之前等 0.8 秒，看得见「整理中」
    final class StubGateway: URLProtocol, @unchecked Sendable {
        static func client() -> GatewayClient {
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [StubGateway.self]
            return GatewayClient(
                baseURL: URL(string: GatewayConfiguration.fallback) ?? URL(fileURLWithPath: "/"),
                session: URLSession(configuration: config))
        }

        override static func canInit(with request: URLRequest) -> Bool { true }
        override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func stopLoading() {}

        override func startLoading() {
            let body = Self.body(of: request)
            let background = body.flatMap { try? JSONDecoder().decode(BackgroundPackage.self, from: $0) }
            let text = background?.note.text ?? ""
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.8) { [self] in
                if text.contains("断网") {
                    client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
                    return
                }
                let (status, json) = Self.reply(to: background, text: text)
                let url = request.url ?? URL(fileURLWithPath: "/")
                if let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) {
                    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                }
                client?.urlProtocol(self, didLoad: Data(json.utf8))
                client?.urlProtocolDidFinishLoading(self)
            }
        }

        private static func reply(to background: BackgroundPackage?, text: String) -> (Int, String) {
            if text.contains("余额") {
                let error = #"{"code":"insufficient_balance","message":"大模型账户余额不足。","retryable":false}"#
                return (502, #"{"error":\#(error)}"#)
            }
            let day = background?.note.day ?? ""
            var creates: [String] = []
            var updates: [String] = []
            if text.contains("跑") {
                creates.append(
                    #"{"day":"\#(day)","data":{"kind":"event","category":"run","label":"跑步","#
                        + #""start":"\#(day)T07:10","durationMin":32,"#
                        + #""metrics":[{"name":"距离","value":5,"unit":"公里"}],"people":[],"things":[],"places":[]},"#
                        + #""span":"跑了五公里","confidence":0.95}"#)
            }
            if text.contains("面") {
                creates.append(
                    #"{"day":"\#(day)","data":{"kind":"event","category":"diet","label":"吃面","#
                        + #""metrics":[{"name":"花费","value":32,"unit":"元"}],"people":["小王"],"things":[],"places":[]},"#
                        + #""span":"和小王吃面三十二","confidence":0.6,"question":"三十二是花了 32 块吗？"}"#)
            }
            // 「对」：回答追问，确认还在等确认的那一条（真的网关靠最近的对话认出来）
            if text == "对", let waiting = background?.existing.first(where: { $0.question != nil }),
                let data = try? JSONEncoder().encode(waiting.data), let json = String(bytes: data, encoding: .utf8)
            {
                updates.append(
                    #"{"id":"\#(waiting.id)","action":"confirmed","day":"\#(waiting.day)","data":\#(json),"#
                        + #""span":"对","confidence":1}"#)
            }
            let reply = creates.isEmpty && updates.isEmpty ? "好的，听到了。" : ""
            let noteId = background?.note.id ?? ""
            return (
                200,
                #"{"version":\#(BackgroundPackage.contractVersion),"noteId":"\#(noteId)","intents":["record"],"#
                    + #""creates":[\#(creates.joined(separator: ","))],"updates":[\#(updates.joined(separator: ","))],"#
                    + #""deletes":[],"duplicates":[],"questions":[],"awaitingDelete":[],"newCategories":[],"#
                    + #""reply":"\#(reply)","steps":[]}"#
            )
        }

        private static func body(of request: URLRequest) -> Data? {
            if let data = request.httpBody { return data }
            guard let stream = request.httpBodyStream else { return nil }
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
            return data
        }
    }
#endif
