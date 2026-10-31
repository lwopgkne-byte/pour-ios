#if DEBUG
    import Foundation

    /// 假服务器的 3.0「我的」（服务器 server/src/routes/hub.ts）：一页的数、常用的格子
    extension StubServer.State {
        /// 服务器的默认常用（shared/src/hub.ts DEFAULT_HUB_FAVORITES）
        static let defaultHubFavorites = [
            "todos", "money", "mood", "insights", "review", "goals", "library", "calendar",
        ]

        mutating func hubReply(_ method: String, _ path: String, _ body: [String: Any]) -> Any? {
            switch (method, path) {
            case ("GET", "/api/me/hub"):
                let days = Set(notes.compactMap { $0["day"] as? String }).count
                return [
                    "days": max(days, 63), "notes": max(notes.count, 377),
                    "known": ["people": 12, "habits": 8, "places": 5],
                    "favorites": hubFavorites ?? Self.defaultHubFavorites, "custom": hubFavorites != nil,
                    "badges": [["tile": "watch", "text": "2"], ["tile": "review", "text": "新"]],
                ]
            case ("PUT", "/api/me/hub/favorites"):
                // 和服务器一样：只留认得的、不重复、最多 8 个
                var seen = Set<String>()
                let wanted = (body["favorites"] as? [String] ?? []).filter { seen.insert($0).inserted }
                hubFavorites = Array(wanted.prefix(8))
                return ["favorites": hubFavorites ?? []]
            default:
                return nil
            }
        }

        /// 说了「全部断网」以后，所有请求都连不上（测没网时页面用上次存的、顶上的细条）
        mutating func offlineReply(_ body: [String: Any]) -> StubServer.Reply? {
            if (body["text"] as? String)?.contains("全部断网") == true { offlineAll = true }
            return offlineAll ? StubServer.Reply(offline: true) : nil
        }
    }
#endif
