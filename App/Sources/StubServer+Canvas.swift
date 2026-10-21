#if DEBUG
    import Foundation
    import PourCore

    extension StubServer.State {
        /// 服务器的基础类别
        static var categories: [[String: Any]] {
            [
                [
                    "key": "sleep", "name": "睡眠", "emoji": "😴", "color": "purple", "parent": NSNull(),
                    "measure": "duration",
                ],
                [
                    "key": "exercise", "name": "运动", "emoji": "🏃", "color": "green", "parent": NSNull(),
                    "measure": "duration",
                ],
                [
                    "key": "run", "name": "跑步", "emoji": "🏃", "color": "green", "parent": "exercise",
                    "measure": "公里",
                ],
                [
                    "key": "diet", "name": "饮食", "emoji": "🍽", "color": "orange", "parent": NSNull(),
                    "measure": "duration",
                ],
                [
                    "key": "study", "name": "学习", "emoji": "📚", "color": "blue", "parent": NSNull(),
                    "measure": "duration",
                ],
                [
                    "key": "work", "name": "工作", "emoji": "💼", "color": "brown", "parent": NSNull(),
                    "measure": "duration",
                ],
                [
                    "key": "other", "name": "其他", "emoji": "📌", "color": "gray", "parent": NSNull(),
                    "measure": "count",
                ],
            ]
        }

        /// 画布 2.0 的样张（docs/模块/生活画布2.0.md 第 5 节）：启动参数「-canvasSample 带孩子」，
        /// 今天换成那个人的一天（记录、一句话总结、推进的目标），截图验收用。没有这个参数时什么都不变
        static let sample: CanvasSample? = {
            let arguments = ProcessInfo.processInfo.arguments
            guard let index = arguments.firstIndex(of: "-canvasSample"), index + 1 < arguments.count else { return nil }
            return CanvasSample.all[arguments[index + 1]]
        }()

        /// 样张那一天的记录：日子换成今天，几点说的心情按这台手机的时区
        static func sampleEntries(today: String) -> [[String: Any]] {
            guard let sample else { return [] }
            return CanvasSample.parse(sample.entries, today: today).enumerated().map { index, item in
                entry(item, id: 1000 + index, today: today)
            }
        }

        /// 样张的类别：十个生活领域和运动的子类别「力量」（真的服务器是按名字建的，key 每个人不一样）
        static var sampleCategories: [[String: Any]] {
            sample == nil ? [] : CanvasSample.parse(CanvasSample.domains, today: "")
        }

        /// 补齐一条记录：编号、日子、状态（有 "question" 的是待确认）、从哪段话来（心情的 "at" 是几点说的）
        private static func entry(_ item: [String: Any], id: Int, today: String) -> [String: Any] {
            var entry = item
            entry["id"] = id
            entry["day"] = today
            entry["confidence"] = item["question"] == nil ? 0.95 : 0.6
            entry["status"] = item["question"] == nil ? "ok" : "confirm"
            let clock = (item["at"] as? String ?? "12:00").split(separator: ":").compactMap { Int($0) }
            var parts = DateComponents()
            parts.year = Int(today.prefix(4))
            parts.month = Int(today.dropFirst(5).prefix(2))
            parts.day = Int(today.suffix(2))
            parts.hour = clock.first
            parts.minute = clock.last
            let said = Calendar.current.date(from: parts) ?? Date()
            entry["sources"] = [
                [
                    "noteId": id, "span": "", "action": "created", "text": "",
                    "createdAt": ISO8601DateFormatter().string(from: said),
                ]
            ]
            entry["at"] = nil
            return entry
        }
    }

    /// 一个人的一天：记录、推进的目标（都是 JSON，{D} 是今天、{Y} 是昨天）、一句话总结
    struct CanvasSample: Sendable {
        let entries: String
        let summary: String?
        let goals: String

        static let all: [String: CanvasSample] = [
            "上班族": office, "带孩子": mom, "大学生": student, "退休老人": elder, "开店": shop, "感悟": quiet,
        ]

        /// 这一天推进的目标
        var goalList: [[String: Any]] { Self.parse(goals, today: "") }

        /// JSON 换上日子以后解出来
        static func parse(_ text: String, today: String) -> [[String: Any]] {
            let filled =
                today.isEmpty
                ? text : text.replacing("{D}", with: today).replacing("{Y}", with: PourDate.addDays(today, -1))
            return (try? JSONSerialization.jsonObject(with: Data(filled.utf8))) as? [[String: Any]] ?? []
        }

        /// 十个生活领域（名字、emoji、颜色、计量照服务器建的）和「力量」
        static let domains = #"""
            [{"key":"c-baby","name":"育儿","emoji":"🍼","color":"pink","measure":"count"},
            {"key":"c-pet","name":"宠物","emoji":"🐕","color":"orange","measure":"count"},
            {"key":"c-health","name":"健康","emoji":"🩺","color":"red","measure":"count"},
            {"key":"c-family","name":"家人朋友","emoji":"👨‍👩‍👧","color":"pink","measure":"count"},
            {"key":"c-hobby","name":"兴趣","emoji":"🎨","color":"yellow","measure":"duration"},
            {"key":"c-fun","name":"娱乐","emoji":"🎬","color":"purple","measure":"duration"},
            {"key":"c-house","name":"家务","emoji":"🧹","color":"brown","measure":"duration"},
            {"key":"c-trip","name":"出行","emoji":"🚗","color":"blue","measure":"duration"},
            {"key":"c-shop","name":"购物","emoji":"🛒","color":"orange","measure":"count"},
            {"key":"c-task","name":"办事","emoji":"📋","color":"gray","measure":"count"},
            {"key":"strength","name":"力量","emoji":"🏋️","color":"green","parent":"exercise","measure":"duration"}]
            """#
    }
#endif
