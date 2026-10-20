#if DEBUG
    import Foundation

    extension StubServer.State {
        /// 照网页版搬过来的几页（目标、回顾、钱、笔记库、搜索）各自的接口
        func pageReply(_ method: String, _ path: String) -> Any? {
            goalsReply(method, path) ?? reviewReply(method, path) ?? moneyReply(method, path)
                ?? libraryReply(method, path) ?? searchReply(method, path)
        }

        /// 搜索：不管搜什么都给网页版演示数据里搜「跑步」的结果（界面测试只看打得开、点得动）
        func searchReply(_ method: String, _ path: String) -> Any? {
            method == "GET" && path == "/api/search" ? SearchStub.json(SearchStub.run) : nil
        }
    }

    /// 搜索和问答的演示数据：搜「跑步」的结果（网页版 5199 拿的），一段带来源、五种图表、报告的回答（「/问」开头的话都这样回答）
    enum SearchStub {
        static func json(_ text: String) -> Any {
            (try? JSONSerialization.jsonObject(with: Data(text.utf8))) ?? [String: Any]()
        }

        static var answer: Any { json(answerText) }

        /// 「/问」开头：给一段带来源、图表的回答（看回答的样子）；别的话是 nil
        static func asked(_ text: String, _ note: [String: Any]) -> [String: Any]? {
            guard text.hasPrefix("/问") else { return nil }
            var done = note
            done["result"] = [
                "receipt": [Any](), "reply": "", "questions": [String](), "notices": [String](), "answer": answer,
            ]
            return done
        }

        static let run = #"""
            {"hits":[{"kind":"note","noteId":210,"day":"2026-09-22","text":"晚上去跑步了","score":
            0.8618974236391213,"via":"both"},{"kind":"note","noteId":166,"day":"2026-09-16",
            "text":"11点40分睡 7点起 今天继续168 早上跑了5.7公里 用了35分钟","score":0.5220822164901041,"via":
            "semantic"},{"kind":"note","noteId":295,"day":"2026-10-07","text":"昨天11点半左右睡的 早上7点醒的 今天继续168 早上跑了6\#
            .4公里 用了37分钟",
            "score":0.5090014597242808,"via":"semantic"},{"kind":"note","noteId":199,"day":
            "2026-09-21","text":"168第7天 早上跑了5.4公里 用了32分钟","score":0.5058416031403599,"via":
            "semantic"}],"goals":[],"day":null,"semantic":{"state":"ready"}}
            """#

        static let answerText = #"""
            {"text":"这周跑了 **3 次**，一共 18 公里[#210]。\n\n- 周二晚上 5 公里\n- 周四早上 6.4 公里[#295]\n\n比上周多一次。",
            "sources":[{"noteId":210,"day":"2026-09-22","text":"晚上去跑步了"},{"noteId":295,"day":
            "2026-10-07","text":"早上跑了6.4公里 用了37分钟"}],"charts":[{"type":"bar","title":"每天跑了多少",
            "unit":"公里","points":[{"label":"周一","value":null},{"label":"周二","value":5},{"label":
            "周三","value":null},{"label":"周四","value":6.4},{"label":"周五","value":0},{"label":
            "周六","value":6.6},{"label":"周日","value":null}],"target":5},{"type":"line","title":
            "入睡时间","unit":"time","points":[{"label":"10/14","value":1420},{"label":"10/15",
            "value":1450},{"label":"10/16","value":1395}],"trend":[null,1435,1422]},{"type":
            "ring","title":"今年跑 500 公里","unit":"公里","value":212.4,"target":500,"pct":0.4248,
            "tone":"good","headline":"按现在的速度能完成"},{"type":"heatmap","title":"每天的心情","unit":
            "mood","days":[{"day":"2026-10-12","value":3},{"day":"2026-10-13","value":4},{
            "day":"2026-10-14","value":2}]},{"type":"timeline","title":"睡觉的时间","items":[{"day":
            "2026-10-14","start":"2026-10-13T23:40","end":"2026-10-14T07:10","label":"睡觉",
            "color":"purple"}]},{"type":"radar","title":"以后的种类"}],"reports":[{"id":84,"title":
            "10月12日–18日 周报"}]}
            """#
    }
#endif
