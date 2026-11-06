#if DEBUG
    import Foundation
    import PourAPI
    import PourCore

    /// 假服务器的待办 2.0（服务器 services/todo-page.ts）：分好组的单子；放进哪一格（quadrant、quadrantByAI）、
    /// 上午 / 下午 / 晚上（window）、以后再说（someday：没有日子，排在「以后」最后，不算过点）
    extension StubServer.State {
        func todoPage() -> [String: Any] {
            let rows = entries.filter { $0["kind"] as? String == "todo" }.map(row)
            let tomorrow = PourDate.addDays(today, 1)
            let sunday = PourDate.addDays(today, 6 - PourDate.weekdayMon0(today))
            let open = { (row: [String: Any]) in row["done"] as? Bool != true && row["someday"] as? Bool != true }
            let day = { (row: [String: Any]) in row["day"] as? String ?? "" }
            // 同一天里你排过的按你排的（没排过的在前），别的按日子、钟点（服务器 byDayThenClock）
            let rank = { (row: [String: Any]) in (row["order"] as? Int).map { String(format: "1%05d", $0) } ?? "0" }
            let sorted = { (list: [[String: Any]], newestFirst: Bool) in
                list.sorted { lhs, rhs in
                    let left = "\(day(lhs))\(rank(lhs))\(lhs["remindAt"] as? String ?? "99")\(lhs["id"] as? Int ?? 0)"
                    let right = "\(day(rhs))\(rank(rhs))\(rhs["remindAt"] as? String ?? "99")\(rhs["id"] as? Int ?? 0)"
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
                    "later", "以后",
                    sorted(rows.filter { open($0) && day($0) > max(sunday, tomorrow) }, false)
                        + rows.filter { $0["done"] as? Bool != true && $0["someday"] as? Bool == true }),
                TodoGroupRows(
                    "done", "已完成",
                    rows.filter { $0["done"] as? Bool == true }.sorted {
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

        /// 说一句「下午回复客户电话」（待办 2.0 第 10 步的结果卡片）：建一件待办——AI 猜放进马上做、只说了下午（时间段），
        /// 收据带上它现在的样子
        mutating func sayTodo(_ text: String, noteId: Int) -> [String: Any]? {
            if text.contains("叫我起床") { return sayAlarm(text, noteId: noteId) }
            guard text.contains("回复客户电话") else { return nil }
            let id = nextId
            nextId += 1
            let data: [String: Any] = [
                "content": "回复客户电话", "done": false, "due": today, "window": "afternoon", "quadrant": 1,
                "quadrantByAI": true,
            ]
            entries.append([
                "id": id, "day": today, "kind": "todo", "category": "todo", "confidence": 0.9, "status": "ok",
                "data": data,
                "sources": [
                    [
                        "noteId": noteId, "span": text, "action": "created", "text": text,
                        "createdAt": ISO8601DateFormatter().string(from: Date()),
                    ]
                ],
            ])
            return [
                "action": "created", "kind": "todo", "entryId": id, "text": "📝 待办：回复客户电话", "pending": false,
                "todo": [
                    "content": "回复客户电话", "day": today, "time": NSNull(), "window": "afternoon", "quadrant": 1,
                    "guessed": true,
                ],
            ]
        }

        /// 说一句「明天早上7点叫我起床」（响铃，产品主人 2026-11-06）：明天 07:00 的「起床」，到点像闹钟一样响
        mutating func sayAlarm(_ text: String, noteId: Int) -> [String: Any] {
            let id = nextId
            nextId += 1
            let day = PourDate.addDays(today, 1)
            entries.append([
                "id": id, "day": today, "kind": "todo", "category": "todo", "confidence": 0.95, "status": "ok",
                "data": ["content": "起床", "done": false, "due": day, "remindAt": "\(day)T07:00", "alarm": true],
                "sources": [
                    [
                        "noteId": noteId, "span": text, "action": "created", "text": text,
                        "createdAt": ISO8601DateFormatter().string(from: Date()),
                    ]
                ],
            ])
            return [
                "action": "created", "kind": "todo", "entryId": id, "text": "📝 待办：起床", "pending": false,
                "todo": [
                    "content": "起床", "day": day, "time": "07:00", "window": NSNull(), "quadrant": 0, "guessed": false,
                    "alarm": true,
                ],
            ]
        }

        /// 挤满了的一天（「-todoCrowded」，四象限、时间线的边界情况，2026-11-06 产品主人看到四象限被撑变形）：
        /// 马上做 6 件（名字长的、快到点的、同一分钟两件）、排时间 5 件、快速办 1 件、放一放 1 件、还没分 3 件、下午的 1 件
        static func crowdedTodos(today: String) -> [[String: Any]] {
            let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
            let soon = String(format: "%02d:%02d", now.hour ?? 9, min(59, (now.minute ?? 0) + 2))
            // 名字 · 哪一格 · 别的字段（钟点、时间段）
            let items: [[String: Any]] = [
                ["content": "发内测版本", "quadrant": 1, "remindAt": "\(today)T\(soon)"],
                ["content": "喝水", "quadrant": 1, "remindAt": "\(today)T\(soon)"],
                ["content": "把会员改版的 PRD 发给研发，顺便约周五评审", "quadrant": 1, "remindAt": "\(today)T17:30"],
                ["content": "给客户回电话", "quadrant": 1, "window": "afternoon"],
                ["content": "接孩子", "quadrant": 1, "remindAt": "\(today)T17:00"], ["content": "交周报", "quadrant": 1],
                ["content": "写季度总结", "quadrant": 2], ["content": "去医院复查", "quadrant": 2, "remindAt": "\(today)T15:00"],
                ["content": "看完那本书", "quadrant": 2, "window": "evening"], ["content": "整理照片", "quadrant": 2],
                ["content": "学吉他", "quadrant": 2], ["content": "交水费", "quadrant": 3],
                ["content": "整理衣柜", "quadrant": 4],
                ["content": "买牛奶"], ["content": "寄快递"], ["content": "订机票"], ["content": "喝茶", "window": "afternoon"],
            ]
            return items.enumerated().map { index, item in
                var data: [String: Any] = ["done": false, "due": today]
                data.merge(item) { _, new in new }
                return [
                    "id": 800 + index, "day": today, "kind": "todo", "category": "todo", "confidence": 1,
                    "status": "ok", "data": data, "sources": [[String: Any]](),
                ]
            }
        }

        /// 一行多带的几样（待办 2.0：格子、时间段、以后再说、你排的顺序；响铃只对有钟点的是 true）
        static func todoTwoRow(_ data: [String: Any]) -> [String: Any] {
            [
                "quadrant": orNull(data["quadrant"]), "quadrantByAI": orNull(data["quadrantByAI"]),
                "window": orNull(data["window"]), "someday": orNull(data["someday"]), "order": orNull(data["order"]),
                "alarm": data["alarm"] as? Bool == true && data["remindAt"] is String,
            ]
        }

        /// 调整顺序：这几件按给的先后记成 0、1、2……
        mutating func order(_ ids: [Int]) -> [String: Any] {
            for (index, id) in ids.enumerated() {
                guard let at = entries.firstIndex(where: { $0["id"] as? Int == id && $0["kind"] as? String == "todo" })
                else { continue }
                var data = entries[at]["data"] as? [String: Any] ?? [:]
                data["order"] = index
                entries[at]["data"] = data
            }
            return ["ok": true]
        }

        /// 改格子和以后再说（services/todo-page.ts edited）：自己选的格不再是猜的；以后再说去掉日子、钟点、时间段，
        /// 给了日子就不再是以后再说。回 true：放进了以后再说，日子钟点不用再改
        static func editTodoTwo(_ data: inout [String: Any], _ change: [String: Any]) -> Bool {
            if let alarm = change["alarm"] as? Bool { data["alarm"] = alarm ? true : nil }
            if let quadrant = change["quadrant"] as? Int {
                data["quadrant"] = quadrant == 0 ? nil : quadrant
                data["quadrantByAI"] = nil
            }
            if change["someday"] as? Bool == true {
                data["someday"] = true
                for key in ["due", "remindAt", "window"] { data[key] = nil }
                return true
            }
            if change["day"] is String || change["someday"] as? Bool == false { data["someday"] = nil }
            return false
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
#endif
