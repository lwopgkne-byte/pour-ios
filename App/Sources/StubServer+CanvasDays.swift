#if DEBUG
    import Foundation

    /// 第 5 节那几种人的一天（docs/模块/生活画布2.0.md）：上班族照演示数据里那个人，别的照方案里写的样子
    extension CanvasSample {
        static let office = CanvasSample(
            entries: #"""
                [{"kind":"event","category":"sleep",
                  "data":{"label":"睡觉","start":"{D}T00:10","end":"{D}T07:10","durationMin":420}},
                {"kind":"event","category":"diet","data":{"label":"16:8 轻断食"}},
                {"kind":"event","category":"c-trip",
                  "data":{"label":"坐地铁","start":"{D}T08:20","end":"{D}T08:55","places":["地铁"]}},
                {"kind":"event","category":"work",
                  "data":{"label":"上班","start":"{D}T09:00","end":"{D}T18:00","durationMin":540}},
                {"kind":"event","category":"diet",
                  "data":{"label":"和小李吃午饭","start":"{D}T12:10","end":"{D}T12:50","people":["小李"],
                  "metrics":[{"name":"花费","value":26,"unit":"元"}]}},
                {"kind":"event","category":"c-baby",
                  "data":{"label":"接儿子放学","start":"{D}T17:30","people":["儿子"],"places":["学校"]}},
                {"kind":"event","category":"strength",
                  "data":{"label":"力量训练","start":"{D}T20:00","end":"{D}T20:45","durationMin":45,
                  "places":["健身房"],"metrics":[{"name":"卧推重量","value":60,"unit":"公斤"}]}},
                {"kind":"event","category":"c-fun","data":{"label":"追剧","durationMin":90,"people":["老婆"]}},
                {"kind":"event","category":"study",
                  "data":{"label":"看书","durationMin":46,"things":["《人类简史》"],
                  "metrics":[{"name":"页数","value":33,"unit":"页"}]}},
                {"kind":"event","category":"study","data":{"label":"背单词","durationMin":30}},
                {"kind":"event","category":"c-shop","question":"六十九是两箱牛奶一共的钱吗？",
                  "data":{"label":"网购牛奶","start":"{D}T22:20","things":["牛奶"],
                  "metrics":[{"name":"花费","value":69,"unit":"元"}]}},
                {"kind":"event","category":"c-task",
                  "data":{"label":"房贷","metrics":[{"name":"花费","value":6800,"unit":"元","monthly":true}]}},
                {"kind":"todo","category":"todo","data":{"content":"送车去保养","done":false,"remindAt":"{D}T19:00"}},
                {"kind":"todo","category":"todo","data":{"content":"交电费","done":true}},
                {"kind":"mood","category":"mood","at":"13:10",
                  "data":{"mood":4,"energy":4,"emotions":["放松"],"moment":"午休听见楼下有人在拉二胡"}},
                {"kind":"mood","category":"mood","at":"21:40","data":{"mood":2,"energy":2,"emotions":["累"]}},
                {"kind":"insight","category":"insight",
                  "data":{"title":"专注比时间长更重要","tags":["专注","效率"],
                  "quote":"关掉消息专心做一件事 两个小时顶一天 以后应该每天留出这么一段"},
                  "related":[{"day":"{Y}","text":"上午不看手机，效率高了很多"}]}]
                """#,
            summary: "上班 9 小时，晚上去健身房练了力量。中午听见楼下有人拉二胡，心情不错；到了晚上有点累。",
            goals: #"""
                [{"id":2,"title":"连续 30 天 16:8 轻断食","tone":"good","pct":0.13,"headline":"连续 4 天 · 最长 13 天",
                  "delta":"连续第 4 天","category":"diet"},
                {"id":3,"title":"每周运动 3 次","tone":"good","pct":1,"headline":"已完成 3 次 · 已达成",
                  "delta":"+1 次","category":"exercise"},
                {"id":4,"title":"每天读 30 页书","tone":"warn","pct":0.6,"headline":"这周 4 天读够了",
                  "delta":"+33 页","category":"study"}]
                """#)

        static let mom = CanvasSample(
            entries: #"""
                [{"kind":"event","category":"sleep","data":{"label":"睡觉","start":"{Y}T22:50","end":"{D}T00:20"}},
                {"kind":"event","category":"sleep","data":{"label":"睡觉","start":"{D}T01:10","end":"{D}T03:30"}},
                {"kind":"event","category":"sleep","data":{"label":"睡觉","start":"{D}T04:10","end":"{D}T06:40"}},
                {"kind":"event","category":"c-baby","data":{"label":"喂奶","start":"{D}T00:30","durationMin":20}},
                {"kind":"event","category":"c-baby","data":{"label":"喂奶","start":"{D}T03:40","durationMin":20}},
                {"kind":"event","category":"c-baby","data":{"label":"喂奶","start":"{D}T06:50","durationMin":20}},
                {"kind":"event","category":"c-baby","data":{"label":"喂奶","start":"{D}T09:30","durationMin":20}},
                {"kind":"event","category":"c-baby","data":{"label":"喂奶","start":"{D}T12:40","durationMin":20}},
                {"kind":"event","category":"c-baby","data":{"label":"喂奶","start":"{D}T16:00","durationMin":20}},
                {"kind":"event","category":"c-baby","data":{"label":"喂奶","start":"{D}T19:20","durationMin":20}},
                {"kind":"event","category":"c-baby","data":{"label":"换尿布","start":"{D}T01:00"}},
                {"kind":"event","category":"c-baby","data":{"label":"换尿布","start":"{D}T07:10"}},
                {"kind":"event","category":"c-baby","data":{"label":"换尿布","start":"{D}T10:30"}},
                {"kind":"event","category":"c-baby","data":{"label":"换尿布","start":"{D}T14:00"}},
                {"kind":"event","category":"c-baby","data":{"label":"换尿布","start":"{D}T17:40"}},
                {"kind":"event","category":"c-baby","data":{"label":"换尿布","start":"{D}T21:10"}},
                {"kind":"event","category":"c-shop",
                  "data":{"label":"奶粉","things":["奶粉"],"metrics":[{"name":"花费","value":298,"unit":"元","for":"孩子"}]}},
                {"kind":"todo","category":"todo","data":{"content":"预约儿保","done":false,"remindAt":"{D}T15:00"}},
                {"kind":"mood","category":"mood","at":"20:30",
                  "data":{"mood":3,"energy":2,"emotions":["累","满足"],"moment":"孩子第一次冲我笑了"}}]
                """#,
            summary: "夜里喂了三次奶，断断续续睡了 6 个多小时。给孩子买了奶粉，晚上孩子第一次冲你笑了。",
            goals: "[]")

        static let student = CanvasSample(
            entries: #"""
                [{"kind":"event","category":"study","data":{"label":"高数","start":"{D}T08:00","end":"{D}T09:40"}},
                {"kind":"event","category":"study",
                  "data":{"label":"自习","start":"{D}T14:00","end":"{D}T16:30","places":["图书馆"]}},
                {"kind":"event","category":"study","data":{"label":"英语","start":"{D}T19:00","end":"{D}T20:50"}},
                {"kind":"event","category":"run",
                  "data":{"label":"跑步","start":"{D}T17:30","end":"{D}T17:52","durationMin":22,"places":["操场"],
                  "metrics":[{"name":"距离","value":3,"unit":"公里"}]}},
                {"kind":"event","category":"diet",
                  "data":{"label":"早饭","start":"{D}T07:30","metrics":[{"name":"花费","value":6,"unit":"元"}]}},
                {"kind":"event","category":"diet",
                  "data":{"label":"午饭","start":"{D}T12:00","metrics":[{"name":"花费","value":15,"unit":"元"}]}},
                {"kind":"event","category":"diet",
                  "data":{"label":"晚饭","start":"{D}T18:10","metrics":[{"name":"花费","value":15,"unit":"元"}]}},
                {"kind":"todo","category":"todo","data":{"content":"交线代作业","done":false,"remindAt":"{D}T23:00"}},
                {"kind":"insight","category":"insight",
                  "data":{"title":"拆成小步","quote":"不会的题拆成小步一步一步来 其实没那么难","tags":["学习"]}}]
                """#,
            summary: "学了 6 个小时，傍晚去操场跑了 3 公里。三餐都在食堂，一共 ¥36。",
            goals: #"""
                [{"id":5,"title":"每周跑 10 公里","tone":"warn","pct":0.5,"headline":"已跑 5 公里 · 稍微落后",
                  "delta":"+3 公里","category":"exercise"}]
                """#)

        static let elder = CanvasSample(
            entries: #"""
                [{"kind":"event","category":"c-health",
                  "data":{"label":"量血压","start":"{D}T07:30",
                  "metrics":[{"name":"收缩压","value":135,"unit":"mmHg"},{"name":"舒张压","value":85,"unit":"mmHg"}]}},
                {"kind":"event","category":"c-health","data":{"label":"吃药","start":"{D}T08:00","things":["降压药"]}},
                {"kind":"event","category":"c-health","data":{"label":"吃药","start":"{D}T12:30"}},
                {"kind":"event","category":"c-health","data":{"label":"吃药","start":"{D}T19:00"}},
                {"kind":"event","category":"exercise",
                  "data":{"label":"散步","start":"{D}T06:30","end":"{D}T07:10","durationMin":40,"places":["公园"]}},
                {"kind":"event","category":"exercise",
                  "data":{"label":"太极","start":"{D}T16:00","end":"{D}T16:30","durationMin":30}},
                {"kind":"event","category":"c-family",
                  "data":{"label":"带孙子上书法课","start":"{D}T09:00","end":"{D}T11:00","people":["孙子"]}},
                {"kind":"event","category":"c-house","data":{"label":"做午饭","start":"{D}T11:10","end":"{D}T12:00"}},
                {"kind":"event","category":"c-house","data":{"label":"浇花"}}]
                """#,
            summary: "早上在公园散步 40 分钟，血压 135/85。上午带孙子去上书法课，下午打了一会儿太极。",
            goals: #"""
                [{"id":6,"title":"每天走 30 分钟","tone":"good","pct":1,"headline":"连续 12 天",
                  "delta":"+40 分钟","category":"exercise"}]
                """#)

        static let shop = CanvasSample(
            entries: #"""
                [{"kind":"event","category":"c-trip",
                  "data":{"label":"开车去批发市场","start":"{D}T06:00","end":"{D}T06:30"}},
                {"kind":"event","category":"work",
                  "data":{"label":"进货","start":"{D}T06:30","end":"{D}T08:00",
                  "metrics":[{"name":"花费","value":1800,"unit":"元"}]}},
                {"kind":"event","category":"work",
                  "data":{"label":"开店","start":"{D}T09:00","end":"{D}T19:00",
                  "metrics":[{"name":"收入","value":3200,"unit":"元"}]}},
                {"kind":"event","category":"work",
                  "data":{"label":"拜访客户","start":"{D}T15:00","people":["老张","王姐","小刘"]}},
                {"kind":"event","category":"diet",
                  "data":{"label":"午饭","start":"{D}T12:30","metrics":[{"name":"花费","value":60,"unit":"元"}]}}]
                """#,
            summary: "开店 10 个小时，营业额 ¥3,200。一早去批发市场进了 ¥1,800 的货，下午拜访了三位老客户。",
            goals: #"""
                [{"id":7,"title":"这个月营业额 8 万","tone":"warn","pct":0.35,"headline":"已完成 2.8 万 · 稍微落后",
                  "delta":"+¥3,200","category":"work"}]
                """#)

        static let quiet = CanvasSample(
            entries: #"""
                [{"kind":"insight","category":"insight",
                  "data":{"title":"先做完再改","quote":"其实不用把每件事都做到完美 先做完 再慢慢改","tags":["工作","心态"]},
                  "related":[{"day":"{Y}","text":"完成比完美更重要"}]}]
                """#,
            summary: "今天想明白了一件事：先做完，再慢慢改。",
            goals: "[]")
    }
#endif
