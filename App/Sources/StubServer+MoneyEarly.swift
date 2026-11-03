#if DEBUG
    import Foundation

    extension MoneyStub {
        /// 刚开始用 3 天（启动参数 -moneyEarly，01 需求文档 5.8 第 4 条）：10月18日才开始记，只有这 3 天的钱；
        /// 还不能和上个月比（11月18日起），没有固定的、收入、预算、值不值，钱和你的日子还在攒
        static func earlyHome() -> [String: Any] {
            var month = json(Self.month) as? [String: Any] ?? [:]
            let keep = { (list: Any?) in
                ((list as? [[String: Any]]) ?? []).filter { ($0["day"] as? String ?? "") >= "2026-10-18" }
            }
            let days = keep(month["days"])
            let items = keep(month["items"]).filter { $0["kind"] as? String == "daily" }
            let spent = days.reduce(0.0) { $0 + ($1["spent"] as? Double ?? 0) }
            month["started"] = "2026-10-18"
            month["early"] = ["days": 3, "daily": items.count]
            month["days"] = days
            month["items"] = items
            month["spent"] = spent
            month["count"] = items.count
            month["counts"] = ["daily": items.count]
            month["compare"] = NSNull()
            month["compareFrom"] = "2026-11-18"
            month["prevMonth"] = NSNull()
            month["fixed"] = [
                "paid": 0, "paidCount": 0, "upcoming": 0, "next": [Any](), "monthly": 0, "series": [Any](),
            ]
            month["income"] = ["total": 0, "items": [Any]()]
            month["domainNote"] = NSNull()
            var overview = json(Self.overview) as? [String: Any] ?? [:]
            overview["watch"] = [Any]()
            overview["who"] = NSNull()
            overview["whoCount"] = items.count
            overview["worth"] = ["good": [Any](), "regret": [Any]()]
            overview["renqing"] = NSNull()
            var sum = 0.0
            let current = (1...20).map { number -> Double in
                let day = String(format: "2026-10-%02d", number)
                sum += days.first { $0["day"] as? String == day }?["spent"] as? Double ?? 0
                return sum
            }
            return [
                "month": month, "pace": ["current": current, "previous": NSNull()], "budgets": [Any](),
                "overview": overview,
                "findings": ["recorded": items.count, "early": true, "week": "2026-10-19", "findings": [Any]()],
            ]
        }
    }
#endif
