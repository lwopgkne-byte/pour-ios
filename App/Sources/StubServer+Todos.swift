#if DEBUG
    import Foundation
    import PourAPI
    import PourCore

    /// 假服务器的 3.0 待办（服务器 server/src/routes/todos.ts、services/todo-page.ts）：分好组的单子、边打边认、快加、
    /// 推迟、详情里改、只删这一次、带到今天、提醒单子。「-todoSample」时有一组样例待办
    extension StubServer.State {
        /// 一件样例待办：哪天说的（离今天几天）、要做的事、别的字段
        private struct Sample {
            let said: Int
            let content: String
            var extra: [String: Any] = [:]
        }

        /// 待办页的样例：以前没做完的两件、今天三件（一件要提醒、一件重复）、明天、以后、做完的
        static func sampleTodos(today: String) -> [[String: Any]] {
            let day = { (offset: Int) in PourDate.addDays(today, offset) }
            let items = [
                Sample(said: -3, content: "交水费", extra: ["due": day(-2)]),
                Sample(said: -1, content: "修自行车", extra: ["remindAt": "\(day(-1))T19:00"]),
                Sample(said: 0, content: "给客户回电话", extra: ["remindAt": "\(today)T23:50", "people": ["王总"]]),
                Sample(said: 0, content: "回邮件"),
                Sample(said: 0, content: "吃降压药", extra: ["remindAt": "\(today)T23:55", "repeat": ["kind": "daily"]]),
                Sample(
                    said: 0, content: "交周报",
                    extra: ["due": day(1), "remindAt": "\(day(1))T09:00", "repeat": ["kind": "weekly", "days": [0]]]),
                Sample(said: 0, content: "续保险", extra: ["due": day(40)]),
                Sample(said: -1, content: "买牛奶", extra: ["done": true, "doneAt": "\(day(-1))T09:00:00.000Z"]),
            ]
            return items.enumerated().map { index, item in
                var data: [String: Any] = ["content": item.content, "done": false]
                data.merge(item.extra) { _, new in new }
                return [
                    "id": 700 + index, "day": day(item.said), "kind": "todo", "category": "todo", "confidence": 1,
                    "status": "ok", "data": data,
                    "sources": [
                        [
                            "noteId": 900 + index, "span": item.content, "action": "created",
                            "text": "提醒我\(item.content)", "createdAt": "\(day(item.said))T08:00:00.000Z",
                        ]
                    ],
                ]
            }
        }

        mutating func todoReply(_ method: String, _ url: URL, _ body: [String: Any]) -> Any? {
            let parts = url.path.split(separator: "/").map(String.init)
            guard parts.count >= 2, parts[1] == "todos" else { return nil }
            if let id = parts.count >= 3 ? Int(parts[2]) : nil {
                return oneTodo(method, id, parts.count == 4 ? parts[3] : "", body)
            }
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            switch (method, parts.count == 3 ? parts[2] : "") {
            case ("GET", ""):
                return query.contains { $0.name == "reminders" } ? ["reminders": reminderList()] : todoPage()
            case ("POST", "parse"):
                var when = Self.parseWhen(body["text"] as? String ?? "", today: today)
                let day = when["day"] as? String
                let time = when["time"] as? String
                when["label"] = Self.orNull(
                    day == nil && time == nil ? nil : TodoBoard.when(day: day ?? today, time: time, today: today))
                return when
            case ("POST", ""): return quickAdd(body["text"] as? String ?? "")
            case ("POST", "carry"): return carry(body["ids"] as? [Int])
            default: return nil
            }
        }

        /// 一件待办：详情里改、推迟、只删这一次
        private mutating func oneTodo(_ method: String, _ id: Int, _ action: String, _ body: [String: Any]) -> Any? {
            guard let index = entries.firstIndex(where: { $0["id"] as? Int == id && $0["kind"] as? String == "todo" })
            else { return nil }
            switch (method, action) {
            case ("PATCH", ""):
                edit(index, body)
                return ["todo": row(entries[index])]
            case ("POST", "snooze"):
                snooze(index, body)
                return ["todo": row(entries[index])]
            case ("POST", "skip"):
                let entry = entries.remove(at: index)
                trash.append(entry)
                return ["next": Self.orNull(followingOf(entry).map(row))]
            default:
                return nil
            }
        }

        /// 推迟：几个说好的选项（App 和服务器同一套算法），或者自己挑的那天那个钟点；记下最早的那个时间
        private mutating func snooze(_ index: Int, _ body: [String: Any]) {
            let preset = (body["preset"] as? String).flatMap(SnoozePreset.init(rawValue:))
            let target: (day: String, time: String) =
                preset?.target(now: Date(), today: today)
                ?? (day: body["day"] as? String ?? today, time: body["time"] as? String ?? "")
            var data = entries[index]["data"] as? [String: Any] ?? [:]
            if data["snoozedFrom"] == nil {
                data["snoozedFrom"] = data["remindAt"] ?? data["due"] ?? entries[index]["day"]
            }
            entries[index]["data"] = data
            edit(index, ["day": target.day, "time": Self.orNull(target.time.isEmpty ? nil : target.time)])
        }

        /// 打勾、取消打勾（PATCH /api/entries/:id）：记下做完的时刻；重复的做完了生成下一次
        mutating func todoDone(_ index: Int, _ done: Bool) {
            guard var data = entries[index]["data"] as? [String: Any] else { return }
            let was = data["done"] as? Bool ?? false
            data["done"] = done
            data["doneAt"] = done ? (data["doneAt"] ?? ISO8601DateFormatter().string(from: Date())) : nil
            entries[index]["data"] = data
            if done, !was, entries[index]["kind"] as? String == "todo" { _ = followingOf(entries[index]) }
        }

        // MARK: - 单子

        private func todoPage() -> [String: Any] {
            let rows = entries.filter { $0["kind"] as? String == "todo" }.map(row)
            let tomorrow = PourDate.addDays(today, 1)
            let sunday = PourDate.addDays(today, 6 - PourDate.weekdayMon0(today))
            let open = { (row: [String: Any]) in row["done"] as? Bool != true }
            let day = { (row: [String: Any]) in row["day"] as? String ?? "" }
            let sorted = { (list: [[String: Any]], newestFirst: Bool) in
                list.sorted { lhs, rhs in
                    let left = "\(day(lhs))\(lhs["remindAt"] as? String ?? "99")\(lhs["id"] as? Int ?? 0)"
                    let right = "\(day(rhs))\(rhs["remindAt"] as? String ?? "99")\(rhs["id"] as? Int ?? 0)"
                    return newestFirst ? left > right : left < right
                }
            }
            let groups = [
                TodoGroupRows("overdue", "以前没做完的", sorted(rows.filter { open($0) && day($0) < today }, true)),
                TodoGroupRows(
                    "today", "今天 · \(Show.dayTitle(today, today: today))",
                    sorted(rows.filter { open($0) && day($0) == today }, false)),
                TodoGroupRows("tomorrow", "明天", sorted(rows.filter { open($0) && day($0) == tomorrow }, false)),
                TodoGroupRows(
                    "week", "这周", sorted(rows.filter { open($0) && day($0) > tomorrow && day($0) <= sunday }, false)),
                TodoGroupRows(
                    "later", "以后", sorted(rows.filter { open($0) && day($0) > max(sunday, tomorrow) }, false)),
                TodoGroupRows(
                    "done", "已完成",
                    rows.filter { !open($0) }.sorted {
                        ($0["doneAt"] as? String ?? "") > ($1["doneAt"] as? String ?? "")
                    }),
            ]
            let count = groups.prefix(2).map(\.rows.count).reduce(0, +)
            return [
                "today": today, "open": count,
                "groups": groups.filter { !$0.rows.isEmpty || $0.key == "today" }.map {
                    ["key": $0.key, "title": $0.title, "rows": $0.rows] as [String: Any]
                },
            ]
        }

        private func reminderList() -> [[String: Any]] {
            let now = PourDate.localDateTime(Date(), in: .current)
            return entries.compactMap { entry -> [String: Any]? in
                guard entry["kind"] as? String == "todo", let data = entry["data"] as? [String: Any],
                    data["done"] as? Bool != true, let at = data["remindAt"] as? String, at > now
                else { return nil }
                return [
                    "id": entry["id"] ?? 0, "content": data["content"] ?? "", "at": at, "said": entry["day"] ?? today,
                ]
            }
            .sorted { ($0["at"] as? String ?? "") < ($1["at"] as? String ?? "") }
        }

        /// 记录 → 待办页的一行（services/todo-page.ts todoRow）
        private func row(_ entry: [String: Any]) -> [String: Any] {
            let data = entry["data"] as? [String: Any] ?? [:]
            let day = data["due"] as? String ?? entry["day"] as? String ?? today
            let done = data["done"] as? Bool ?? false
            let source = (entry["sources"] as? [[String: Any]])?.first
            let rule = data["repeat"] as? [String: Any]
            return [
                "id": entry["id"] ?? 0, "content": data["content"] ?? "", "day": day,
                "remindAt": Self.orNull((data["remindAt"] as? String).map { String($0.suffix(5)) }),
                "done": done, "doneAt": Self.orNull(data["doneAt"]), "repeat": Self.orNull(rule),
                "repeatText": Self.orNull(rule.flatMap(Self.repeatOf).map(\.text)), "overdue": !done && day < today,
                "snoozedFrom": data["snoozedFrom"] ?? NSNull(), "people": data["people"] ?? [String](),
                "things": data["things"] ?? [String](), "places": data["places"] ?? [String](),
                "source": Self.orNull(
                    source.map {
                        ["noteId": $0["noteId"] ?? 0, "text": $0["text"] ?? "", "at": $0["createdAt"] ?? ""]
                            as [String: Any]
                    }),
            ]
        }

        // MARK: - 改

        /// 详情里改（services/todo-page.ts edited）：改了日子、钟点没给，原来的钟点挪过去；time、repeat 是 null 就去掉
        private mutating func edit(_ index: Int, _ change: [String: Any]) {
            var data = entries[index]["data"] as? [String: Any] ?? [:]
            if let content = change["content"] as? String { data["content"] = content }
            let day = change["day"] as? String ?? data["due"] as? String ?? entries[index]["day"] as? String ?? today
            if change["day"] is String { data["due"] = day }
            let clock: String? =
                change.keys.contains("time")
                ? change["time"] as? String : (data["remindAt"] as? String).map { String($0.suffix(5)) }
            data["remindAt"] = clock.map { "\(day)T\($0)" }
            if change.keys.contains("repeat") { data["repeat"] = change["repeat"] as? [String: Any] }
            entries[index]["data"] = data
        }

        private mutating func carry(_ ids: [Int]?) -> [String: Any] {
            var moved: [Int] = []
            for index in entries.indices where entries[index]["kind"] as? String == "todo" {
                let id = entries[index]["id"] as? Int ?? 0
                let current = row(entries[index])
                guard current["overdue"] as? Bool == true, ids?.contains(id) ?? true else { continue }
                edit(index, ["day": today])
                moved.append(id)
            }
            return ["moved": moved]
        }

        /// 快加：原话存下、认好时间建待办、回认出的结果
        private mutating func quickAdd(_ text: String) -> [String: Any] {
            let when = Self.parseWhen(text, today: today)
            let noteId = nextId
            let id = nextId + 1
            nextId += 2
            let due = when["day"] as? String ?? today
            var data: [String: Any] = ["content": when["title"] ?? text, "done": false, "due": due]
            if let time = when["time"] as? String { data["remindAt"] = "\(due)T\(time)" }
            if let rule = when["repeat"] as? [String: Any] { data["repeat"] = rule }
            let now = ISO8601DateFormatter().string(from: Date())
            entries.append([
                "id": id, "day": today, "kind": "todo", "category": "todo", "confidence": 1, "status": "ok",
                "data": data,
                "sources": [["noteId": noteId, "span": text, "action": "created", "text": text, "createdAt": now]],
            ])
            let note: [String: Any] = ["id": noteId, "text": text, "createdAt": now, "day": today, "status": "done"]
            notes.append(note)
            return ["note": note, "todo": row(entries[entries.count - 1])]
        }

        /// 重复的下一次（services/todo-page.ts nextOfRepeat）
        private mutating func followingOf(_ entry: [String: Any]) -> [String: Any]? {
            guard var data = entry["data"] as? [String: Any],
                let rule = (data["repeat"] as? [String: Any]).flatMap(Self.repeatOf)
            else { return nil }
            let from = data["due"] as? String ?? entry["day"] as? String ?? today
            let day = Self.next(rule, after: from)
            let clock = (data["remindAt"] as? String).map { String($0.suffix(5)) }
            data["due"] = day
            data["done"] = false
            data["doneAt"] = nil
            data["snoozedFrom"] = nil
            data["remindAt"] = clock.map { "\(day)T\($0)" }
            var next = entry
            next["id"] = nextId
            next["data"] = data
            nextId += 1
            entries.append(next)
            return next
        }

        static func repeatOf(_ rule: [String: Any]) -> API.Repeat? {
            switch rule["kind"] as? String {
            case "daily": .daily
            case "weekdays": .weekdays
            case "weekly": .weekly(rule["days"] as? [Int] ?? [0])
            case "monthly": .monthly(rule["day"] as? Int ?? 1)
            default: nil
            }
        }

        static func next(_ rule: API.Repeat, after day: String) -> String {
            var next = PourDate.addDays(day, 1)
            for _ in 0..<62 {
                let weekday = PourDate.weekdayMon0(next)
                switch rule {
                case .daily: return next
                case .weekdays: if weekday < 5 { return next }
                case .weekly(let days): if days.contains(weekday) { return next }
                case .monthly(let date): if Int(next.suffix(2)) == date { return next }
                }
                next = PourDate.addDays(next, 1)
            }
            return next
        }

        // MARK: - 认时间（服务器 shared/src/when.ts 的一小部分：界面测试用的那几句）

        static func parseWhen(_ text: String, today: String) -> [String: Any] {
            var heard = Heard(text: text)
            heard.day(today: today)
            heard.weekly(today: today)
            heard.minutesLater()
            if heard.time == nil { heard.clock() }
            var title = text
            for span in heard.spans.sorted(by: { $0[0] > $1[0] }) {
                title = (title as NSString).replacingCharacters(
                    in: NSRange(location: span[0], length: span[1] - span[0]), with: "")
            }
            title = title.replacingOccurrences(of: "提醒我", with: "").trimmingCharacters(in: .whitespaces)
            return [
                "day": orNull(heard.day), "time": orNull(heard.time), "repeat": orNull(heard.rule),
                "repeatText": orNull(heard.rule.flatMap(repeatOf).map(\.text)),
                "spans": heard.spans.sorted { $0[0] < $1[0] }, "title": title.isEmpty ? text : title,
            ]
        }

        /// 没有就是 JSON 的 null
        static func orNull(_ value: Any?) -> Any { value ?? NSNull() }

        /// 「三」「十二」「8」→ 数
        static func number(_ text: String) -> Int {
            if let value = Int(text) { return value }
            let digits = ["零": 0, "一": 1, "二": 2, "两": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9]
            if text.hasPrefix("十") { return 10 + (digits[String(text.dropFirst())] ?? 0) }
            if text.count == 3, text.dropFirst().hasPrefix("十") {
                return (digits[String(text.prefix(1))] ?? 0) * 10 + (digits[String(text.suffix(1))] ?? 0)
            }
            return digits[text] ?? 0
        }
    }

    /// 待办页的一组（假服务器拼单子用）
    private struct TodoGroupRows {
        let key: String
        let title: String
        let rows: [[String: Any]]

        init(_ key: String, _ title: String, _ rows: [[String: Any]]) {
            self.key = key
            self.title = title
            self.rows = rows
        }
    }

    /// 一句话里认出来的（假服务器认时间：界面测试用的那几种说法）
    private struct Heard {
        let text: String
        var day: String?
        var time: String?
        var rule: [String: Any]?
        var spans: [[Int]] = []

        init(text: String) {
            self.text = text
        }

        private var source: NSString { text as NSString }

        private func match(_ pattern: String) -> NSTextCheckingResult? {
            try? NSRegularExpression(pattern: pattern).firstMatch(
                in: text, range: NSRange(location: 0, length: source.length))
        }

        private mutating func mark(_ range: NSRange) {
            spans.append([range.location, range.location + range.length])
        }

        /// 今天、明天、后天
        mutating func day(today: String) {
            for (word, offset) in [("今天", 0), ("明天", 1), ("后天", 2)] {
                let range = source.range(of: word)
                guard range.location != NSNotFound else { continue }
                day = PourDate.addDays(today, offset)
                mark(range)
                return
            }
        }

        /// 每周几
        mutating func weekly(today: String) {
            guard let found = match("每周([一二三四五六日])") else { return }
            let weekday =
                ["一", "二", "三", "四", "五", "六", "日"].firstIndex(of: source.substring(with: found.range(at: 1))) ?? 0
            rule = ["kind": "weekly", "days": [weekday]]
            day = StubServer.State.next(.weekly([weekday]), after: PourDate.addDays(today, -1))
            mark(found.range)
        }

        /// 「1分钟后」：现在往后几分钟（界面测试等通知弹出来用）
        mutating func minutesLater() {
            guard let found = match("([0-9]+)分钟后"), let minutes = Int(source.substring(with: found.range(at: 1)))
            else { return }
            let local = PourDate.localDateTime(Date().addingTimeInterval(Double(minutes) * 60), in: .current)
            day = String(local.prefix(10))
            time = String(local.suffix(5))
            mark(found.range)
        }

        /// 上午下午晚上、几点、几点半
        mutating func clock() {
            guard let found = match("(上午|下午|晚上|早上|中午)?([一二两三四五六七八九十]{1,3}|[0-9]{1,2})点(半)?") else { return }
            let part = found.range(at: 1).location == NSNotFound ? "" : source.substring(with: found.range(at: 1))
            var hour = StubServer.State.number(source.substring(with: found.range(at: 2)))
            if ["下午", "晚上"].contains(part), hour < 12 { hour += 12 }
            let half = found.range(at: 3).location != NSNotFound
            time = String(format: "%02d:%02d", hour, half ? 30 : 0)
            mark(found.range)
        }
    }
#endif
