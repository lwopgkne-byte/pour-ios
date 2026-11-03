#if DEBUG
    import Foundation

    extension StubServer.State {
        /// 3.0 感悟页（/api/insights、今天重温、一条感悟、收藏）：5288 演示数据的 13 句感悟（7 句语录）；
        /// 今天重温先是一个月前的今天那句，「换一句」按顺序轮着换
        func insightsReply(_ method: String, _ url: URL) -> Any? {
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let value = { (name: String) in query.first { $0.name == name }?.value }
            let path = url.path
            switch (method, path) {
            case ("GET", "/api/insights"): return InsightsStub.page(query: value("q"))
            case ("GET", "/api/insights/today"):
                return value("next") == "1" ? InsightsStub.next() : InsightsStub.current()
            case ("GET", _) where path.hasPrefix("/api/insights/"):
                return Int(path.dropFirst("/api/insights/".count)).flatMap(InsightsStub.detail)
            case ("POST", _) where path.hasPrefix("/api/insights/") && path.hasSuffix("/star"):
                return ["ok": true]
            default: return nil
            }
        }
    }

    /// 感悟页的演示数据（5288 演示服务器拿的，原样）
    enum InsightsStub {
        static func json(_ text: String) -> Any {
            (try? JSONSerialization.jsonObject(with: Data(text.utf8))) ?? [String: Any]()
        }

        /// 「换一句」换到第几句了
        nonisolated(unsafe) static var turn = 0

        static var all: [[String: Any]] {
            (json(Self.list) as? [String: Any])?["insights"] as? [[String: Any]] ?? []
        }

        /// 搜：字面上有就算（真的服务器还按意思找）
        static func page(query: String?) -> Any {
            var page = json(Self.list) as? [String: Any] ?? [:]
            if let query, !query.isEmpty {
                page["insights"] = all.filter { item in
                    let tags = item["tags"] as? [String] ?? []
                    return "\(item["quote"] as? String ?? "") \(tags.joined(separator: " "))".contains(query)
                }
            }
            return page
        }

        /// 换一句：按顺序轮着换（今天重温那句以外的）
        static func next() -> Any {
            turn += 1
            return current()
        }

        /// 今天重温现在是哪一句：没换过是一个月前的今天那句；换过以后一天里都是换到的那句（和真的服务器一样）
        static func current() -> Any {
            guard turn > 0, !all.isEmpty else { return json(Self.today) }
            let item = all[turn % all.count]
            return ["insight": item, "ago": "\(turn * 3 + 5) 天前你说", "said": said(item), "related": [Any]()]
        }

        /// 一条感悟：今天重温那句原样；别的原话就是「今天……」+ 那句
        static func detail(_ id: Int) -> Any? {
            if id == 244 { return json(Self.today) }
            guard let item = all.first(where: { $0["id"] as? Int == id }) else { return nil }
            let related = ((json(Self.today) as? [String: Any])?["related"] as? [Any])?.prefix(2) ?? []
            return ["insight": item, "ago": "16 天前你说", "said": said(item), "related": Array(related)]
        }

        private static func said(_ item: [String: Any]) -> String {
            "今天想了想 \(item["quote"] as? String ?? "")"
        }

        static let list = #"""
            {"insights":[{"id":587,"day":"2026-10-29","title":"陪儿子就只陪儿子","quote":"陪儿子的时候 就只陪儿子","tags"\#
            :["家人","专注"],"noteId":365,"starred":true,"saying":true},{"id":571,"day":"2026-10-28","titl\#
            e":"专注比时间长更重要","quote":"关掉消息专心做一件事 两个小时顶一天 以后应该每天留出这么一段","tags":["专注","效率"],"noteId":359,"\#
            starred":true,"saying":false},{"id":522,"day":"2026-10-24","title":"陪孩子不在于时间长","quote":"陪儿\#
            子二十分钟 手机放远一点 比陪一下午心不在焉强","tags":["育儿","专注"],"noteId":335,"starred":false,"saying":false},{\#
            "id":510,"day":"2026-10-23","title":"少做比多做难","quote":"少做一个功能 往往比多做一个更难","tags":["工作","取舍"]\#
            ,"noteId":329,"starred":true,"saying":true},{"id":472,"day":"2026-10-20","title":"读书让我安静",\#
            "quote":"睡前读半小时书 比刷手机睡得踏实","tags":["阅读","睡眠"],"noteId":311,"starred":false,"saying":false}\#
            ,{"id":445,"day":"2026-10-18","title":"累的时候先休息","quote":"上线熬到三点多 今天什么都不想干 与其硬撑不如早点睡","tags\#
            ":["精力","休息"],"noteId":296,"starred":false,"saying":false},{"id":423,"day":"2026-10-16","t\#
            itle":"慢慢来比较快","quote":"慢慢来 比较快","tags":["心态"],"noteId":286,"starred":true,"saying":true},\#
            {"id":388,"day":"2026-10-13","title":"手机吃掉了晚上","quote":"晚上又刷了两个小时手机 什么都没干成 下次应该放客厅充电","tag\#
            s":["手机","时间"],"noteId":268,"starred":false,"saying":false},{"id":336,"day":"2026-10-09","\#
            title":"用户说的不一定是要的","quote":"用户说的不一定是用户要的","tags":["工作","用户"],"noteId":243,"starred":true,\#
            "saying":true},{"id":327,"day":"2026-10-08","title":"早睡的第二天效率高","quote":"昨晚十一点就睡了 今天上午做事特别\#
            顺","tags":["睡眠","效率"],"noteId":237,"starred":false,"saying":false},{"id":269,"day":"2026-1\#
            0-03","title":"先想清楚为什么做","quote":"先想清楚为什么做 再想做什么","tags":["工作","方法"],"noteId":203,"starred\#
            ":true,"saying":true},{"id":255,"day":"2026-10-02","title":"小目标更容易坚持","quote":"每次只跑五公里反而坚持\#
            下来了 以前总觉得必须一上来就十公里 跑两次就放弃","tags":["运动","习惯"],"noteId":197,"starred":true,"saying":false},\#
            {"id":244,"day":"2026-10-01","title":"家安顿好了心才定","quote":"装修这两个月一直悬着 今天看着收拾好的家 心才算落了地","tag\#
            s":["家","安定"],"noteId":188,"starred":false,"saying":false}],"tags":[{"tag":"专注","count":3}\#
            ,{"tag":"工作","count":3},{"tag":"效率","count":2},{"tag":"睡眠","count":2},{"tag":"家人","count":\#
            1},{"tag":"育儿","count":1},{"tag":"取舍","count":1},{"tag":"阅读","count":1},{"tag":"精力","count\#
            ":1},{"tag":"休息","count":1},{"tag":"心态","count":1},{"tag":"手机","count":1},{"tag":"时间","cou\#
            nt":1},{"tag":"用户","count":1},{"tag":"方法","count":1},{"tag":"运动","count":1},{"tag":"习惯","c\#
            ount":1},{"tag":"家","count":1},{"tag":"安定","count":1}],"starred":7}
            """#

        static let today = #"""
            {"insight":{"id":244,"day":"2026-10-01","title":"家安顿好了心才定","quote":"装修这两个月一直悬着 今天看着收拾好的家 心\#
            才算落了地","tags":["家","安定"],"noteId":188,"starred":false,"saying":false},"ago":"一个月前的今天你说","s\#
            aid":"睡前看了26页三体 给妈妈打了电话 聊了半小时 新家终于收拾好了 一家三口第一次在新家吃饭 心里很踏实 装修这两个月一直悬着 今天看着收拾好的家 心才算落了地","re\#
            lated":[{"noteId":178,"day":"2026-09-30","text":"装修师傅来装了最后两个柜门 装修总算全部完工"},{"noteId":166,"d\#
            ay":"2026-09-28","text":"装修师傅来补了墙角 还差两个柜门"},{"noteId":13,"day":"2026-09-02","text":"装修师傅说柜\#
            子尺寸做错了 要返工 烦得不行 这事我必须盯紧点"}]}
            """#
    }
#endif
