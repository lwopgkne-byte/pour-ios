// swift-format-ignore-file
#if DEBUG
    import Foundation

    /// 一个人一页的演示数据（3.0 第 8 步，5288 演示服务器拿的「儿子」，原样）；别的名字回同一个人换个名字
    extension AboutStub {
        static func person(_ name: String) -> Any {
            guard var page = json(personSon) as? [String: Any] else { return [String: Any]() }
            if name != "儿子" { page["name"] = name }
            return page
        }

        static let personSon = #"""
            {"name":"儿子","relation":null,"group":"family","sub":"家人 · 这 9 周 32 天 · 最近一次 11月1日","acts":[{"nam\#
            e":"接放学","count":18,"days":["2026-09-01","2026-09-03","2026-09-08","2026-09-10","2026-09-15","20\#
            26-09-17","2026-09-22","2026-09-24","2026-09-29","2026-10-01","2026-10-06","2026-10-08","2026-10\#
            -13","2026-10-15","2026-10-20","2026-10-22","2026-10-27","2026-10-29"]},{"name":"看电影","count":3,\#
            "days":["2026-09-20","2026-10-04","2026-11-01"]},{"name":"上篮球课","count":3,"days":["2026-10-04","\#
            2026-10-11","2026-10-25"]},{"name":"去公园","count":2,"days":["2026-10-03","2026-10-31"]},{"name":"\#
            游泳","count":2,"days":["2026-09-20","2026-10-04"]},{"name":"买运动鞋","count":1,"days":["2026-11-01"]\#
            }],"mood":{"title":"32 天里 26 天心情挺好以上","sub":"别的日子 28 天里 4 天 · 只是同时出现"},"recent":[{"entryId":656,\#
            "day":"2026-11-01","text":"给儿子买了双运动鞋 259"},{"entryId":651,"day":"2026-11-01","text":"5点带儿子去看了场电影\#
             三张票150"},{"entryId":633,"day":"2026-10-31","text":"下午3点陪儿子去公园玩了一个半小时"},{"entryId":601,"day":"20\#
            26-10-29","text":"去接儿子放学"},{"entryId":577,"day":"2026-10-27","text":"下班顺路接了儿子"}],"money":{"total\#
            ":4134,"count":6,"text":"这 9 周 6 笔，一共 ¥4,134"},"empty":false}
            """#
    }
#endif
