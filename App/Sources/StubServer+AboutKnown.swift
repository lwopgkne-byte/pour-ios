#if DEBUG
    import Foundation

    /// 关于我的演示数据（续）：Pour 认识的（5199 演示服务器的 /api/about，每样只留几条）
    extension AboutStub {
        static let known = #"""
            {"sleep":{"key":"sleep","basis":"00:00|07:30","mark":null,"markedAt":null,"bed":
            "00:00","wake":"07:30","minutes":440,"steady":null,"weekendDiff":null,"before":
            null,"from":"2026-09-23","to":"2026-10-19","nights":[{"day":"2026-10-19","start":
            "2026-10-19T00:20","end":"2026-10-19T07:10","minutes":410,"entryId":597,"noteId":
            366},{"day":"2026-10-18","start":"2026-10-18T00:20","end":"2026-10-18T08:40","minutes":
            500,"entryId":581,"noteId":361},{"day":"2026-10-17","start":"2026-10-17T00:10",
            "end":"2026-10-17T08:30","minutes":500,"entryId":572,"noteId":354},{"day":"2026-10-16",
            "start":"2026-10-16T00:30","end":"2026-10-16T07:00","minutes":390,"entryId":559,
            "noteId":349},{"day":"2026-10-15","start":"2026-10-15T00:10","end":"2026-10-15T07:10",
            "minutes":420,"entryId":544,"noteId":343},{"day":"2026-10-14","start":"2026-10-14T00:10",
            "end":"2026-10-14T07:00","minutes":410,"entryId":533,"noteId":338}],"outliers":
            [{"day":"2026-10-09","start":"2026-10-08T23:20","end":"2026-10-09T05:20","minutes":
            360,"entryId":474,"noteId":310,"note":"比平时早起 2 小时"},{"day":"2026-10-05","start":
            "2026-10-05T03:40","end":"2026-10-05T10:05","minutes":385,"entryId":425,"noteId":
            284,"note":"比平时晚 4 小时"},{"day":"2026-10-02","start":"2026-10-01T23:30","end":"2026-10-02T05:30",
            "minutes":360,"entryId":399,"noteId":269,"note":"比平时早起 2 小时"}]},"habits":[{"key":
            "habit:168轻断食","basis":"daily|","mark":null,"markedAt":null,"name":"16:8 轻断食",
            "domain":"diet","perWeek":"daily","part":null,"times":25,"occurrences":[{"day":
            "2026-10-19","at":null,"label":"16:8 轻断食","entryId":598,"noteId":366},{"day":"2026-10-18",
            "at":null,"label":"16:8 轻断食","entryId":582,"noteId":361},{"day":"2026-10-17","at":
            null,"label":"16:8 轻断食","entryId":573,"noteId":354},{"day":"2026-10-16","at":null,
            "label":"16:8 轻断食","entryId":560,"noteId":349}]},{"key":"habit:看书","basis":"5|",
            "mark":null,"markedAt":null,"name":"看书","domain":"study","perWeek":5,"part":null,
            "times":19,"occurrences":[{"day":"2026-10-18","at":null,"label":"看书 42 页","entryId":
            592,"noteId":365},{"day":"2026-10-15","at":null,"label":"看书 33 页","entryId":553,
            "noteId":348},{"day":"2026-10-14","at":"22:00","label":"看书 48 页","entryId":542,
            "noteId":342},{"day":"2026-10-13","at":null,"label":"看书 44 页","entryId":528,"noteId":
            337}]},{"key":"habit:背单词","basis":"4|","mark":null,"markedAt":null,"name":"背单词",
            "domain":"study","perWeek":4,"part":null,"times":15,"occurrences":[{"day":"2026-10-18",
            "at":null,"label":"背单词","entryId":593,"noteId":365},{"day":"2026-10-15","at":null,
            "label":"背单词","entryId":554,"noteId":348},{"day":"2026-10-14","at":null,"label":
            "背单词","entryId":540,"noteId":342},{"day":"2026-10-13","at":null,"label":"背单词",
            "entryId":529,"noteId":337}]},{"key":"habit:量血压","basis":"3|","mark":null,"markedAt":
            null,"name":"量血压","domain":"c-09897138","perWeek":3,"part":null,"times":13,"occurrences":
            [{"day":"2026-10-18","at":null,"label":"量血压 130 mmHg","entryId":583,"noteId":361},
            {"day":"2026-10-16","at":null,"label":"量血压 129 mmHg","entryId":561,"noteId":349},
            {"day":"2026-10-14","at":null,"label":"量血压 132 mmHg","entryId":535,"noteId":338},
            {"day":"2026-10-12","at":null,"label":"量血压 131 mmHg","entryId":511,"noteId":325}]}],
            "people":[{"key":"person:儿子","basis":"儿子","mark":null,"markedAt":null,"name":"儿子",
            "times":43,"firstDay":"2026-08-18","lastDay":"2026-10-18","relation":null,"titled":
            true,"domains":["娱乐","运动"],"moments":{"good":3,"bad":0},"recent":[{"day":"2026-10-18",
            "label":"给儿子买运动鞋","domain":"购物","entryId":594,"noteId":365},{"day":"2026-10-18",
            "label":"看电影","domain":"娱乐","entryId":588,"noteId":364},{"day":"2026-10-17","label":
            "陪儿子去公园","domain":"家人朋友","entryId":578,"noteId":358},{"day":"2026-10-15","label":
            "接儿子放学","domain":"家人朋友","entryId":550,"noteId":347}]},{"key":"person:老婆","basis":
            "老婆","mark":null,"markedAt":null,"name":"老婆","times":23,"firstDay":"2026-08-21",
            "lastDay":"2026-10-18","relation":null,"titled":true,"domains":["娱乐","购物"],"moments":
            {"good":2,"bad":1},"recent":[{"day":"2026-10-18","label":"看电影","domain":"娱乐","entryId":
            588,"noteId":364},{"day":"2026-10-15","label":"追剧","domain":"娱乐","entryId":552,
            "noteId":348},{"day":"2026-10-11","label":"买围巾","domain":"购物","entryId":500,"noteId":
            322},{"day":"2026-10-10","label":"看纪录片","domain":"娱乐","entryId":492,"noteId":319}]},
            {"key":"person:小王","basis":"小王","mark":null,"markedAt":null,"name":"小王","times":
            11,"firstDay":"2026-08-26","lastDay":"2026-10-16","relation":{"id":3,"meaning":
            "同事","noteId":365,"updatedAt":"2026-10-18T16:20:00.000Z","note":{"text":"睡前看了42页人类简史 单词背了25分钟 给儿子买\#
            了双运动鞋 259 明天上午十点提醒我给客户回电话 晚上楼下飘上来烤红薯的香味 一下子放松了 小王是我同事",
            "at":"2026-10-18T16:20:00.000Z"}},"titled":false,"domains":["工作"],"moments":{"good":
            0,"bad":2},"recent":[{"day":"2026-10-16","label":"和小王对方案","domain":"工作","entryId":
            563,"noteId":351},{"day":"2026-10-07","label":"和小王开会","domain":"工作","entryId":
            452,"noteId":298},{"day":"2026-10-03","label":"喝喜酒","domain":"家人朋友","entryId":
            410,"noteId":275},{"day":"2026-09-29","label":"和小王对排期","domain":"工作","entryId":
            361,"noteId":254}]},{"key":"person:小李","basis":"小李","mark":null,"markedAt":null,
            "name":"小李","times":8,"firstDay":"2026-09-19","lastDay":"2026-10-15","relation":
            null,"titled":false,"domains":["饮食"],"moments":null,"recent":[{"day":"2026-10-15",
            "label":"和小李吃午饭","domain":"饮食","entryId":548,"noteId":346},{"day":"2026-10-12",
            "label":"回请小李吃火锅","domain":"饮食","entryId":514,"noteId":327},{"day":"2026-10-08",
            "label":"和小李吃午饭","domain":"饮食","entryId":467,"noteId":307},{"day":"2026-10-01",
            "label":"和小李吃午饭","domain":"饮食","entryId":391,"noteId":266}]}],"places":[{"key":
            "place:学校","basis":"学校","mark":null,"markedAt":null,"name":"学校","days":18,"lastDay":
            "2026-10-15","doing":["接儿子放学"],"recent":[{"day":"2026-10-15","at":null,"label":
            "接儿子放学","entryId":550,"noteId":347},{"day":"2026-10-13","at":null,"label":"接儿子放学",
            "entryId":527,"noteId":336},{"day":"2026-10-08","at":null,"label":"接儿子放学","entryId":
            469,"noteId":308}]},{"key":"place:小区","basis":"小区","mark":null,"markedAt":null,
            "name":"小区","days":11,"lastDay":"2026-10-19","doing":["跑步","陪儿子骑车"],"recent":[
            {"day":"2026-10-19","at":"6:30","label":"跑步","entryId":599,"noteId":366},{"day":
            "2026-10-14","at":"6:30","label":"跑步","entryId":536,"noteId":338},{"day":"2026-10-12",
            "at":"6:30","label":"跑步","entryId":512,"noteId":325}]},{"key":"place:超市","basis":
            "超市","mark":null,"markedAt":null,"name":"超市","days":9,"lastDay":"2026-10-17","doing":
            ["超市买菜"],"recent":[{"day":"2026-10-17","at":null,"label":"超市买菜","entryId":576,
            "noteId":356},{"day":"2026-10-10","at":null,"label":"超市买菜","entryId":489,"noteId":
            317},{"day":"2026-10-03","at":null,"label":"超市买菜","entryId":411,"noteId":276}]},
            {"key":"place:星巴克","basis":"星巴克","mark":null,"markedAt":null,"name":"星巴克","days":
            9,"lastDay":"2026-10-16","doing":["写方案"],"recent":[{"day":"2026-10-16","at":null,
            "label":"写方案","entryId":564,"noteId":351},{"day":"2026-10-09","at":null,"label":
            "写方案","entryId":477,"noteId":312},{"day":"2026-10-02","at":null,"label":"写方案",
            "entryId":404,"noteId":271}]}],"former":[{"key":"person:装修师傅","basis":"装修师傅","mark":
            null,"markedAt":null,"name":"装修师傅","times":9,"firstDay":"2026-08-19","lastDay":
            "2026-09-17","relation":null,"titled":false,"domains":["家务"],"moments":null,"recent":
            [{"day":"2026-09-17","label":"装柜门","domain":"家务","entryId":223,"noteId":175},{
            "day":"2026-09-16","label":"对尾款","domain":"家务","entryId":213,"noteId":167},{"day":
            "2026-09-15","label":"补墙角","domain":"家务","entryId":203,"noteId":162},{"day":"2026-09-12",
            "label":"刷漆","domain":"家务","entryId":187,"noteId":148}]}],"sayings":[{"id":2,"phrase":
            "老地方","meaning":"公司楼下那家面馆","noteId":200,"updatedAt":"2026-09-21T07:10:00.000Z",
            "note":{"text":"老地方就是公司楼下那家面馆 今天又去吃了 牛肉面28","at":"2026-09-21T07:10:00.000Z"},"key":
            "saying:老地方"},{"id":1,"phrase":"168","meaning":"16:8 轻断食","noteId":160,"updatedAt":
            "2026-09-15T02:05:00.000Z","note":{"text":"昨晚11点50分睡的 早上7点10分起 开始168了 就是16:8轻断食 争取连续30天 今年想跑500公里 \#
            从今天开始算",
            "at":"2026-09-15T02:05:00.000Z"},"key":"saying:168"}],"waiting":[],"hidden":[]}
            """#
    }
#endif
