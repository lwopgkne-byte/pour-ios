#if DEBUG
    import Foundation
    import PourCore

    /// 假服务器的健康（docs/模块/产品优化.md R5）：存下送来的；画布上那一天放进锻炼、那一觉（只能看，编号是负数）和步数。
    /// 真的服务器还要和你说的比是不是同一次（shared/src/health-app.ts），这里不比
    extension StubServer.State {
        mutating func healthReply(_ method: String, _ path: String, _ body: [String: Any]) -> [String: Any]? {
            if path == "/api/health/page" { return Self.healthPage }
            guard path == "/api/health" else { return nil }
            switch method {
            case "PUT":
                health = body
                return ["ok": true, "changed": [today]]
            case "DELETE":
                health = nil
                return ["ok": true]
            default:
                return ["connected": health != nil, "syncedAt": health == nil ? NSNull() : "2026-10-26T08:00:00.000Z"]
            }
        }

        /// 健康一页（服务器 /api/health/page）：照 5288 演示数据拿的——昨天的步数（今天手机还没送来）、昨晚那一觉、四次锻炼
        static var healthPage: [String: Any] {
            [
                "connected": true, "syncedAt": "2026-11-02T20:17:03.362Z", "today": "2026-11-03",
                "steps": ["day": "2026-11-02", "count": 6039, "said": false, "goal": 8000],
                "sleep": [
                    "day": "2026-11-02", "label": "睡觉", "start": "2026-11-02T00:10", "end": "2026-11-02T07:00",
                    "minutes": 410, "km": NSNull(), "said": true, "fromHealth": ["时长"],
                ],
                "workouts": [
                    [
                        "day": "2026-11-01", "label": "游泳", "start": "2026-11-01T15:00", "end": "2026-11-01T16:00",
                        "minutes": 60, "km": NSNull(), "said": true, "fromHealth": [String](),
                    ],
                    [
                        "day": "2026-10-31", "label": "跑步", "start": "2026-10-31T07:00", "end": "2026-10-31T07:50",
                        "minutes": 50, "km": 8.4, "said": true, "fromHealth": ["距离"],
                    ],
                    [
                        "day": "2026-10-30", "label": "走路", "start": "2026-10-30T20:16", "end": "2026-10-30T20:52",
                        "minutes": 36, "km": 3.1, "said": false, "fromHealth": [String](),
                    ],
                ],
            ]
        }

        /// 这一天健康来的记录和步数
        func healthOf(_ day: String) -> (entries: [[String: Any]], steps: Int?) {
            guard let health else { return ([], nil) }
            let local = { (iso: Any?) in Self.local(iso as? String ?? "") }
            var entries: [[String: Any]] = []
            for (index, workout) in (health["workouts"] as? [[String: Any]] ?? []).enumerated() {
                let start = local(workout["start"])
                guard start.hasPrefix(day) else { continue }
                var data: [String: Any] = [
                    "label": workout["activity"] as? String == "running" ? "跑步" : "锻炼", "start": start,
                    "end": local(workout["end"]), "durationMin": workout["durationMin"] ?? 0,
                ]
                if let distance = workout["km"] as? Double {
                    data["metrics"] = [["name": "距离", "value": distance, "unit": "公里"]]
                }
                entries.append(Self.healthEntry(id: -(index + 1), day: day, category: "run", data: data))
            }
            let sleep = (health["sleep"] as? [[String: Any]] ?? []).filter { local($0["end"]).hasPrefix(day) }
            if let first = sleep.first, let last = sleep.last {
                let start = local(first["start"])
                let end = local(last["end"])
                let data: [String: Any] = [
                    "label": "睡觉", "start": start, "end": end, "durationMin": PourDate.minutesBetween(start, end),
                ]
                entries.append(Self.healthEntry(id: -100, day: day, category: "sleep", data: data))
            }
            let steps = (health["steps"] as? [[String: Any]] ?? []).filter { local($0["start"]).hasPrefix(day) }
                .reduce(0) { $0 + ($1["count"] as? Int ?? 0) }
            return (entries, steps > 0 ? steps : nil)
        }

        private static func healthEntry(id: Int, day: String, category: String, data: [String: Any]) -> [String: Any] {
            [
                "id": id, "day": day, "kind": "event", "category": category, "data": data, "confidence": 1,
                "status": "ok", "sources": [Any](), "origin": "health",
            ]
        }

        /// ISO → 这台手机时区里的「2026-10-26T07:02」
        private static func local(_ iso: String) -> String {
            guard let date = try? Date(iso, strategy: .iso8601) else { return "" }
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let two = { (value: Int?) in String(format: "%02d", value ?? 0) }
            return "\(parts.year ?? 0)-\(two(parts.month))-\(two(parts.day))T\(two(parts.hour)):\(two(parts.minute))"
        }
    }
#endif
