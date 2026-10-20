#if DEBUG
    import Foundation

    /// 关于我的演示数据（续）
    extension AboutStub {
        static let care = #"""
            {"from":"2026-09-21","to":"2026-10-20","hidden":false,"rows":[{"key":"diet","name":
            "饮食","said":[{"kind":"goal","day":"2026-09-30","text":"每月外卖不超过 300 元","entryId":
            null,"noteId":null},{"kind":"goal","day":"2026-09-23","text":"每周外卖不超过 2 次","entryId":
            null,"noteId":null},{"kind":"goal","day":"2026-09-15","text":"连续 30 天 16:8 轻断食",
            "entryId":null,"noteId":null}],"minutes":null,"money":1811,"weekendMinutes":null,
            "days":["2026-09-21","2026-09-22","2026-09-23","2026-09-24","2026-09-25","2026-09-26",
            "2026-09-27","2026-09-28","2026-09-29","2026-09-30","2026-10-01","2026-10-02",
            "2026-10-03","2026-10-04","2026-10-05","2026-10-06","2026-10-07","2026-10-08",
            "2026-10-09","2026-10-10","2026-10-11","2026-10-12","2026-10-13","2026-10-14",
            "2026-10-15","2026-10-16","2026-10-17","2026-10-18","2026-10-19"],"share":null,
            "text":"这 30 天记到 29 天，¥1,811"},{"key":"exercise","name":"运动","said":[{"kind":"insight",
            "day":"2026-09-19","text":"每次只跑五公里反而坚持下来了 以前总觉得必须一上来就十公里 跑两次就放弃","entryId":254,
            "noteId":192},{"kind":"goal","day":"2026-09-15","text":"今年跑 500 公里","entryId":
            null,"noteId":null},{"kind":"goal","day":"2026-09-15","text":"每周运动 3 次","entryId":
            null,"noteId":null}],"minutes":776,"money":null,"weekendMinutes":247,"days":["2026-09-21",
            "2026-09-22","2026-09-23","2026-09-24","2026-09-26","2026-09-28","2026-09-30",
            "2026-10-01","2026-10-03","2026-10-04","2026-10-07","2026-10-08","2026-10-10",
            "2026-10-12","2026-10-14","2026-10-15","2026-10-17","2026-10-19"],"share":5,"text":
            "这 30 天记到 18 天，一共 12 小时 56 分"},{"key":"sleep","name":"睡眠","said":[{"kind":"insight",
            "day":"2026-10-07","text":"睡前读半小时书 比刷手机睡得踏实","entryId":462,"noteId":303},{"kind":
            "insight","day":"2026-09-25","text":"昨晚十一点就睡了 今天上午做事特别顺","entryId":321,"noteId":
            230},{"kind":"goal","day":"2026-09-21","text":"平均睡眠 7.5 小时","entryId":null,"noteId":
            null}],"minutes":12045,"money":null,"weekendMinutes":3870,"days":["2026-09-22",
            "2026-09-23","2026-09-24","2026-09-25","2026-09-26","2026-09-27","2026-09-28",
            "2026-09-29","2026-09-30","2026-10-01","2026-10-02","2026-10-03","2026-10-04",
            "2026-10-05","2026-10-06","2026-10-07","2026-10-09","2026-10-10","2026-10-11",
            "2026-10-12","2026-10-13","2026-10-14","2026-10-15","2026-10-16","2026-10-17",
            "2026-10-18","2026-10-19"],"share":null,"text":"这 30 天记到 27 天，一共 200 小时 45 分"}]}
            """#

        static let people = #"""
            {"span":"这 9 周","sentence":"这 9 周你提到 13 个人；儿子在 31 天里出现，是最常在一起的。","people":[{"name":
            "儿子","relation":null,"group":"family","days":["2026-08-20","2026-08-25","2026-08-27",
            "2026-08-29","2026-08-31","2026-09-01","2026-09-03","2026-09-05","2026-09-06",
            "2026-09-07","2026-09-08","2026-09-10","2026-09-15","2026-09-17","2026-09-18",
            "2026-09-19","2026-09-20","2026-09-22","2026-09-24","2026-09-26","2026-09-27",
            "2026-09-29","2026-10-01","2026-10-06","2026-10-08","2026-10-10","2026-10-11",
            "2026-10-13","2026-10-15","2026-10-17","2026-10-18"],"lastDay":"2026-10-18","doing":
            "多是接放学、看电影、上篮球课","mood":"better","moodText":"心情好一些","former":false},{"name":"老婆",
            "relation":null,"group":"family","days":["2026-08-21","2026-08-23","2026-08-26",
            "2026-08-30","2026-08-31","2026-09-05","2026-09-06","2026-09-10","2026-09-13",
            "2026-09-17","2026-09-20","2026-09-25","2026-09-27","2026-09-30","2026-10-04",
            "2026-10-05","2026-10-10","2026-10-11","2026-10-15","2026-10-18"],"lastDay":"2026-10-18",
            "doing":"多是看电影、看纪录片、追剧","mood":"same","moodText":"差不多","former":false},{"name":
            "小王","relation":"同事","group":"work","days":["2026-08-26","2026-09-04","2026-09-07",
            "2026-09-16","2026-09-22","2026-09-25","2026-09-28","2026-09-29","2026-10-03",
            "2026-10-07","2026-10-16"],"lastDay":"2026-10-16","doing":"多是对方案、开会","mood":"worse",
            "moodText":"心情差一些","former":false},{"name":"小李","relation":null,"group":"other",
            "days":["2026-09-19","2026-09-24","2026-09-28","2026-10-01","2026-10-08","2026-10-12",
            "2026-10-15"],"lastDay":"2026-10-15","doing":"多是吃午饭","mood":"better","moodText":
            "心情好一些","former":false},{"name":"同事","relation":null,"group":"work","days":["2026-08-20",
            "2026-08-26","2026-09-01","2026-09-07","2026-09-27"],"lastDay":"2026-09-27","doing":
            "多是午饭 麻辣烫","mood":"few","moodText":"还太少","former":false},{"name":"老同学","relation":
            null,"group":"other","days":["2026-09-19","2026-10-09","2026-10-10","2026-10-17"],
            "lastDay":"2026-10-17","doing":"满月红包、吃火锅","mood":"few","moodText":"还太少","former":
            false},{"name":"妈妈","relation":null,"group":"family","days":["2026-09-18","2026-10-02",
            "2026-10-16"],"lastDay":"2026-10-16","doing":"多是视频","mood":"few","moodText":"还太少",
            "former":false},{"name":"客户","relation":null,"group":"work","days":["2026-09-25",
            "2026-09-29","2026-10-07"],"lastDay":"2026-10-07","doing":"打电话、改需求","mood":"few",
            "moodText":"还太少","former":false},{"name":"装修师傅","relation":null,"group":"other",
            "days":["2026-08-19","2026-08-26","2026-08-29","2026-09-02","2026-09-08","2026-09-12",
            "2026-09-15","2026-09-16","2026-09-17"],"lastDay":"2026-09-17","doing":"装柜门、对尾款",
            "mood":"same","moodText":"差不多","former":true}],"findings":[{"key":"和小王在一起→badMood",
            "sentence":"和小王在一起的日子，大多心情不太好；别的日子很少这样。","bars":[{"label":"和小王在一起","value":"11 天里 9 天",
            "share":0.8181818181818182,"strong":true},{"label":"别的日子","value":"47 天里 4 天",
            "share":0.0851063829787234,"strong":false}],"sub":"前后两段都是这样 · 只是同时出现 · 点开看是哪几天",
            "tone":"bad","days":[{"day":"2026-08-26","text":"心情不太好"},{"day":"2026-09-04","text":
            "心情不太好"},{"day":"2026-09-07","text":"心情不太好"},{"day":"2026-09-16","text":"心情不太好"},
            {"day":"2026-09-22","text":"心情不太好 · 说了累"},{"day":"2026-09-28","text":"心情很差"},{
            "day":"2026-09-29","text":"心情不太好"},{"day":"2026-10-07","text":"心情不太好"},{"day":
            "2026-10-16","text":"心情不太好 · 说了累"}]},{"key":"和儿子在一起→goodMood","sentence":"和儿子在一起的日子，大多心情挺好；别的日子很少这样。",
            "bars":[{"label":"和儿子在一起","value":"31 天里 25 天","share":0.8064516129032258,"strong":
            true},{"label":"别的日子","value":"27 天里 3 天","share":0.1111111111111111,"strong":
            false}],"sub":"前后两段都是这样 · 只是同时出现 · 点开看是哪几天","tone":"good","days":[{"day":"2026-08-20",
            "text":"心情挺好 · 说了累"},{"day":"2026-08-25","text":"心情挺好"},{"day":"2026-08-27","text":
            "心情挺好"},{"day":"2026-08-29","text":"心情挺好"},{"day":"2026-09-01","text":"心情很好"},
            {"day":"2026-09-03","text":"心情挺好"},{"day":"2026-09-05","text":"心情挺好 · 说了累"},{"day":
            "2026-09-06","text":"心情挺好"},{"day":"2026-09-08","text":"心情挺好 · 说了累"},{"day":"2026-09-10",
            "text":"心情挺好 · 说了累"},{"day":"2026-09-15","text":"心情挺好"},{"day":"2026-09-17","text":
            "心情挺好"},{"day":"2026-09-18","text":"心情挺好 · 说了累"},{"day":"2026-09-19","text":"心情很好"},
            {"day":"2026-09-20","text":"心情很好"},{"day":"2026-09-24","text":"心情挺好"},{"day":"2026-09-26",
            "text":"心情挺好"},{"day":"2026-09-27","text":"心情挺好 · 说了累"},{"day":"2026-10-01","text":
            "心情很好"},{"day":"2026-10-06","text":"心情挺好"},{"day":"2026-10-08","text":"心情挺好"},
            {"day":"2026-10-10","text":"心情很好"},{"day":"2026-10-11","text":"心情挺好"},{"day":"2026-10-15",
            "text":"心情挺好"},{"day":"2026-10-17","text":"心情挺好"}]}],"changes":[]}
            """#

        static let year = #"""
            {"year":2026,"from":"2026-01-01","to":"2026-10-20","span":293,"recorded":63,"notes":
            368,"streak":{"days":63,"from":"2026-08-18","to":"2026-10-19"},"tiles":[{"key":
            "diet","name":"饮食","color":"orange","notes":107,"share":26},{"key":"work","name":
            "工作","color":"brown","notes":74,"share":18},{"key":"sleep","name":"睡眠","color":
            "purple","notes":61,"share":15},{"key":"c-8dc516e6","name":"家人朋友","color":"pink",
            "notes":44,"share":11},{"key":"c-84f6a689","name":"购物","color":"orange","notes":
            35,"share":8},{"key":"c-b7328bba","name":"家务","color":"brown","notes":32,"share":
            8},{"key":"study","name":"学习","color":"blue","notes":29,"share":7},{"key":"exercise",
            "name":"运动","color":"green","notes":27,"share":7}],"people":[{"name":"儿子","days":
            33},{"name":"老婆","days":20},{"name":"小王","days":11},{"name":"装修师傅","days":9},{
            "name":"小李","days":7}],"months":[{"month":"2026-08","name":"8 月","mood":3.15,"days":
            13},{"month":"2026-09","name":"9 月","mood":3.39,"days":30},{"month":"2026-10",
            "name":"10 月","mood":3.41,"days":16}],"bestMonth":{"month":"2026-10","name":"10 月",
            "mood":3.41,"days":16},"emotions":[{"word":"开心","times":12},{"word":"烦躁","times":
            5},{"word":"放松","times":4},{"word":"失落","times":3},{"word":"生气","times":3},{"word":
            "委屈","times":2}],"first":{"day":"2026-08-18","noteId":1,"text":"昨晚11点10分睡的 早上7点10分起"},
            "last":{"day":"2026-10-19","noteId":368,"text":"断网了也要记下来"},"enough":false,"waiting":
            "再记 57 天，能看到你的 2026","sentence":"2026 年，你记了 63 天、说了 368 段话"}
            """#

        static let metrics = #"""
            {"metrics":[{"id":"sleep:duration","name":"睡眠时长","emoji":"😴","color":"purple",
            "category":"sleep","kind":"event","measure":"duration","unit":"小时","how":"avg"},
            {"id":"sleep:start_time","name":"入睡时间","emoji":"😴","color":"purple","category":
            "sleep","kind":"event","measure":"start_time","unit":"time","how":"clock"},{"id":
            "sleep:end_time","name":"起床时间","emoji":"😴","color":"purple","category":"sleep",
            "kind":"event","measure":"end_time","unit":"time","how":"clock"},{"id":"exercise:duration",
            "name":"运动时长","emoji":"🏃","color":"green","category":"exercise","kind":"event",
            "measure":"duration","unit":"小时","how":"sum"},{"id":"diet:count","name":"饮食次数",
            "emoji":"🍽","color":"orange","category":"diet","kind":"event","measure":"count",
            "unit":"次","how":"sum"},{"id":"study:duration","name":"学习时长","emoji":"📚","color":
            "blue","category":"study","kind":"event","measure":"duration","unit":"小时","how":
            "sum"},{"id":"work:duration","name":"工作时长","emoji":"💼","color":"brown","category":
            "work","kind":"event","measure":"duration","unit":"小时","how":"sum"},{"id":"c-d141d79b:duration",
            "name":"冥想时长","emoji":"🧘","color":"purple","category":"c-d141d79b","kind":"event",
            "measure":"duration","unit":"小时","how":"sum"},{"id":"c-09897138:count","name":
            "健康次数","emoji":"🩺","color":"red","category":"c-09897138","kind":"event","measure":
            "count","unit":"次","how":"sum"},{"id":"c-84f6a689:count","name":"购物次数","emoji":
            "🛒","color":"orange","category":"c-84f6a689","kind":"event","measure":"count",
            "unit":"次","how":"sum"},{"id":"c-8dc516e6:count","name":"家人朋友次数","emoji":"👨‍👩‍👧",
            "color":"pink","category":"c-8dc516e6","kind":"event","measure":"count","unit":
            "次","how":"sum"},{"id":"c-b27062be:count","name":"办事次数","emoji":"📋","color":"gray",
            "category":"c-b27062be","kind":"event","measure":"count","unit":"次","how":"sum"},
            {"id":"c-b7328bba:duration","name":"家务时长","emoji":"🧹","color":"brown","category":
            "c-b7328bba","kind":"event","measure":"duration","unit":"小时","how":"sum"},{"id":
            "c-c916946f:duration","name":"娱乐时长","emoji":"🎬","color":"purple","category":"c-c916946f",
            "kind":"event","measure":"duration","unit":"小时","how":"sum"},{"id":"c-f4b9b270:count",
            "name":"宠物次数","emoji":"🐕","color":"orange","category":"c-f4b9b270","kind":"event",
            "measure":"count","unit":"次","how":"sum"},{"id":"mood:mood","name":"心情","emoji":
            "💭","color":"pink","category":null,"kind":"mood","measure":"mood","unit":"分","how":
            "avg"},{"id":"mood:energy","name":"精力","emoji":"⚡","color":"yellow","category":
            null,"kind":"mood","measure":"energy","unit":"分","how":"avg"}]}
            """#

        static let heat = #"""
            {"year":2026,"days":[{"day":"2026-08-01","value":0},{"day":"2026-08-02","value":
            0},{"day":"2026-08-03","value":0},{"day":"2026-08-04","value":0},{"day":"2026-08-05",
            "value":0},{"day":"2026-08-06","value":0},{"day":"2026-08-07","value":0},{"day":
            "2026-08-08","value":0},{"day":"2026-08-09","value":0},{"day":"2026-08-10","value":
            0},{"day":"2026-08-11","value":0},{"day":"2026-08-12","value":0},{"day":"2026-08-13",
            "value":0},{"day":"2026-08-14","value":0},{"day":"2026-08-15","value":0},{"day":
            "2026-08-16","value":0},{"day":"2026-08-17","value":0},{"day":"2026-08-18","value":
            6},{"day":"2026-08-19","value":6},{"day":"2026-08-20","value":5},{"day":"2026-08-21",
            "value":10},{"day":"2026-08-22","value":6},{"day":"2026-08-23","value":5},{"day":
            "2026-08-24","value":4},{"day":"2026-08-25","value":6},{"day":"2026-08-26","value":
            10},{"day":"2026-08-27","value":6},{"day":"2026-08-28","value":6},{"day":"2026-08-29",
            "value":6},{"day":"2026-08-30","value":4},{"day":"2026-08-31","value":8},{"day":
            "2026-09-01","value":6},{"day":"2026-09-02","value":7},{"day":"2026-09-03","value":
            4},{"day":"2026-09-04","value":9},{"day":"2026-09-05","value":8},{"day":"2026-09-06",
            "value":6},{"day":"2026-09-07","value":8},{"day":"2026-09-08","value":8},{"day":
            "2026-09-09","value":4},{"day":"2026-09-10","value":6},{"day":"2026-09-11","value":
            7},{"day":"2026-09-12","value":5},{"day":"2026-09-13","value":4},{"day":"2026-09-14",
            "value":3},{"day":"2026-09-15","value":8},{"day":"2026-09-16","value":9},{"day":
            "2026-09-17","value":11},{"day":"2026-09-18","value":10},{"day":"2026-09-19","value":
            11},{"day":"2026-09-20","value":12},{"day":"2026-09-21","value":6},{"day":"2026-09-22",
            "value":12},{"day":"2026-09-23","value":9},{"day":"2026-09-24","value":11},{"day":
            "2026-09-25","value":11},{"day":"2026-09-26","value":9},{"day":"2026-09-27","value":
            11},{"day":"2026-09-28","value":12},{"day":"2026-09-29","value":12},{"day":"2026-09-30",
            "value":15},{"day":"2026-10-01","value":11},{"day":"2026-10-02","value":8},{"day":
            "2026-10-03","value":8},{"day":"2026-10-04","value":8},{"day":"2026-10-05","value":
            10},{"day":"2026-10-06","value":11},{"day":"2026-10-07","value":15},{"day":"2026-10-08",
            "value":10},{"day":"2026-10-09","value":9},{"day":"2026-10-10","value":12},{"day":
            "2026-10-11","value":11},{"day":"2026-10-12","value":12},{"day":"2026-10-13","value":
            10},{"day":"2026-10-14","value":10},{"day":"2026-10-15","value":14},{"day":"2026-10-16",
            "value":12},{"day":"2026-10-17","value":8},{"day":"2026-10-18","value":14},{"day":
            "2026-10-19","value":4},{"day":"2026-10-20","value":0},{"day":"2026-10-21","value":
            0},{"day":"2026-10-22","value":0},{"day":"2026-10-23","value":0},{"day":"2026-10-24",
            "value":0},{"day":"2026-10-25","value":0},{"day":"2026-10-26","value":0},{"day":
            "2026-10-27","value":0},{"day":"2026-10-28","value":0},{"day":"2026-10-29","value":
            0},{"day":"2026-10-30","value":0},{"day":"2026-10-31","value":0},{"day":"2026-11-01",
            "value":0},{"day":"2026-11-02","value":0},{"day":"2026-11-03","value":0},{"day":
            "2026-11-04","value":0},{"day":"2026-11-05","value":0},{"day":"2026-11-06","value":
            0},{"day":"2026-11-07","value":0},{"day":"2026-11-08","value":0},{"day":"2026-11-09",
            "value":0},{"day":"2026-11-10","value":0},{"day":"2026-11-11","value":0},{"day":
            "2026-11-12","value":0},{"day":"2026-11-13","value":0},{"day":"2026-11-14","value":
            0},{"day":"2026-11-15","value":0},{"day":"2026-11-16","value":0},{"day":"2026-11-17",
            "value":0},{"day":"2026-11-18","value":0},{"day":"2026-11-19","value":0},{"day":
            "2026-11-20","value":0},{"day":"2026-11-21","value":0},{"day":"2026-11-22","value":
            0},{"day":"2026-11-23","value":0},{"day":"2026-11-24","value":0},{"day":"2026-11-25",
            "value":0},{"day":"2026-11-26","value":0},{"day":"2026-11-27","value":0},{"day":
            "2026-11-28","value":0},{"day":"2026-11-29","value":0},{"day":"2026-11-30","value":
            0},{"day":"2026-12-01","value":0},{"day":"2026-12-02","value":0},{"day":"2026-12-03",
            "value":0},{"day":"2026-12-04","value":0},{"day":"2026-12-05","value":0},{"day":
            "2026-12-06","value":0},{"day":"2026-12-07","value":0},{"day":"2026-12-08","value":
            0},{"day":"2026-12-09","value":0},{"day":"2026-12-10","value":0},{"day":"2026-12-11",
            "value":0},{"day":"2026-12-12","value":0},{"day":"2026-12-13","value":0},{"day":
            "2026-12-14","value":0},{"day":"2026-12-15","value":0},{"day":"2026-12-16","value":
            0},{"day":"2026-12-17","value":0},{"day":"2026-12-18","value":0},{"day":"2026-12-19",
            "value":0},{"day":"2026-12-20","value":0},{"day":"2026-12-21","value":0},{"day":
            "2026-12-22","value":0},{"day":"2026-12-23","value":0},{"day":"2026-12-24","value":
            0},{"day":"2026-12-25","value":0},{"day":"2026-12-26","value":0},{"day":"2026-12-27",
            "value":0},{"day":"2026-12-28","value":0},{"day":"2026-12-29","value":0},{"day":
            "2026-12-30","value":0},{"day":"2026-12-31","value":0}],"unit":"条","label":"记录量"}
            """#
    }
#endif
