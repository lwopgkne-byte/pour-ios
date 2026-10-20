#if DEBUG
    import Foundation

    /// 关于我的演示数据（续）：心情从哪来（这 30 天）、心情按天的变化（5199 演示服务器拿的，原样）
    extension AboutStub {
        static let sources = #"""
            {"range":{"from":"2026-09-21","to":"2026-10-20","label":"这 30 天"},"when":{"good":
            {"purpose":4,"daily":4,"glimpse":4},"bad":{"purpose":5,"daily":1,"glimpse":1}},
            "goodTotal":12,"badTotal":7,"noMoment":9,"mirror":[{"key":"work","domain":"工作",
            "emoji":"💼","hasGoal":false,"timeShare":74,"timeUnder1":false,"goodShare":25},
            {"key":"study","domain":"学习","emoji":"📚","hasGoal":true,"timeShare":9,"timeUnder1":
            false,"goodShare":8},{"key":"c-c916946f","domain":"娱乐","emoji":"🎬","hasGoal":false,
            "timeShare":5,"timeUnder1":false,"goodShare":8},{"key":"c-8dc516e6","domain":"家人朋友",
            "emoji":"👨‍👩‍👧","hasGoal":false,"timeShare":3,"timeUnder1":false,"goodShare":8},
            {"key":"c-f4b9b270","domain":"宠物","emoji":"🐕","hasGoal":false,"timeShare":0,"timeUnder1":
            true,"goodShare":8},{"key":"diet","domain":"饮食","emoji":"🍽","hasGoal":true,"timeShare":
            null,"timeUnder1":false,"goodShare":8},{"key":"glimpse","domain":"不算一件事","emoji":
            "","hasGoal":false,"timeShare":null,"timeUnder1":false,"goodShare":33}],"people":
            [{"name":"客户","good":1,"bad":2},{"name":"领导","good":0,"bad":2},{"name":"没提到别人",
            "good":8,"bad":2}],"emotions":{"good":[{"word":"开心","count":6},{"word":"放松","count":
            3},{"word":"满足","count":2}],"bad":[{"word":"烦躁","count":2},{"word":"生气","count":
            2},{"word":"失落","count":2},{"word":"委屈","count":1}]},"enough":{"good":true,"bad":
            true,"time":true},"short":{},"examples":{"when:good:glimpse":[{"entryId":596,"day":
            "2026-10-18","moment":"晚上楼下飘上来烤红薯的香味","noteId":365},{"entryId":557,"day":"2026-10-15",
            "moment":"午休听见楼下有人在拉二胡","noteId":348},{"entryId":506,"day":"2026-10-11","moment":
            "等红灯的时候看见一只小狗冲我摇尾巴","noteId":324}],"domain:glimpse":[{"entryId":596,"day":"2026-10-18",
            "moment":"晚上楼下飘上来烤红薯的香味","noteId":365},{"entryId":557,"day":"2026-10-15","moment":
            "午休听见楼下有人在拉二胡","noteId":348},{"entryId":506,"day":"2026-10-11","moment":"等红灯的时候看见一只小狗冲我摇尾巴",
            "noteId":324}],"person:没提到别人":[{"entryId":596,"day":"2026-10-18","moment":"晚上楼下飘上来烤红薯的香味",
            "noteId":365},{"entryId":586,"day":"2026-10-18","moment":"下午方案被改了三遍","noteId":
            362},{"entryId":557,"day":"2026-10-15","moment":"午休听见楼下有人在拉二胡","noteId":348}],
            "when:bad:purpose":[{"entryId":586,"day":"2026-10-18","moment":"下午方案被改了三遍","noteId":
            362},{"entryId":461,"day":"2026-10-07","moment":"上午11点跟客户打电话吵了一架","noteId":303},
            {"entryId":369,"day":"2026-09-29","moment":"下午4点客户临时改需求 又要重做","noteId":256}],"when:bad:glimpse":
            [{"entryId":571,"day":"2026-10-16","moment":"和小王开完会","noteId":353}],"person:小王":
            [{"entryId":571,"day":"2026-10-16","moment":"和小王开完会","noteId":353}],"when:good:purpose":
            [{"entryId":543,"day":"2026-10-14","moment":"晚上10点 三体终于看完了","noteId":342},{"entryId":
            445,"day":"2026-10-06","moment":"下午3点把拖了两周的方案写完了","noteId":293},{"entryId":384,
            "day":"2026-09-30","moment":"上午评审很顺利","noteId":262}],"domain:study":[{"entryId":
            543,"day":"2026-10-14","moment":"晚上10点 三体终于看完了","noteId":342}],"when:bad:daily":
            [{"entryId":532,"day":"2026-10-13","moment":"早上8点地铁坏了 上班迟到","noteId":337}],"when:good:daily":
            [{"entryId":496,"day":"2026-10-10","moment":"晚上7点和老同学吃了顿火锅","noteId":319},{"entryId":
            473,"day":"2026-10-08","moment":"晚上9点陪猫玩了半小时逗猫棒","noteId":309},{"entryId":343,
            "day":"2026-09-27","moment":"上午10点和老婆去花鸟市场逛了一圈","noteId":242}],"domain:diet":[
            {"entryId":496,"day":"2026-10-10","moment":"晚上7点和老同学吃了顿火锅","noteId":319}],"person:老同学":
            [{"entryId":496,"day":"2026-10-10","moment":"晚上7点和老同学吃了顿火锅","noteId":319}],"domain:c-f4b9b270":
            [{"entryId":473,"day":"2026-10-08","moment":"晚上9点陪猫玩了半小时逗猫棒","noteId":309}],"person:客户":
            [{"entryId":461,"day":"2026-10-07","moment":"上午11点跟客户打电话吵了一架","noteId":303},{"entryId":
            369,"day":"2026-09-29","moment":"下午4点客户临时改需求 又要重做","noteId":256},{"entryId":320,
            "day":"2026-09-25","moment":"给客户的提案一次就过了","noteId":230}],"domain:work":[{"entryId":
            445,"day":"2026-10-06","moment":"下午3点把拖了两周的方案写完了","noteId":293},{"entryId":384,
            "day":"2026-09-30","moment":"上午评审很顺利","noteId":262},{"entryId":320,"day":"2026-09-25",
            "moment":"给客户的提案一次就过了","noteId":230}],"person:领导":[{"entryId":356,"day":"2026-09-28",
            "moment":"加班到十点 领导还是不满意","noteId":249},{"entryId":287,"day":"2026-09-22","moment":
            "上午10点开会被领导当众点名","noteId":213}],"domain:c-c916946f":[{"entryId":343,"day":"2026-09-27",
            "moment":"上午10点和老婆去花鸟市场逛了一圈","noteId":242}],"person:老婆":[{"entryId":343,"day":
            "2026-09-27","moment":"上午10点和老婆去花鸟市场逛了一圈","noteId":242}],"domain:c-8dc516e6":[
            {"entryId":309,"day":"2026-09-24","moment":"晚上8点陪儿子拼完了一个乐高","noteId":224}],"person:儿子":
            [{"entryId":309,"day":"2026-09-24","moment":"晚上8点陪儿子拼完了一个乐高","noteId":224}]},"candidates":
            ["这 30 天醒着的时间有 74% 花在工作上，好时刻里工作占 25%","好时刻里有 33% 是在做有目标的事时，不好的时刻里是 71%"]}
            """#

        static let moodTrend = #"""
            {"metric":{"id":"mood:mood","name":"心情","emoji":"💭","color":"pink","category":
            null,"kind":"mood","measure":"mood","unit":"分","how":"avg"},"dim":"day","points":
            [{"label":"9/21","from":"2026-09-21","value":3},{"label":"9/22","from":"2026-09-22",
            "value":2},{"label":"9/23","from":"2026-09-23","value":4},{"label":"9/24","from":
            "2026-09-24","value":4},{"label":"9/25","from":"2026-09-25","value":5},{"label":
            "9/26","from":"2026-09-26","value":4},{"label":"9/27","from":"2026-09-27","value":
            4},{"label":"9/28","from":"2026-09-28","value":1},{"label":"9/29","from":"2026-09-29",
            "value":2},{"label":"9/30","from":"2026-09-30","value":3},{"label":"10/1","from":
            "2026-10-01","value":5},{"label":"10/2","from":"2026-10-02","value":null},{"label":
            "10/3","from":"2026-10-03","value":3},{"label":"10/4","from":"2026-10-04","value":
            3},{"label":"10/5","from":"2026-10-05","value":null},{"label":"10/6","from":"2026-10-06",
            "value":4},{"label":"10/7","from":"2026-10-07","value":2},{"label":"10/8","from":
            "2026-10-08","value":4},{"label":"10/9","from":"2026-10-09","value":3},{"label":
            "10/10","from":"2026-10-10","value":5},{"label":"10/11","from":"2026-10-11","value":
            4},{"label":"10/12","from":"2026-10-12","value":3},{"label":"10/13","from":"2026-10-13",
            "value":2},{"label":"10/14","from":"2026-10-14","value":4},{"label":"10/15","from":
            "2026-10-15","value":4},{"label":"10/16","from":"2026-10-16","value":2},{"label":
            "10/17","from":"2026-10-17","value":4},{"label":"10/18","from":"2026-10-18","value":
            3},{"label":"10/19","from":"2026-10-19","value":null},{"label":"10/20","from":
            "2026-10-20","value":null}],"each":[[3],[2],[4],[4],[5],[4],[4],[1],[2],[4,2],
            [5],[],[3],[3],[],[4],[2],[4],[3],[5],[4],[3],[2],[4],[4],[2],[4],[2,4],[],[]],
            "trend":[3,2.5,3,3.25,3.6,3.6666666666666665,3.7142857142857144,3.4285714285714284,
            3.4285714285714284,3.2857142857142856,3.4285714285714284,3.1666666666666665,3,
            2.8333333333333335,3.2,3.6,3.4,3.2,3.1666666666666665,3.5,3.6666666666666665,3.5714285714285716,
            3.2857142857142856,3.5714285714285716,3.5714285714285716,3.4285714285714284,3.2857142857142856,
            3.142857142857143,3.1666666666666665,3.4],"yoy":null,"target":null,"summary":{
            "label":"平均","value":3.3461538461538463}}
            """#
    }
#endif
