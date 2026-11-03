#if DEBUG
    import Foundation

    extension StubServer.State {
        /// 3.0 心情页（服务器 /api/mood/page、/api/mood/words）：从 5288 演示数据拿的 10 月，10月31日当今天（三刻、有起有落）
        func moodReply(_ method: String, _ path: String) -> Any? {
            switch (method, path) {
            case ("GET", "/api/mood/page"): return MoodStub.json(MoodStub.page)
            case ("GET", "/api/mood/words"): return MoodStub.json(MoodStub.words)
            default: return nil
            }
        }
    }

    /// 心情页的演示数据（5288 演示服务器拿的，原样；今天换成 10月31日）
    enum MoodStub {
        static func json(_ text: String) -> Any {
            (try? JSONSerialization.jsonObject(with: Data(text.utf8))) ?? [String: Any]()
        }

        static let page = #"""
            {"today":"2026-10-31","month":"2026-10","current":true,"todayMoments":
            [{"entryId":608,"day":"2026-10-31","time":"16:20","mood":2,"word":
            "不太好","emotions":["烦躁"],"energy":null,"moment":"下午方案被改了三遍","byYou":
            false,"noteId":380},{"entryId":606,"day":"2026-10-31","time":
            "18:10","mood":2,"word":"不太好","emotions":["烦躁"],"energy":null,
            "moment":"方案又改了","byYou":false,"noteId":379},{"entryId":620,
            "day":"2026-10-31","time":"21:50","mood":4,"word":"挺好","emotions":
            ["放松"],"energy":null,"moment":"晚上楼下飘上来烤红薯的香味","byYou":false,
            "noteId":383}],"todaySummary":"3 刻 · 有起有落","days":[{"day":"2026-10-01",
            "mood":4,"word":"挺好","moments":[{"entryId":243,"day":"2026-10-01",
            "time":"21:40","mood":4,"word":"挺好","emotions":["踏实"],"energy":
            null,"moment":"新家终于收拾好了 一家三口第一次在新家吃饭","byYou":false,"noteId":
            188}]},{"day":"2026-10-02","mood":2,"word":"不太好","moments":[
            {"entryId":254,"day":"2026-10-02","time":"21:40","mood":2,"word":
            "不太好","emotions":["失落"],"energy":null,"moment":"小王又把方案打回来了",
            "byYou":false,"noteId":197}]},{"day":"2026-10-03","mood":5,"word":
            "很好","moments":[{"entryId":268,"day":"2026-10-03","time":"21:50",
            "mood":5,"word":"很好","emotions":["开心"],"energy":null,"moment":
            "晚上7点陪儿子在小区骑自行车 他第一次不用辅助轮","byYou":false,"noteId":203}]},{"day":
            "2026-10-04","mood":5,"word":"很好","moments":[{"entryId":278,
            "day":"2026-10-04","time":"21:50","mood":5,"word":"很好","emotions":
            ["放松"],"energy":null,"moment":"下班路上看见一片晚霞","byYou":false,"noteId":
            210}]},{"day":"2026-10-05","mood":2,"word":"不太好","moments":[
            {"entryId":293,"day":"2026-10-05","time":"21:40","mood":2,"word":
            "不太好","emotions":["委屈"],"energy":null,"moment":"上午10点开会被领导当众点名",
            "byYou":false,"noteId":219}]},{"day":"2026-10-06","mood":4,"word":
            "挺好","moments":[{"entryId":301,"day":"2026-10-06","time":"21:40",
            "mood":4,"word":"挺好","emotions":["开心"],"energy":null,"moment":
            "晚上8点陪儿子拼完了一个乐高","byYou":false,"noteId":224}]},{"day":"2026-10-07",
            "mood":3,"word":"一般","moments":[{"entryId":313,"day":"2026-10-07",
            "time":"21:40","mood":3,"word":"一般","emotions":[],"energy":4,
            "moment":null,"byYou":false,"noteId":230}]},{"day":"2026-10-08",
            "mood":5,"word":"很好","moments":[{"entryId":326,"day":"2026-10-08",
            "time":"21:40","mood":5,"word":"很好","emotions":["开心"],"energy":
            null,"moment":"给客户的提案一次就过了","byYou":false,"noteId":237}]},{"day":
            "2026-10-09","mood":3,"word":"一般","moments":[{"entryId":335,
            "day":"2026-10-09","time":"21:40","mood":3,"word":"一般","emotions":
            [],"energy":null,"moment":null,"byYou":false,"noteId":243}]},
            {"day":"2026-10-10","mood":4,"word":"挺好","moments":[{"entryId":
            346,"day":"2026-10-10","time":"21:50","mood":4,"word":"挺好","emotions":
            [],"energy":null,"moment":null,"byYou":false,"noteId":249}]},
            {"day":"2026-10-11","mood":4,"word":"挺好","moments":[{"entryId":
            359,"day":"2026-10-11","time":"21:50","mood":4,"word":"挺好","emotions":
            ["放松"],"energy":null,"moment":"上午10点和老婆去花鸟市场逛了一圈","byYou":false,
            "noteId":255}]},{"day":"2026-10-12","mood":2,"word":"不太好","moments":
            [{"entryId":372,"day":"2026-10-12","time":"21:40","mood":2,"word":
            "不太好","emotions":["烦躁"],"energy":null,"moment":"下午4点客户临时改需求 又要重做",
            "byYou":false,"noteId":262}]},{"day":"2026-10-13","mood":3,"word":
            "有起有落","moments":[{"entryId":386,"day":"2026-10-13","time":"21:40",
            "mood":4,"word":"挺好","emotions":["开心"],"energy":null,"moment":
            "上午评审很顺利","byYou":false,"noteId":268},{"entryId":387,"day":"2026-10-13",
            "time":"21:40","mood":2,"word":"不太好","emotions":["焦虑"],"energy":
            null,"moment":null,"byYou":false,"noteId":268}]},{"day":"2026-10-14",
            "mood":1,"word":"很差","moments":[{"entryId":402,"day":"2026-10-14",
            "time":"21:40","mood":1,"word":"很差","emotions":["失落"],"energy":
            null,"moment":"加班到十点 领导还是不满意","byYou":false,"noteId":276}]},
            {"day":"2026-10-15","mood":5,"word":"很好","moments":[{"entryId":
            416,"day":"2026-10-15","time":"21:40","mood":5,"word":"很好","emotions":
            [],"energy":null,"moment":"早上闻到楼下面包店刚出炉的香味","byYou":false,"noteId":
            281}]},{"day":"2026-10-16","mood":3,"word":"一般","moments":[{
            "entryId":422,"day":"2026-10-16","time":"21:40","mood":3,"word":
            "一般","emotions":[],"energy":null,"moment":null,"byYou":false,
            "noteId":286}]},{"day":"2026-10-17","mood":3,"word":"一般","moments":
            [{"entryId":433,"day":"2026-10-17","time":"21:50","mood":3,"word":
            "一般","emotions":[],"energy":4,"moment":null,"byYou":false,"noteId":
            291}]},{"day":"2026-10-18","mood":3,"word":"一般","moments":[{
            "entryId":444,"day":"2026-10-18","time":"21:50","mood":3,"word":
            "一般","emotions":[],"energy":4,"moment":null,"byYou":false,"noteId":
            296}]},{"day":"2026-10-19","mood":4,"word":"挺好","moments":[{
            "entryId":456,"day":"2026-10-19","time":"21:40","mood":4,"word":
            "挺好","emotions":["满足"],"energy":null,"moment":"下午3点把拖了两周的方案写完了",
            "byYou":false,"noteId":302}]},{"day":"2026-10-20","mood":4,"word":
            "挺好","moments":[{"entryId":471,"day":"2026-10-20","time":"21:40",
            "mood":4,"word":"挺好","emotions":["开心"],"energy":null,"moment":
            "晚上9点陪猫玩了半小时逗猫棒","byYou":false,"noteId":311}]},{"day":"2026-10-21",
            "mood":3,"word":"一般","moments":[{"entryId":483,"day":"2026-10-21",
            "time":"21:40","mood":3,"word":"一般","emotions":[],"energy":null,
            "moment":null,"byYou":false,"noteId":316}]},{"day":"2026-10-22",
            "mood":2,"word":"不太好","moments":[{"entryId":497,"day":"2026-10-22",
            "time":"21:40","mood":2,"word":"不太好","emotions":["生气"],"energy":
            null,"moment":"上午11点跟客户打电话吵了一架","byYou":false,"noteId":322}]},
            {"day":"2026-10-23","mood":5,"word":"很好","moments":[{"entryId":
            509,"day":"2026-10-23","time":"21:40","mood":5,"word":"很好","emotions":
            ["开心"],"energy":null,"moment":"晚上7点和老同学吃了顿火锅","byYou":false,
            "noteId":329}]},{"day":"2026-10-24","mood":4,"word":"挺好","moments":
            [{"entryId":521,"day":"2026-10-24","time":"21:50","mood":4,"word":
            "挺好","emotions":["满足"],"energy":null,"moment":"晚上10点 三体终于看完了",
            "byYou":false,"noteId":335}]},{"day":"2026-10-25","mood":4,"word":
            "挺好","moments":[{"entryId":536,"day":"2026-10-25","time":"21:50",
            "mood":4,"word":"挺好","emotions":["开心"],"energy":null,"moment":
            "等红灯的时候看见一只小狗冲我摇尾巴","byYou":false,"noteId":340}]},{"day":"2026-10-26",
            "mood":2,"word":"不太好","moments":[{"entryId":547,"day":"2026-10-26",
            "time":"21:40","mood":2,"word":"不太好","emotions":["失落"],"energy":
            null,"moment":"早上8点地铁坏了 上班迟到","byYou":false,"noteId":347}]},
            {"day":"2026-10-27","mood":3,"word":"一般","moments":[{"entryId":
            556,"day":"2026-10-27","time":"21:40","mood":3,"word":"一般","emotions":
            [],"energy":null,"moment":null,"byYou":false,"noteId":353}]},
            {"day":"2026-10-28","mood":3,"word":"一般","moments":[{"entryId":
            570,"day":"2026-10-28","time":"21:40","mood":3,"word":"一般","emotions":
            [],"energy":4,"moment":null,"byYou":false,"noteId":359}]},{"day":
            "2026-10-29","mood":4,"word":"挺好","moments":[{"entryId":586,
            "day":"2026-10-29","time":"21:40","mood":4,"word":"挺好","emotions":
            ["放松"],"energy":null,"moment":"午休听见楼下有人在拉二胡","byYou":false,"noteId":
            365}]},{"day":"2026-10-30","mood":3.5,"word":"挺好","moments":
            [{"entryId":593,"day":"2026-10-30","time":"21:40","mood":4,"word":
            "挺好","emotions":[],"energy":null,"moment":null,"byYou":false,
            "noteId":370},{"entryId":599,"day":"2026-10-30","time":"21:40",
            "mood":3,"word":"一般","emotions":[],"energy":null,"moment":null,
            "byYou":false,"noteId":373}]},{"day":"2026-10-31","mood":2.67,
            "word":"有起有落","moments":[{"entryId":608,"day":"2026-10-31","time":
            "16:20","mood":2,"word":"不太好","emotions":["烦躁"],"energy":null,
            "moment":"下午方案被改了三遍","byYou":false,"noteId":380},{"entryId":
            606,"day":"2026-10-31","time":"18:10","mood":2,"word":"不太好",
            "emotions":["烦躁"],"energy":null,"moment":"方案又改了","byYou":false,
            "noteId":379},{"entryId":620,"day":"2026-10-31","time":"21:50",
            "mood":4,"word":"挺好","emotions":["放松"],"energy":null,"moment":
            "晚上楼下飘上来烤红薯的香味","byYou":false,"noteId":383}]}],"monthLine":"平均在一般和挺好之间 · 31 天说到了心情",
            "prevMonth":"2026-09","nextMonth":null,"week":{"bars":[{"value":
            2.56,"days":9},{"value":3.89,"days":9},{"value":2.44,"days":
            9},{"value":4,"days":9},{"value":2.94,"days":8},{"value":3.74,
            "days":9},{"value":3.75,"days":8}],"low":null,"high":null,"sentence":
            "哪天最低，前后两段时间不一样","check":""},"good":{"total":15,"recent":[{"entryId":
            620,"day":"2026-10-31","time":"21:50","mood":4,"word":"挺好","emotions":
            ["放松"],"energy":null,"moment":"晚上楼下飘上来烤红薯的香味","byYou":false,
            "noteId":383},{"entryId":586,"day":"2026-10-29","time":"21:40",
            "mood":4,"word":"挺好","emotions":["放松"],"energy":null,"moment":
            "午休听见楼下有人在拉二胡","byYou":false,"noteId":365},{"entryId":536,"day":
            "2026-10-25","time":"21:50","mood":4,"word":"挺好","emotions":
            ["开心"],"energy":null,"moment":"等红灯的时候看见一只小狗冲我摇尾巴","byYou":false,
            "noteId":340}]},"findings":[{"key":"和儿子在一起→goodMood","sentence":
            "和儿子在一起的日子，大多心情挺好；别的日子很少这样。","bars":[{"label":"和儿子在一起","value":
            "30 天里 24 天","share":0.8,"strong":true},{"label":"别的日子","value":
            "31 天里 3 天","share":0.0967741935483871,"strong":false}],"sub":
            "前后两段都是这样 · 只是同时出现 · 点开看是哪几天","tone":"good","days":[{"day":"2026-09-01",
            "text":"心情挺好"},{"day":"2026-09-03","text":"心情挺好 · 说了累"},{"day":
            "2026-09-08","text":"心情挺好"},{"day":"2026-09-10","text":"心情挺好 · 说了累"},
            {"day":"2026-09-12","text":"心情挺好"},{"day":"2026-09-15","text":
            "心情挺好"},{"day":"2026-09-17","text":"心情挺好"},{"day":"2026-09-19",
            "text":"心情很好"},{"day":"2026-09-20","text":"心情很好"},{"day":"2026-09-22",
            "text":"心情挺好"},{"day":"2026-09-24","text":"心情挺好"},{"day":"2026-09-29",
            "text":"心情很好 · 说了累"},{"day":"2026-10-01","text":"心情挺好"},{"day":
            "2026-10-03","text":"心情很好"},{"day":"2026-10-04","text":"心情很好"},
            {"day":"2026-10-06","text":"心情挺好 · 说了累"},{"day":"2026-10-08",
            "text":"心情很好"},{"day":"2026-10-10","text":"心情挺好"},{"day":"2026-10-11",
            "text":"心情挺好 · 说了累"},{"day":"2026-10-15","text":"心情很好"},{"day":
            "2026-10-20","text":"心情挺好 · 说了累"},{"day":"2026-10-24","text":
            "心情挺好"},{"day":"2026-10-25","text":"心情挺好"},{"day":"2026-10-29",
            "text":"心情挺好"}]},{"key":"和小王在一起→badMood","sentence":"和小王在一起的日子，大多心情不太好；别的日子很少这样。",
            "bars":[{"label":"和小王在一起","value":"11 天里 9 天","share":0.8181818181818182,
            "strong":true},{"label":"别的日子","value":"50 天里 5 天","share":0.1,
            "strong":false}],"sub":"前后两段都是这样 · 只是同时出现 · 点开看是哪几天","tone":
            "bad","days":[{"day":"2026-09-02","text":"心情不太好 · 说了累"},{"day":
            "2026-09-11","text":"心情不太好 · 说了累"},{"day":"2026-09-14","text":
            "心情不太好"},{"day":"2026-09-23","text":"心情不太好 · 说了累"},{"day":"2026-10-02",
            "text":"心情不太好"},{"day":"2026-10-05","text":"心情不太好"},{"day":"2026-10-12",
            "text":"心情不太好"},{"day":"2026-10-14","text":"心情很差"},{"day":"2026-10-26",
            "text":"心情不太好 · 说了累"}]}],"changes":[{"key":"feelings","text":
            "说出过的感受，从 1 种到 9 种","from":"1 种","to":"9 种","sub":"一共说出过几种感受 · 能说得越细，越容易知道自己怎么了",
            "points":[1,2,4,5,6,7,8,9,9],"color":"mood"}]}
            """#

        static let words = #"""
            {"good":["开心","放松","满足","踏实","平静","期待","感激"],"bad":["烦躁","失落",
            "生气","委屈","焦虑","累","难过"]}
            """#
    }
#endif
