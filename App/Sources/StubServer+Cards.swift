#if DEBUG
    import Foundation

    extension StubServer.State {
        /// 我的卡片（docs/模块/产品优化.md R3）：样张里先放三张（一个数、一张清单、一张小图），平常没有
        static func sampleCards() -> [[String: Any]] {
            guard sample != nil || CanvasSamples.isOn else { return [] }
            return [
                [
                    "id": 1, "title": "这个月的咖啡", "show": "number", "basis": "本月 · 带「咖啡」的 · 多少杯",
                    "value": "12 杯", "empty": false,
                ],
                [
                    "id": 2, "title": "今年读的书", "show": "list", "basis": "今年 · 带「《」的 · 说到的东西",
                    "items": [
                        ["text": "《人类简史》", "day": "2026-10-20", "entryId": 1007],
                        ["text": "《三体》", "day": "2026-09-02", "entryId": 1008],
                    ],
                    "empty": false,
                ],
                [
                    "id": 3, "title": "最近的睡眠", "show": "chart", "basis": "最近 7 天 · 睡眠 · 时长",
                    "value": "48 小时 30 分",
                    "bars": [
                        ["label": "周一", "value": 420], ["label": "周二", "value": 390], ["label": "周三", "value": 450],
                        ["label": "周四", "value": 400], ["label": "周五", "value": 380], ["label": "周六", "value": 480],
                        ["label": "周日", "value": 390],
                    ],
                    "empty": false,
                ],
            ]
        }

        /// 我的语录（docs/模块/产品优化.md R4）
        static var sampleQuotes: [[String: Any]] {
            [
                ["entryId": 3301, "text": "付出不亚于任何人的努力", "day": "2026-10-12", "noteId": 3301, "asked": true],
                ["entryId": 3302, "text": "先做完，再慢慢修改", "day": "2026-10-08", "noteId": 3302, "asked": false],
            ]
        }

        /// 卡片：长按改名字、放到最前、不要了、放回来；语录：全部、不放进语录
        mutating func cardsReply(_ method: String, _ path: String, _ body: [String: Any]) -> Any? {
            if path.hasPrefix("/api/quotes") { return quotesReply(path, body) }
            guard path.hasPrefix("/api/cards/") else { return nil }
            let parts = path.split(separator: "/").map(String.init)
            guard parts.count >= 3, let id = Int(parts[2]) else { return nil }
            switch (method, parts.count == 4 ? parts[3] : "") {
            case ("PATCH", _): patchCard(id, body)
            case ("DELETE", _):
                if let index = cards.firstIndex(where: { $0["id"] as? Int == id }) {
                    trashCards.append(cards.remove(at: index))
                }
            case ("POST", "restore"):
                if let index = trashCards.firstIndex(where: { $0["id"] as? Int == id }) {
                    cards.append(trashCards.remove(at: index))
                }
            default: return nil
            }
            return ["ok": true]
        }

        private mutating func patchCard(_ id: Int, _ body: [String: Any]) {
            guard let index = cards.firstIndex(where: { $0["id"] as? Int == id }) else { return }
            if let title = body["title"] as? String { cards[index]["title"] = title }
            if body["to"] as? String == "first" { cards.insert(cards.remove(at: index), at: 0) }
        }

        private mutating func quotesReply(_ path: String, _ body: [String: Any]) -> Any? {
            if path == "/api/quotes/hidden", let id = body["entryId"] as? Int, body["hidden"] as? Bool == true {
                quotes.removeAll { $0["entryId"] as? Int == id }
            }
            return ["quotes": quotes]
        }
    }
#endif
