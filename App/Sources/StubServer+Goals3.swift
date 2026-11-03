#if DEBUG
    import Foundation

    /// 3.0 目标的假服务器（界面测试用，-uiTest）：首页、一个目标、GROW、WOOP、每周回顾、我在乎的、理解卡都是 10月27日演示数据原样；
    /// 改动（暂停、完成、回答……）回服务器同样的轻提示，不真的改（真的改在连 5288 的「用手走一遍」里看）
    enum Goals3Stub {
        static let all: [String: String] = [part1, part2, part3, part4].reduce(into: [:]) { out, part in
            out.merge(part) { first, _ in first }
        }

        static func json(_ key: String) -> Any? {
            all[key].flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) }
        }

        /// 编号 → 名字（轻提示里写名字）
        static func title(_ id: Int) -> String {
            let page = (json("/api/goals/\(id)") as? [String: Any])?["page"] as? [String: Any]
            return (page?["card"] as? [String: Any])?["title"] as? String ?? "这个目标"
        }

        static func done(_ toast: String, finished: Bool? = nil) -> [String: Any] {
            var out: [String: Any] = ["toast": toast, "undo": [1]]
            if let finished { out["finished"] = finished }
            return out
        }

        static func act(_ id: Int, _ body: [String: Any]) -> [String: Any] {
            let name = title(id)
            switch body["action"] as? String {
            case "pause": return done("暂停了：\(name)")
            case "resume": return done("继续了：\(name)")
            case "done": return done("「\(name)」放进做到的了")
            case "letgo": return done("放下了：\(name) · 在「放下的」里")
            case "retry": return done("再试试：\(name)，从今天重新算")
            default: return done("改回进行中了：\(name)")
            }
        }

        static func set(_ id: Int, _ body: [String: Any]) -> [String: Any] {
            if let target = body["target"] as? Double { return done("目标值改成 \(Int(target)) 公里，月和周跟着重新分") }
            if let title = body["title"] as? String { return done("名称改成「\(title)」") }
            if body["restPerWeek"] is Int || body["restPerWeek"] is Double {
                return done("改成每周 \(body["restPerWeek"] ?? 2) 次补假，从下周一开始")
            }
            if body["three"] != nil { return done("三句话写在目标页最上面了 · 每个工作日 18:30 提醒你") }
            if let remind = body["remind"] as? [String: Any] {
                if remind["off"] as? Bool == true { return done("关了「\(title(id))」的提醒") }
                return done("改好了：\(remind["text"] ?? "") 提醒你「如果就」")
            }
            if body["care"] != nil { return done("放进「关系」了") }
            return setMore(body) ?? done("改好了")
        }

        /// 3.0 收尾：类别、只算、周期、从哪天算（和服务器 2.19.0 的轻提示一样）
        private static func setMore(_ body: [String: Any]) -> [String: Any]? {
            if let key = body["category"] as? String {
                let names = ["exercise": "运动", "run": "跑步", "sleep": "睡眠", "diet": "饮食", "study": "学习", "work": "工作"]
                return done("类别改成「\(names[key] ?? key)」")
            }
            if let words = body["keywords"] as? [String] {
                return done(words.isEmpty ? "整个类别都算" : "只算名称里带\(words.map { "「\($0)」" }.joined())的记录")
            }
            if let period = body["period"] as? String {
                let label = ["year": "今年", "month": "这个月", "week": "这周"][period] ?? period
                if body["repeat"] as? Bool == true { return done("周期改成「\(period == "week" ? "每周" : "每月")」") }
                let range = ["year": "1月1日–12月31日", "month": "10月1日–10月31日", "week": "10月26日–11月1日"][period] ?? ""
                return done("周期改成「\(label)」（\(range)）")
            }
            if let start = body["start"] as? String, start.count == 10 {
                return done("从 \(Int(start.dropFirst(5).prefix(2)) ?? 0)月\(Int(start.suffix(2)) ?? 0)日 开始算")
            }
            return nil
        }

        /// 跑步那个目标（4）带上设置里能改的（服务器 2.19.0 的 settings.edit）；别的目标照旧，是旧服务器的样子
        static func withEdit(_ detail: Any?) -> Any? {
            guard var detail = detail as? [String: Any], var page = detail["page"] as? [String: Any],
                var settings = page["settings"] as? [String: Any]
            else { return detail }
            let option = { (label: String, period: String, repeats: Bool) -> [String: Any] in
                ["label": label, "period": period, "repeat": repeats, "current": label == "今年"]
            }
            settings["edit"] =
                [
                    "category": "run", "keywords": [String](),
                    "periods": [
                        option("今年", "year", false), option("这个月", "month", false), option("这周", "week", false),
                        option("每月", "month", true), option("每周", "week", true),
                    ],
                    "start": ["value": "2026-09-23", "from": "2026-01-01", "to": "2026-10-27"],
                ] as [String: Any]
            page["settings"] = settings
            detail["page"] = page
            return detail
        }

        /// 手机排的目标通知（10月27日演示数据原样）：跑步的「如果就」每个工作日 18:30、每周回顾周日 20:00
        static var reminders: [String: Any] {
            [
                "ifthen": [
                    [
                        "id": 4, "title": "今年跑 500 公里", "plan": "如果下班觉得累，就先换上跑鞋出门走 10 分钟",
                        "remind": ["kind": "time", "text": "每个工作日 18:30", "at": "18:30", "days": [0, 1, 2, 3, 4]],
                        "line": "每个工作日 18:30 提醒你「如果就」", "paused": false,
                    ] as [String: Any]
                ],
                "weekly": ["weekday": 6, "time": "20:00"], "resume": [Any](),
            ]
        }

        /// 理解卡：演示数据里有的几句原样；别的照「每周 · 坚持」理解成一张卡
        static func understand(_ text: String) -> Any {
            if let known = json("understand:\(text)") { return known }
            let plan: [String: Any] = [
                "title": text, "type": "坚持", "period": "每周", "from": "从你说的「\(text)」算",
                "counted": "还没找到相关的记录，从今天开始算", "quotes": [Any](), "care": "health",
                "op": [
                    "kind": "quantity", "title": text, "period": "week", "repeat": true, "calc": "count", "target": 3,
                ],
            ]
            return ["kind": "plan", "plan": plan, "note": NSNull(), "positive": NSNull()]
        }
    }

    extension StubServer.State {
        /// 3.0 目标的接口（在旧的 /api/goals 前面认）
        func goals3Reply(_ method: String, _ path: String, _ body: [String: Any]) -> Any? {
            guard path.hasPrefix("/api/goals") || path.hasPrefix("/api/care") else { return nil }
            if method == "GET" { return goals3Get(path) }
            return goals3Change(method, path, body) ?? goals3Act(path, body)
        }

        private func goals3Get(_ path: String) -> Any? {
            if path == "/api/goals/reminders" { return Goals3Stub.reminders }
            if path == "/api/goals/4" { return Goals3Stub.withEdit(Goals3Stub.json(path)) }
            if Goals3Stub.all[path] != nil { return Goals3Stub.json(path) }
            if path.hasSuffix("/grow") { return Goals3Stub.json("/api/goals/4/grow") }
            if path.hasSuffix("/woop") { return Goals3Stub.json("/api/goals/4/woop") }
            return nil
        }

        /// 不带编号的写：理解卡、定好、撤销、每周回顾、打分、我想成为
        private func goals3Change(_ method: String, _ path: String, _ body: [String: Any]) -> Any? {
            switch (method, path) {
            case ("POST", "/api/goals/understand"): return Goals3Stub.understand(body["text"] as? String ?? "")
            case ("POST", "/api/goals/plan"):
                return ["id": 99, "ids": [99], "line": "定好了 · 在「坚持」里 · 我在乎的：健康", "big": false]
            case ("POST", "/api/goals/undo"), ("POST", "/api/goals/weekly"): return ["ok": true]
            case ("POST", "/api/goals/weekly/todo"):
                return ["entryId": 9001, "toast": "加上了：10月31日 周六 08:00 \(body["content"] as? String ?? "")"]
            case ("PUT", "/api/care"): return Goals3Stub.json("/api/care")
            case ("POST", _) where path.hasSuffix("/score"):
                return ["toast": "健康这个季度打 \(body["value"] ?? 9) 分", "before": 9]
            case ("POST", _) where path.hasSuffix("/wish"):
                let text = body["text"] as? String ?? "我想成为一个陪儿子踢一下午球也不喘的爸爸"
                return ["wish": ["text": text, "agreed": true, "sources": [Any]()]]
            default: return nil
            }
        }

        /// 一个目标上的操作：暂停、改、里程碑、回答、GROW
        private func goals3Act(_ path: String, _ body: [String: Any]) -> Any? {
            let parts = path.split(separator: "/").map(String.init)
            guard parts.count == 4, let id = Int(parts[2]) else { return nil }
            switch parts[3] {
            case "act": return Goals3Stub.act(id, body)
            case "set": return Goals3Stub.set(id, body)
            case "milestone":
                let last = (body["index"] as? Int) == 3
                return Goals3Stub.done(last ? "做到了：\(Goals3Stub.title(id))" : "勾上了：第三部分 人类的融合统一", finished: last)
            case "ask":
                let counts = body["counts"] as? Bool ?? false
                return Goals3Stub.done(counts ? "记住了：算进《人类简史》，到第 260 页" : "记住了：这 40 页不算")
            case "grow":
                let pause = body["key"] as? String == "pause"
                return Goals3Stub.done(pause ? "先停一个月：到 11月27日，这期间不提醒、不算落后" : "改好了：改成周末长跑，从 11月2日重新开始算")
            default: return nil
            }
        }
    }
#endif
