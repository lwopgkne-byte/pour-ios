import Foundation

/// 服务器推过来的「哪些东西变了」（GET /api/events，text/event-stream）
public struct ServerEvent: Hashable, Sendable {
    /// notes-changed、entries-changed、summary-changed、goals-changed、messages-changed、settings-changed……
    public var type: String
    /// 只是原话的状态变了（刚收下、开始整理）：记录还没动
    public var statusOnly: Bool
    public var day: String?
    /// answer-delta：哪段话的回答
    public var noteId: Int?
    /// answer-delta：回答新长出来的一截；nil 是这段回答结束了（清空）
    public var text: String?
}

extension APIClient {
    /// 一直听着服务器的推送；断了由调用方等一会儿再接
    public nonisolated func events() -> AsyncThrowingStream<ServerEvent, any Error> {
        let url = baseURL.appending(path: "api/events")
        // 和别的请求同一套设置（输过 PIN 以后的 cookie、界面测试的假服务器）；
        // 服务器每 25 秒发一次心跳，90 秒什么都没收到就算断了，由调用方重连
        let config = session.configuration
        config.timeoutIntervalForRequest = Self.eventsSilence
        let listener = URLSession(configuration: config)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: url)
                    request.timeoutInterval = Self.eventsSilence
                    request.setValue("text/event-stream", forHTTPHeaderField: "accept")
                    let (bytes, response) = try await listener.bytes(for: request)
                    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw APIError.unreachable }
                    var type = "message"
                    var data = ""
                    for try await line in bytes.lines {
                        if line.hasPrefix("event:") {
                            type = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            data += line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                            // 一条推送的 data 是一行 JSON；收到就算一条（URLSession 的 lines 会吞掉空行）
                            continuation.yield(Self.event(type, data))
                            type = "message"
                            data = ""
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
                listener.invalidateAndCancel()
            }
        }
    }

    /// 多久没收到任何东西算断了（服务器 25 秒一次心跳）
    static let eventsSilence: TimeInterval = 90

    static func event(_ type: String, _ data: String) -> ServerEvent {
        struct Body: Decodable {
            let statusOnly: Bool?
            let day: String?
            let noteId: Int?
            let text: String?
        }
        let body = try? JSONDecoder().decode(Body.self, from: Data(data.utf8))
        return ServerEvent(
            type: type, statusOnly: body?.statusOnly ?? false, day: body?.day, noteId: body?.noteId, text: body?.text)
    }
}
