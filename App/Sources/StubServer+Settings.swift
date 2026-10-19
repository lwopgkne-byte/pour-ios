#if DEBUG
    import Foundation
    import PourCore

    extension StubServer.State {
        /// 设置页的接口；提醒改了的那几项盖上去（网页版服务器 PUT /api/reminders）
        mutating func settingsReply(_ method: String, _ path: String, _ body: [String: Any]) -> Any? {
            switch (method, path) {
            case ("GET", "/api/reminders"): return reminders
            case ("PUT", "/api/reminders"):
                reminders.merge(body) { _, new in new }
                return reminders
            default: return Self.settings(method, path)
            }
        }

        /// 设置页的接口：都是刚装好、什么都还没设置过的样子（照网页版服务器回的样子）
        static func settings(_ method: String, _ path: String) -> Any? {
            if method == "POST", ["/api/llm/consent", "/api/llm/dismiss-setup"].contains(path) { return ["ok": true] }
            return method == "GET" ? reads[path] : nil
        }

        private static var reads: [String: Any] {
            [
                "/api/llm/status": llmStatus,
                "/api/settings/lan": [
                    "local": false, "pinEnabled": false, "pinUnset": true, "urls": ["http://192.168.1.8:5188"],
                    "rememberDays": 30,
                ] as [String: Any],
                "/api/growth": growth,
                "/api/audit/status": [
                    "model": "deepseek-v4-pro", "capCny": 5, "monthCostCny": 0, "exam": NSNull(), "examRunning": false,
                    "week": ["found": 0, "confirmed": 0, "manual": 0], "decided": ["confirmed": 0, "dismissed": 0],
                    "lastRun": NSNull(),
                ] as [String: Any],
                "/api/evals": [
                    "runs": [Any](),
                    "progress": [
                        "running": false, "startedAt": NSNull(), "done": 0, "total": NSNull(), "error": NSNull(),
                    ],
                ] as [String: Any],
                "/api/eval-candidates": ["candidates": [Any](), "classifying": false] as [String: Any],
                "/api/data/status": [
                    "mode": "real", "backups": [Any](), "backupCount": 0, "dayBoundary": 240, "notes": 0,
                ] as [String: Any],
                "/api/llm/runs": ["runs": [Any]()],
                "/api/review": ["items": [Any]()],
            ]
        }

        private static var llmStatus: [String: Any] {
            [
                "baseUrl": "https://api.deepseek.com", "model": "deepseek-v4-pro", "modelSource": "default",
                // 平时的样子：电脑上已经填好了密钥、确认过（画布上不出「连接大模型」）
                "keySource": "settings", "keyMasked": "sk-…a1b2", "configured": true, "consentAccepted": true,
                "showSetup": false, "confidenceThreshold": 0.8, "monthlyTokenLimit": 0, "local": false,
                "usage": [
                    "month": "2026-10", "calls": 0, "promptTokens": 0, "cacheHitTokens": 0, "completionTokens": 0,
                    "totalTokens": 0, "costCny": 0, "costPartial": false, "byFeature": [Any](),
                ] as [String: Any],
                "queue": ["pending": 0, "blocker": NSNull()] as [String: Any],
            ]
        }

        /// 提醒刚装好的样子（改了存在 State.reminders 里）
        static var defaultReminders: [String: Any] {
            [
                "morning": ["enabled": true, "time": "07:30"], "evening": ["enabled": true, "time": "21:30"],
                "warning": ["enabled": true, "time": "20:30"], "weekly": ["enabled": true],
                "monthly": ["enabled": true],
                "dnd": ["enabled": true, "from": "23:00", "to": "07:00"] as [String: Any],
                "bedtime": "00:00", "channels": ["serverchan": true, "bark": true],
                "keys": ["serverchan": NSNull(), "bark": NSNull()] as [String: Any],
            ]
        }

        private static var growth: [String: Any] {
            [
                "weeks": [["start": "2026-10-12", "notes": 0, "corrections": 0, "asks": 0]],
                "dictionary": ["total": 0, "thisWeek": 0], "about": ["right": 0, "wrong": 0],
                "checklist": ["general": 340, "personal": 0], "knows": ["people": 0, "habits": 0, "places": 0],
            ]
        }

        /// 每日回顾：今天早上 10 点来的，回顾的是昨天
        static var dailyReview: [String: Any] {
            let today = PourDate.logicalDay(Date(), in: .current)
            let morning = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
            return [
                "id": 1, "kind": "daily", "createdAt": ISO8601DateFormatter().string(from: morning),
                "title": "昨天", "body": "睡了 7 小时，跑步 5 公里。",
                "daily": [
                    "day": PourDate.addDays(today, -1), "overview": "睡了 7 小时，跑步 5 公里。", "observation": NSNull(),
                    "facts": "",
                ],
            ]
        }
    }
#endif
