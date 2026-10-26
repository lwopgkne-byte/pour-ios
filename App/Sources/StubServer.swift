#if DEBUG
    import Foundation
    import PourAPI
    import PourCore
    import Synchronization

    /// 界面测试用的假服务器（只在 Debug 版里，启动参数 -uiTest）：不连网、不花钱，照服务器的接口回话。
    /// 说的话里有「跑了五公里」记一条跑步，有「吃面三十二」记一条吃面 ¥32（拿不准，要确认）；
    /// 「断网」→ 连不上；「余额」→ 处理失败；别的 → 只回一句话
    final class StubServer: URLProtocol, @unchecked Sendable {
        static func client() -> APIClient {
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [StubServer.self]
            let base = URL(string: "http://stub.local") ?? URL(fileURLWithPath: "/")
            return APIClient(baseURL: base, session: URLSession(configuration: config))
        }

        override static func canInit(with request: URLRequest) -> Bool { true }
        override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func stopLoading() {}

        override func startLoading() {
            // 服务器推送：连上了就一直开着、不说话（真的服务器有变化才推；界面测试里不推）
            if request.url?.path == "/api/events", let url = request.url,
                let response = HTTPURLResponse(
                    url: url, statusCode: 200, httpVersion: nil, headerFields: ["content-type": "text/event-stream"])
            {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                return
            }
            let reply = Self.state.withLock { $0.answer(request) }
            guard !reply.offline, let url = request.url,
                let response = HTTPURLResponse(url: url, statusCode: reply.status, httpVersion: nil, headerFields: nil)
            else {
                client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: reply.body)
            client?.urlProtocolDidFinishLoading(self)
        }

        /// 假服务器的一次回话：状态码、内容；offline 是装作连不上
        struct Reply {
            var status = 200
            var body = Data("{}".utf8)
            var offline = false
        }

        private static let state = Mutex(State())

        /// 最近一个请求带的这个请求头
        static func seenHeader(_ name: String) -> String? {
            state.withLock { $0.seenHeaders.first { $0.key.lowercased() == name.lowercased() }?.value }
        }

        /// 假服务器里的数据：说过的话、记录、删掉的记录
        struct State {
            var notes: [[String: Any]] = []
            /// 平时是空的；「-canvasSample 带孩子」时是那个人的今天（StubServer+Canvas）
            var entries: [[String: Any]] = Self.sampleEntries(today: PourDate.logicalDay(Date(), in: .current))
            var trash: [[String: Any]] = []
            var nextId = 1
            /// 对话里的系统消息：今天早上来的「昨天的回顾好了」
            var messages: [[String: Any]] = [Self.dailyReview]
            /// 提醒和推送的设置：改了的那几项盖上去（服务器 PUT /api/reminders）
            var reminders = Self.defaultReminders
            /// 名字表：「说到的」里改了名字、不再显示的（StubServer+Names）
            var names: [[String: Any]] = []
            /// 我的卡片、不要了的卡片、我的语录（StubServer+Cards）
            var cards: [[String: Any]] = Self.sampleCards()
            var trashCards: [[String: Any]] = []
            var quotes: [[String: Any]] = Self.sampleQuotes
            /// 健康 App 送来的（StubServer+Health）
            var health: [String: Any]?
            /// 最近一个请求带的请求头（单元测试看 App 有没有说自己照哪一版接口写的）
            var seenHeaders: [String: String] = [:]

            var today: String { PourDate.logicalDay(Date(), in: .current) }

            mutating func answer(_ request: URLRequest) -> Reply {
                guard let url = request.url else { return Reply(offline: true) }
                seenHeaders = request.allHTTPHeaderFields ?? [:]
                let method = request.httpMethod ?? "GET"
                let body = Self.body(request)
                if let reply = basic(method, url, body) { return reply }
                let parts = url.path.split(separator: "/").map(String.init)
                if parts.count == 3, parts[1] == "day" {
                    let health = healthOf(parts[2])
                    let entries = entries.filter { $0["day"] as? String == parts[2] } + health.entries
                    let sample = Self.samplePlan(today: today)[parts[2]]
                    let summary: Any = sample?.summary ?? NSNull()
                    var view: [String: Any] = [
                        "day": parts[2], "entries": entries, "summary": summary, "goals": sample?.goalList ?? [],
                        "mentions": mentionsOfDay(parts[2], sample: sample?.mentionList), "cards": cards,
                    ]
                    if let steps = health.steps { view["health"] = ["steps": steps] }
                    return ok(view)
                }
                if parts.count == 4, parts[1] == "notes", let id = Int(parts[2]) {
                    if parts[3] == "undo" { return ok(undo(note: id)) }
                    return ok(["ok": true])
                }
                if parts.count >= 3, parts[1] == "entries", let id = Int(parts[2]) {
                    return entry(method, id, parts.count == 4 ? parts[3] : "", body)
                }
                return Reply(status: 404, body: Data(#"{"error":"not_found","message":"没有这个接口"}"#.utf8))
            }

            /// 不带编号的接口：今天是哪天、类别表、说过的话、说一句
            private mutating func basic(_ method: String, _ url: URL, _ body: [String: Any]) -> Reply? {
                let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
                if let value = settingsReply(method, url.path, body) ?? namesReply(method, url.path, body)
                    ?? cardsReply(method, url.path, body) ?? healthReply(method, url.path, body)
                    ?? pageReply(method, url.path)
                {
                    return ok(value)
                }
                switch (method, url.path) {
                case ("GET", "/api/meta"):
                    return ok([
                        "today": today, "dayBoundary": 240, "mode": "real",
                        "api": ["version": APIClient.apiVersion, "minClient": 1], "server": "2.7.0",
                    ])
                case ("GET", "/api/categories"): return ok(["categories": Self.categories + Self.sampleCategories])
                case ("GET", "/api/messages"): return ok(["messages": messages])
                case ("GET", "/api/notes"):
                    if let day = query.first(where: { $0.name == "day" })?.value {
                        return ok(["notes": notes.filter { $0["day"] as? String == day }, "hasMore": false])
                    }
                    return ok(["notes": notes, "hasMore": false])
                case ("POST", "/api/notes"):
                    let text = body["text"] as? String ?? ""
                    if text.contains("断网") { return Reply(offline: true) }
                    // 补记：记到以前的那一天（docs/模块/产品优化.md R1.1）
                    let backfill = (body["day"] as? String).flatMap { $0 < today ? $0 : nil }
                    return ok(say(text, day: backfill))
                default:
                    return nil
                }
            }

            /// 一条记录：确认、打勾、改、删、放回来、最近 7 天
            private mutating func entry(_ method: String, _ id: Int, _ action: String, _ body: [String: Any]) -> Reply {
                switch (method, action) {
                case ("PATCH", _): return ok(patch(entry: id, body))
                case ("DELETE", _): return ok(delete(entry: id))
                case ("POST", "restore"): return ok(restore(entry: id))
                default: return ok(["label": "", "unit": "分钟", "points": [Any]()])
                }
            }

            private func ok(_ value: Any) -> Reply {
                Reply(body: (try? JSONSerialization.data(withJSONObject: value)) ?? Data("{}".utf8))
            }

            private static func body(_ request: URLRequest) -> [String: Any] {
                var data = request.httpBody
                if data == nil, let stream = request.httpBodyStream {
                    stream.open()
                    defer { stream.close() }
                    var buffer = [UInt8](repeating: 0, count: 64 * 1024)
                    let read = stream.read(&buffer, maxLength: buffer.count)
                    data = read > 0 ? Data(buffer.prefix(read)) : nil
                }
                return data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
            }

            /// 说一句：马上整理完（假服务器不排队）
            private mutating func say(_ text: String, day backfill: String? = nil) -> [String: Any] {
                let noteId = take()
                let now = ISO8601DateFormatter().string(from: Date())
                var note: [String: Any] = [
                    "id": noteId, "text": text, "createdAt": now, "day": backfill ?? today, "status": "done",
                ]
                if backfill != nil { note["backfill"] = true }
                if text.contains("余额") {
                    note["status"] = "failed"
                    note["error"] = "没整理成：大模型账户余额不足。"
                    notes.append(note)
                    return note
                }
                if let asked = SearchStub.asked(text, note) {
                    notes.append(asked)
                    return asked
                }
                var receipt: [[String: Any]] = []
                if text.contains("跑了五公里") {
                    let id = add(
                        Seed(category: "run", noteId: noteId, text: text, span: "跑了五公里"),
                        data: [
                            "label": "跑步", "start": "\(today)T07:10", "end": "\(today)T07:42", "durationMin": 32,
                            "metrics": [["name": "距离", "value": 5, "unit": "公里"]],
                        ])
                    receipt.append([
                        "action": "created", "kind": "event", "entryId": id, "text": "🏃 跑步 32 分钟 5 公里",
                        "pending": false,
                    ])
                }
                if text.contains("吃面三十二") {
                    let id = add(
                        Seed(category: "diet", noteId: noteId, text: text, span: "和小王吃面三十二"),
                        data: [
                            "label": "吃面", "metrics": [["name": "花费", "value": 32, "unit": "元"]], "people": ["小王"],
                        ],
                        question: "三十二是花了 32 块吗？")
                    receipt.append([
                        "action": "created", "kind": "event", "entryId": id, "text": "🍽 吃面 ¥32 · 和小王", "pending": true,
                    ])
                }
                note["result"] = [
                    "receipt": receipt, "reply": receipt.isEmpty ? "好的，听到了。" : "", "questions": [String](),
                    "notices": [String](),
                ]
                notes.append(note)
                return note
            }

            private mutating func take() -> Int {
                defer { nextId += 1 }
                return nextId
            }

            /// 一条事件来自哪段话、原话里哪一段
            struct Seed {
                let category: String
                let noteId: Int
                let text: String
                let span: String
            }

            private mutating func add(_ seed: Seed, data: [String: Any], question: String? = nil) -> Int {
                let id = take()
                var entry: [String: Any] = [
                    "id": id, "day": today, "confidence": question == nil ? 0.95 : 0.6,
                    "status": question == nil ? "ok" : "confirm", "kind": "event", "category": seed.category,
                    "data": data,
                    "sources": [
                        [
                            "noteId": seed.noteId, "span": seed.span, "action": "created", "text": seed.text,
                            "createdAt": ISO8601DateFormatter().string(from: Date()),
                        ]
                    ],
                ]
                if let question { entry["question"] = question }
                entries.append(entry)
                return id
            }

            private mutating func undo(note id: Int) -> [String: Any] {
                entries.removeAll { (($0["sources"] as? [[String: Any]])?.first?["noteId"] as? Int) == id }
                if let index = notes.firstIndex(where: { $0["id"] as? Int == id }),
                    var result = notes[index]["result"] as? [String: Any]
                {
                    result["undone"] = true
                    notes[index]["result"] = result
                }
                return ["ok": true]
            }

            private mutating func patch(entry id: Int, _ body: [String: Any]) -> [String: Any] {
                guard let index = entries.firstIndex(where: { $0["id"] as? Int == id }) else { return [:] }
                if body["confirm"] as? Bool == true {
                    entries[index]["status"] = "ok"
                    entries[index]["question"] = nil
                }
                if let done = body["done"] as? Bool, var data = entries[index]["data"] as? [String: Any] {
                    data["done"] = done
                    entries[index]["data"] = data
                }
                if let fields = body["fields"] as? [String: Any], var data = entries[index]["data"] as? [String: Any] {
                    if let label = fields["label"] as? String { data["label"] = label }
                    entries[index]["data"] = data
                }
                return entries[index]
            }

            private mutating func delete(entry id: Int) -> [String: Any] {
                if let index = entries.firstIndex(where: { $0["id"] as? Int == id }) {
                    trash.append(entries.remove(at: index))
                }
                return ["ok": true]
            }

            private mutating func restore(entry id: Int) -> [String: Any] {
                if let index = trash.firstIndex(where: { $0["id"] as? Int == id }) {
                    entries.append(trash.remove(at: index))
                }
                return ["ok": true]
            }
        }
    }
#endif
