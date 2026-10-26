#if DEBUG
    import Foundation

    extension StubServer.State {
        /// 回顾：从演示数据里拿的回顾列表、10月18日的每日回顾、10月12日那一周的周报、自动检查发现的一处
        /// （日子是演示数据的日子，界面测试只看页面打得开、点得动）
        func reviewReply(_ method: String, _ path: String) -> Any? {
            switch (method, path) {
            case ("GET", "/api/review"): return Self.json(Self.list)
            case ("GET", let other) where other.hasPrefix("/api/review/daily/"): return Self.json(Self.daily)
            case ("GET", let other) where other.hasPrefix("/api/review/period/"): return Self.json(Self.weekly)
            case ("GET", let other) where other.hasPrefix("/api/audit/day/"): return Self.json(Self.audit)
            case ("POST", let other) where other.hasPrefix("/api/messages/") || other.hasPrefix("/api/audit/"):
                return ["ok": true]
            default: return nil
            }
        }

        private static func json(_ text: String) -> Any {
            (try? JSONSerialization.jsonObject(with: Data(text.utf8))) ?? [String: Any]()
        }

        private static let list = #"""
            {"items":[{"id":84,"kind":"weekly","title":"10月12日–18日 周报",
            "summary":"这周运动 3 小时 2 分（比上周多 38 分钟），睡眠每晚平均 7 小时 16 分。","day":null,"from":"2026-10-12",
            "createdAt":"2026-10-19T02:05:00.000Z","read":false},{"id":83,"kind":"daily","title":"10月18日 周日",
            "summary":"睡了 8 小时 20 分，16:8 轻断食，看书 42 页，背单词。","day":"2026-10-18","from":null,
            "createdAt":"2026-10-19T02:00:00.000Z","read":false},{"id":82,"kind":"daily","title":"10月17日 周六",
            "summary":"睡了 8 小时 20 分，跑步 9.9 公里，16:8 轻断食，超市买菜 洗衣液 ¥45、面包 ¥16、葡萄 ¥28、牛肉 ¥89。","day":"2026-10-17",
            "from":null,"createdAt":"2026-10-18T02:00:00.000Z","read":true},{"id":81,"kind":"warning","title":"有件事需要留意",
            "summary":"连续 3 天入睡晚于目标 00:00（00:10、00:30、00:10）","day":null,"from":null,
            "createdAt":"2026-10-17T15:00:00.000Z","read":false}]}
            """#

        private static let daily = #"""
            {"review":{"day":"2026-10-18","numbers":[{"key":"sleep","label":"睡眠","parts":[{"n":"8","u":"小时"},{"n":"20",
            "u":"分"}],"text":"8 小时 20 分","compare":"和平常的周末差不多","notable":false},{"key":"focus","label":"专注",
            "parts":[{"n":"2","u":"小时"},{"n":"24","u":"分"}],"text":"2 小时 24 分","compare":"比平常的周末多 1 小时 30 分钟",
            "notable":true},{"key":"mood","label":"心情","parts":[{"n":"有起有落","u":""}],"text":"有起有落",
            "compare":"比平常的周末差一些","notable":true}],"entries":[{"id":581,"day":"2026-10-18","kind":"event",
            "category":"sleep","data":{"label":"睡觉","start":"2026-10-18T00:20","end":"2026-10-18T08:40",
            "durationMin":500},"confidence":0.9,"status":"ok"},{"id":582,"day":"2026-10-18","kind":"event",
            "category":"diet","data":{"label":"16:8 轻断食"},"confidence":0.9,"status":"ok"},{"id":583,"day":"2026-10-18",
            "kind":"event","category":"c-09897138","data":{"label":"量血压","metrics":[{"name":"收缩压","value":130,
            "unit":"mmHg"},{"name":"舒张压","value":83,"unit":"mmHg"}]},"confidence":0.9,"status":"ok"},{"id":584,
            "day":"2026-10-18","kind":"event","category":"c-09897138","data":{"label":"称体重","metrics":[{"name":"体重",
            "value":70.8,"unit":"公斤"}]},"confidence":0.9,"status":"ok"},{"id":585,"day":"2026-10-18","kind":"event",
            "category":"work","data":{"label":"改方案"},"confidence":0.9,"status":"ok"},{"id":586,"day":"2026-10-18",
            "kind":"mood","category":"mood","data":{"mood":2,"emotions":["烦躁"],"tone":"bad","strength":"medium",
            "moment":"下午方案被改了三遍"},"confidence":0.75,"status":"ok"},{"id":587,"day":"2026-10-18","kind":"event",
            "category":"work","data":{"label":"开会","start":"2026-10-19T03:00","end":"2026-10-19T04:00",
            "durationMin":60},"confidence":0.9,"status":"ok"},{"id":588,"day":"2026-10-18","kind":"event",
            "category":"c-c916946f","data":{"label":"看电影","people":["老婆","儿子"],"places":["电影院"],
            "start":"2026-10-18T17:00","end":"2026-10-18T18:50","durationMin":110,"metrics":[{"name":"花费","value":150,
            "unit":"元","item":"电影票"}]},"confidence":0.9,"status":"ok"},{"id":589,"day":"2026-10-18","kind":"event",
            "category":"c-b7328bba","data":{"label":"整理衣柜","durationMin":40},"confidence":0.9,"status":"ok"},{"id":590,
            "day":"2026-10-18","kind":"event","category":"c-f4b9b270","data":{"label":"买猫粮","metrics":[{"name":"花费",
            "value":120,"unit":"元"}],"tags":["囤货"]},"confidence":0.9,"status":"ok"},{"id":591,"day":"2026-10-18",
            "kind":"event","category":"c-f4b9b270","data":{"label":"打疫苗","metrics":[{"name":"花费","value":80,
            "unit":"元"}],"tags":["健康管理"]},"confidence":0.9,"status":"ok"},{"id":592,"day":"2026-10-18","kind":"event",
            "category":"study","data":{"label":"看书","durationMin":59,"things":["《人类简史》"],"metrics":[{"name":"页数",
            "value":42,"unit":"页"}]},"confidence":0.9,"status":"ok"},{"id":593,"day":"2026-10-18","kind":"event",
            "category":"study","data":{"label":"背单词","durationMin":25},"confidence":0.9,"status":"ok"},{"id":594,
            "day":"2026-10-18","kind":"event","category":"c-84f6a689","data":{"label":"给儿子买运动鞋","people":["儿子"],
            "things":["运动鞋"],"metrics":[{"name":"花费","value":259,"unit":"元","for":"儿子"}]},"confidence":0.9,
            "status":"ok"},{"id":595,"day":"2026-10-18","kind":"todo","category":"todo","data":{"content":"给客户回电话",
            "done":false,"due":"2026-10-19","remindAt":"2026-10-19T10:00","people":["客户"]},"confidence":0.95,
            "status":"ok"},{"id":596,"day":"2026-10-18","kind":"mood","category":"mood","data":{"mood":4,
            "emotions":["放松"],"tone":"good","strength":"medium","moment":"晚上楼下飘上来烤红薯的香味"},"confidence":0.75,
            "status":"ok"}],"groups":[{"key":"diet","emoji":"🍽","name":"饮食","items":[{"entryId":582,
            "text":"16:8 轻断食"}]},{"key":"study","emoji":"📚","name":"学习","items":[{"entryId":592,
            "text":"看书 42 页 · 59 分钟"},{"entryId":593,"text":"背单词 · 25 分钟"}]},{"key":"work","emoji":"💼","name":"工作",
            "items":[{"entryId":585,"text":"改方案"},{"entryId":587,"text":"开会 · 1 小时"}]},{"key":"c-09897138","emoji":"🩺",
            "name":"健康","items":[{"entryId":583,"text":"量血压 收缩压 130 mmHg、舒张压 83 mmHg"},{"entryId":584,
            "text":"称体重 70.8 公斤"}]},{"key":"c-84f6a689","emoji":"🛒","name":"购物","items":[{"entryId":594,
            "text":"给儿子买运动鞋 ¥259"}]},{"key":"c-b7328bba","emoji":"🧹","name":"家务","items":[{"entryId":589,
            "text":"整理衣柜 · 40 分钟"}]},{"key":"c-c916946f","emoji":"🎬","name":"娱乐","items":[{"entryId":588,
            "text":"看电影 电影票 ¥150 · 1 小时 50 分钟 · 在电影院 · 和老婆、儿子"}]},{"key":"c-f4b9b270","emoji":"🐕","name":"宠物",
            "items":[{"entryId":590,"text":"买猫粮 ¥120"},{"entryId":591,"text":"打疫苗 ¥80"}]}],"goals":[{"id":2,
            "title":"连续 30 天 16:8 轻断食","tone":"good","pct":0.23333333333333334,"headline":"连续 7 天 · 最长 13 天",
            "delta":"连续第 7 天","category":"diet"},{"id":5,"title":"平均睡眠 7.5 小时","tone":"warn","pct":0.9682539682539683,
            "headline":"实际 7.3 小时 · 差 0.2 小时","delta":"当天 8.3 小时","category":"sleep"},{"id":7,"title":"体重降到 69.5 公斤",
            "tone":"warn","pct":0.9740714786264892,"headline":"实际 71.4 公斤 · 多 1.8 公斤","delta":"当天 70.8 公斤",
            "category":"c-09897138"},{"id":9,"title":"每周背单词 4 次","tone":"good","pct":1,"headline":"已完成 5 次 · 已达成",
            "delta":"+1 次","category":"study"}],"moods":[{"entryId":586,"mood":2,"emotions":["烦躁"],"moment":"下午方案被改了三遍",
            "at":"16:20"},{"entryId":596,"mood":4,"emotions":["放松"],"moment":"晚上楼下飘上来烤红薯的香味","at":"21:50"}],
            "insights":[],"open":{"todos":[{"entryId":595,"content":"给客户回电话"}],"pending":[]},"today":{"todos":["给客户回电话",
            "交水费（本来是 10月17日 周六 要做的）"],"goals":["「今年跑 500 公里」还差 398.1 公里，还剩 74 天，平均每天 5.4 公里（落后 35%）",
            "「连续 30 天 16:8 轻断食」已经连续 8 天，今天做到就是第 9 天","「每周运动 3 次」这周还差 2 次，还剩 7 天",
            "「平均睡眠 7.5 小时」这周平均 6.8 小时，剩下的天里平均每天要 7.6 小时"]},"notes":5,"overview":"睡了 8 小时 20 分，16:8 轻断食，看书 42 页，背单词。",
            "observation":"专注 2 小时 24 分，比平常的周末多 1 小时 30 分钟。","updated":false},"messageId":83,"read":false,
            "prev":"2026-10-17","next":null,"weekly":"2026-10-12",
            "quote":{"entryId":3301,"text":"付出不亚于任何人的努力","day":"2026-10-12","noteId":3301,"asked":true}}
            """#

        private static let weekly = #"""
            {"review":{"kind":"weekly","period":{"from":"2026-10-12","to":"2026-10-18"},"title":"10月12日 – 18日",
            "overview":"这周运动 3 小时 2 分（比上周多 38 分钟），睡眠每晚平均 7 小时 16 分。","updated":false,"sparse":false,"daysRecorded":7,
            "totalDays":7,"notes":41,"numbers":[{"key":"sleep","label":"睡眠 · 每晚平均","parts":[{"n":"7","u":"小时"},
            {"n":"16","u":"分"}],"text":"7 小时 16 分","compare":"和上周差不多","notable":false},{"key":"exercise",
            "label":"运动 · 4 次","parts":[{"n":"3","u":"小时"},{"n":"2","u":"分"}],"text":"3 小时 2 分","compare":"比上周多 38 分钟",
            "notable":true},{"key":"focus","label":"专注 · 工作和学习","parts":[{"n":"59","u":"小时"},{"n":"27","u":"分"}],
            "text":"59 小时 27 分","compare":"比上周多 7 小时 30 分钟","notable":false},{"key":"mood","label":"心情 · 8 条",
            "parts":[{"n":"一般","u":""}],"text":"一般","compare":"比上周差一些","notable":false}],"days":[{"day":"2026-10-12",
            "recorded":true,"mood":"一般","level":3},{"day":"2026-10-13","recorded":true,"mood":"不太好","level":2},
            {"day":"2026-10-14","recorded":true,"mood":"挺好","level":4},{"day":"2026-10-15","recorded":true,"mood":"挺好",
            "level":4},{"day":"2026-10-16","recorded":true,"mood":"不太好","level":2},{"day":"2026-10-17","recorded":true,
            "mood":"挺好","level":4},{"day":"2026-10-18","recorded":true,"mood":"有起有落","level":3}],"entries":[{"id":509,
            "day":"2026-10-12","kind":"event","category":"sleep","data":{"label":"睡觉","start":"2026-10-12T00:20",
            "end":"2026-10-12T07:10","durationMin":410},"confidence":0.9,"status":"ok"},{"id":512,"day":"2026-10-12",
            "kind":"event","category":"run","data":{"label":"跑步","start":"2026-10-12T06:30","end":"2026-10-12T07:08",
            "durationMin":38,"metrics":[{"name":"距离","value":6.8,"unit":"公里"}],"places":["小区"]},"confidence":0.9,
            "status":"ok"},{"id":522,"day":"2026-10-13","kind":"event","category":"sleep","data":{"label":"睡觉",
            "start":"2026-10-13T00:10","end":"2026-10-13T07:10","durationMin":420},"confidence":0.9,"status":"ok"},
            {"id":524,"day":"2026-10-13","kind":"event","category":"c-84f6a689","data":{"label":"网购台灯","things":["台灯"],
            "start":"2026-10-13T23:10","metrics":[{"name":"花费","value":159,"unit":"元"}]},"confidence":0.9,
            "status":"ok"},{"id":526,"day":"2026-10-13","kind":"event","category":"work","data":{"label":"上班",
            "durationMin":600,"start":"2026-10-13T09:00","end":"2026-10-13T19:00"},"confidence":0.9,"status":"ok"},
            {"id":531,"day":"2026-10-13","kind":"event","category":"c-94fb6da3","data":{"label":"坐地铁",
            "start":"2026-10-13T08:00","places":["地铁"]},"confidence":0.9,"status":"ok"},{"id":533,"day":"2026-10-14",
            "kind":"event","category":"sleep","data":{"label":"睡觉","start":"2026-10-14T00:10","end":"2026-10-14T07:00",
            "durationMin":410},"confidence":0.9,"status":"ok"},{"id":536,"day":"2026-10-14","kind":"event",
            "category":"run","data":{"label":"跑步","start":"2026-10-14T06:30","end":"2026-10-14T07:08","durationMin":38,
            "metrics":[{"name":"距离","value":6.7,"unit":"公里"}],"places":["小区"]},"confidence":0.9,"status":"ok"},
            {"id":542,"day":"2026-10-14","kind":"event","category":"study","data":{"label":"看书",
            "start":"2026-10-14T22:00","durationMin":60,"metrics":[{"name":"页数","value":48,"unit":"页"}]},
            "confidence":0.9,"status":"ok"},{"id":544,"day":"2026-10-15","kind":"event","category":"sleep",
            "data":{"label":"睡觉","start":"2026-10-15T00:10","end":"2026-10-15T07:10","durationMin":420},
            "confidence":0.9,"status":"ok"},{"id":547,"day":"2026-10-15","kind":"event","category":"c-84f6a689",
            "data":{"label":"网购牛奶","things":["牛奶"],"start":"2026-10-15T22:20","metrics":[{"name":"花费","value":69,
            "unit":"元"}]},"confidence":0.9,"status":"ok"},{"id":549,"day":"2026-10-15","kind":"event","category":"work",
            "data":{"label":"上班","durationMin":540,"start":"2026-10-15T09:00","end":"2026-10-15T18:00"},
            "confidence":0.9,"status":"ok"},{"id":551,"day":"2026-10-15","kind":"event","category":"strength",
            "data":{"label":"力量训练","start":"2026-10-15T20:00","end":"2026-10-15T20:45","durationMin":45,
            "places":["健身房"],"metrics":[{"name":"卧推重量","value":70,"unit":"公斤"},{"name":"卧推组数","value":5,"unit":"组"}]},
            "confidence":0.9,"status":"ok"},{"id":559,"day":"2026-10-16","kind":"event","category":"sleep",
            "data":{"label":"睡觉","start":"2026-10-16T00:30","end":"2026-10-16T07:00","durationMin":390},
            "confidence":0.9,"status":"ok"},{"id":572,"day":"2026-10-17","kind":"event","category":"sleep",
            "data":{"label":"睡觉","start":"2026-10-17T00:10","end":"2026-10-17T08:30","durationMin":500},
            "confidence":0.9,"status":"ok"},{"id":574,"day":"2026-10-17","kind":"event","category":"run",
            "data":{"label":"跑步","start":"2026-10-17T09:40","end":"2026-10-17T10:41","durationMin":61,
            "metrics":[{"name":"距离","value":9.9,"unit":"公里"}],"places":["滨江步道"]},"confidence":0.9,"status":"ok"},
            {"id":578,"day":"2026-10-17","kind":"event","category":"c-8dc516e6","data":{"label":"陪儿子去公园",
            "people":["儿子"],"places":["公园"],"start":"2026-10-17T15:00","end":"2026-10-17T16:30","durationMin":90},
            "confidence":0.9,"status":"ok"},{"id":581,"day":"2026-10-18","kind":"event","category":"sleep",
            "data":{"label":"睡觉","start":"2026-10-18T00:20","end":"2026-10-18T08:40","durationMin":500},
            "confidence":0.9,"status":"ok"},{"id":587,"day":"2026-10-18","kind":"event","category":"work",
            "data":{"label":"开会","start":"2026-10-19T03:00","end":"2026-10-19T04:00","durationMin":60},"confidence":0.9,
            "status":"ok"},{"id":588,"day":"2026-10-18","kind":"event","category":"c-c916946f","data":{"label":"看电影",
            "people":["老婆","儿子"],"places":["电影院"],"start":"2026-10-18T17:00","end":"2026-10-18T18:50","durationMin":110,
            "metrics":[{"name":"花费","value":150,"unit":"元","item":"电影票"}]},"confidence":0.9,"status":"ok"}],
            "weeklyReports":[],"groups":[{"key":"exercise","emoji":"🏃","name":"运动",
            "text":"跑步 3 次、力量 · 3 小时 2 分钟 · 23.4 公里","compare":"比上周多 38 分钟"},{"key":"diet","emoji":"🍽","name":"饮食",
            "text":"16:8 轻断食 7 次、外卖 黄焖鸡 2 次、回请小李吃火锅 等 8 样 · 花了 ¥358","compare":null},{"key":"study","emoji":"📚",
            "name":"学习","text":"看书 5 次、背单词 5 次 · 6 小时 57 分钟 · 210 页","compare":"比上周多 45 分钟"},{"key":"work","emoji":"💼",
            "name":"工作","text":"上班 5 次、和小王对方案、写方案 等 5 样 · 52 小时 30 分钟 · 花了 ¥32","compare":"比上周多 6 小时 45 分钟"},
            {"key":"c-d141d79b","emoji":"🧘","name":"冥想","text":"2 次 · 20 分钟","compare":"比上周少 35 分钟"},
            {"key":"c-09897138","emoji":"🩺","name":"健康","text":"量血压 4 次、称体重","compare":"比上周多 1 次"},{"key":"c-84f6a689",
            "emoji":"🛒","name":"购物","text":"买按摩枪、网购台灯、网购牛奶 等 5 样 · 花了 ¥1,064","compare":"比上周多 1 次"},{"key":"c-8dc516e6",
            "emoji":"👨‍👩‍👧","name":"家人朋友","text":"接儿子放学 2 次、给妈妈转钱、和妈妈视频 等 5 样 · 花了 ¥1,800","compare":"比上周少 1 次"},
            {"key":"c-94fb6da3","emoji":"🚗","name":"出行","text":"坐地铁 3 次、打车回家 · 花了 ¥56","compare":"比上周多 3 次"},
            {"key":"c-b27062be","emoji":"📋","name":"办事","text":"房贷 · 花了 ¥6,800","compare":"比上周少 2 次"},
            {"key":"c-b7328bba","emoji":"🧹","name":"家务","text":"拖地洗衣服、整理衣柜 · 1 小时 40 分钟","compare":"比上周多 40 分钟"},
            {"key":"c-c916946f","emoji":"🎬","name":"娱乐","text":"追剧、看电影 · 3 小时 20 分钟 · 花了 ¥150","compare":null},
            {"key":"c-f4b9b270","emoji":"🐕","name":"宠物","text":"换猫砂、买猫粮、打疫苗 · 花了 ¥200","compare":"比上周少 1 次"}],
            "money":[{"text":"日常花了 ¥3,604","compare":"比上周多 ¥2,444"},{"text":"固定的 ¥6,800","compare":null},
            {"text":"最大的一笔：给妈妈转钱 ¥1,000","compare":null}],"goals":[{"id":1,"title":"今年跑 500 公里","tone":"bad",
            "pct":0.191,"headline":"已完成 95.5 公里 · 落后 37%","delta":"+23.4 公里","category":"run"},{"id":2,
            "title":"连续 30 天 16:8 轻断食","tone":"good","pct":0.23333333333333334,"headline":"连续 7 天 · 最长 13 天",
            "delta":"7 天","category":"diet"},{"id":3,"title":"每周运动 3 次","tone":"good","pct":1,
            "headline":"已完成 4 次 · 已达成","delta":"+4 次","category":"exercise"},{"id":5,"title":"平均睡眠 7.5 小时",
            "tone":"warn","pct":0.9682539682539683,"headline":"实际 7.3 小时 · 差 0.2 小时","delta":"平均 7.3 小时",
            "category":"sleep"},{"id":7,"title":"体重降到 69.5 公斤","tone":"warn","pct":0.9740714786264892,
            "headline":"实际 71.4 公斤 · 多 1.8 公斤","delta":"平均 70.8 公斤","category":"c-09897138"},{"id":8,
            "title":"每周外卖不超过 2 次","tone":"none","pct":1,"headline":"已超过上限 1 次","delta":"+3 次","category":"diet"},
            {"id":9,"title":"每周背单词 4 次","tone":"good","pct":1,"headline":"已完成 5 次 · 已达成","delta":"+5 次",
            "category":"study"},{"id":10,"title":"每月外卖不超过 300 元","tone":"warn","pct":0.5933333333333334,
            "headline":"已用 178 / 300 元","delta":"+102 元","category":"diet"}],"mood":{"total":8,"good":4,"bad":3,
            "moments":[{"entryId":543,"day":"2026-10-14","text":"晚上10点 三体终于看完了"},{"entryId":557,"day":"2026-10-15",
            "text":"午休听见楼下有人在拉二胡"},{"entryId":596,"day":"2026-10-18","text":"晚上楼下飘上来烤红薯的香味"}]},
            "themes":[{"theme":"专注比时间长更重要","quotes":[{"noteId":348,"day":"2026-10-15",
            "text":"关掉消息专心做一件事 两个小时顶一天 以后应该每天留出这么一段"}]}],"highlights":["运动时长 3 小时 2 分，比上周多 38 分钟","运动次数 4 次，比上周多 1 次"],
            "concerns":["平均睡眠 7 小时 16 分，比上周少 8 分钟"],"next":{"todos":["给客户回电话","交水费（本来是 10月17日 周六 要做的）"],
            "goals":["「今年跑 500 公里」还差 398.1 公里，还剩 74 天，平均每天 5.4 公里（落后 35%）","「连续 30 天 16:8 轻断食」已经连续 8 天，今天做到就是第 9 天",
            "「每周运动 3 次」这周还差 2 次，还剩 7 天","「平均睡眠 7.5 小时」这周平均 6.8 小时，剩下的天里平均每天要 7.6 小时"],
            "suggestions":["外卖控制在两次以内，中午多去老地方吃面"]},"categorySuggestions":[]},"messageId":84,"read":false,
            "prev":"2026-10-05","next":null}
            """#

        private static let audit = #"""
            {"findings":[{"id":4,"noteId":363,"day":"2026-10-18","text":"下午三点到四点开了个会","at":"2026-10-18T09:50:00.000Z",
            "quote":"下午三点","reason":"「下午三点」是 15:00，记成了凌晨 3 点","before":["💼 开会 3:00–4:00 · 工作"],
            "after":["💼 开会 15:00–16:00 · 工作"],"entryIds":[587]}]}
            """#
    }
#endif
