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

        /// 一行多带的四样
        static func todoTwoRow(_ data: [String: Any]) -> [String: Any] {
            [
                "quadrant": orNull(data["quadrant"]), "quadrantByAI": orNull(data["quadrantByAI"]),
                "window": orNull(data["window"]), "someday": orNull(data["someday"]),
            ]
        }

        /// 改格子和以后再说（services/todo-page.ts edited）：自己选的格不再是猜的；以后再说去掉日子、钟点、时间段，
        /// 给了日子就不再是以后再说。回 true：放进了以后再说，日子钟点不用再改
        static func editTodoTwo(_ data: inout [String: Any], _ change: [String: Any]) -> Bool {
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
