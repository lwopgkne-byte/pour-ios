#if DEBUG
    import Foundation

    extension StubServer.State {
        /// 笔记库：从网页版演示数据里拿的最近几段原话、人物、感悟、好时刻（日子是演示数据的日子）
        func libraryReply(_ method: String, _ path: String) -> Any? {
            switch (method, path) {
            case ("GET", "/api/library"): return LibraryStub.json(LibraryStub.notes)
            case ("GET", "/api/library/people"): return LibraryStub.json(LibraryStub.people)
            case ("GET", "/api/insights"): return LibraryStub.json(LibraryStub.insights)
            case ("GET", "/api/moments"): return LibraryStub.json(LibraryStub.moments)
            case ("PATCH", let other) where other.hasPrefix("/api/notes/"): return ["ok": true]
            case ("DELETE", let other) where other.hasPrefix("/api/notes/"): return ["ok": true]
            case ("POST", let other) where other.hasPrefix("/api/notes/") && other.hasSuffix("/restore"):
                return ["ok": true]
            default: return nil
            }
        }
    }

    /// 笔记库的演示数据（网页版 5199 演示服务器拿的，原样）
    enum LibraryStub {
        static func json(_ text: String) -> Any {
            (try? JSONSerialization.jsonObject(with: Data(text.utf8))) ?? [String: Any]()
        }

        static let notes = #"""
            {"notes":[{"id":368,"text":"断网了也要记下来","createdAt":"2026-10-19T10:07:39.386Z","day":
            "2026-10-19","status":"pending","error":"还没有确认把原话发送给大模型整理。在页面上确认后会自动开始。","entries":
            []},{"id":367,"text":"食堂吃的 15","createdAt":"2026-10-19T07:10:00.000Z","day":"2026-10-19",
            "status":"done","result":{"receipt":[{"action":"created","kind":"event","entryId":
            600,"text":"🍽 食堂午饭 ¥15 · 在公司食堂","pending":false}],"reply":"","questions":[],"notices":
            []},"entries":[{"id":600,"kind":"event","category":"diet","text":"🍽 食堂午饭 ¥15 · 在公司食堂"}]},
            {"id":366,"text":"又过了12点才睡 12点20分 早上7点10分起的 今天继续168 早上跑了6.4公里 用了36分钟","createdAt":
            "2026-10-19T02:10:00.000Z","day":"2026-10-19","status":"done","result":{"receipt":
            [{"action":"created","kind":"event","entryId":597,"text":"😴 0:20 → 7:10","pending":
            false},{"action":"created","kind":"event","entryId":598,"text":"🍽 16:8 轻断食","pending":
            false},{"action":"created","kind":"event","entryId":599,"text":"🏃 跑步 36 分钟 6.4 公里 · 在小区",
            "pending":false}],"reply":"","questions":[],"notices":[],"advanced":["今年跑 500 公里 +6.4 公里",
            "连续 30 天 16:8 轻断食 连续第 8 天","每周运动 3 次 +1 次","平均睡眠 7.5 小时"]},"entries":[{"id":597,
            "kind":"event","category":"sleep","text":"😴 0:20 → 7:10"},{"id":598,"kind":"event",
            "category":"diet","text":"🍽 16:8 轻断食"},{"id":599,"kind":"event","category":"run",
            "text":"🏃 跑步 36 分钟 6.4 公里 · 在小区"}]},{"id":365,"text":"睡前看了42页人类简史 单词背了25分钟 给儿子买了双运动鞋 259 明天上午十点提醒我\#
            给客户回电话 晚上楼下飘上来烤红薯的香味 一下子放松了 小王是我同事",
            "createdAt":"2026-10-18T16:20:00.000Z","day":"2026-10-18","status":"done","result":
            {"receipt":[{"action":"created","kind":"event","entryId":592,"text":"📚 看书 59 分钟 42 页",
            "pending":false},{"action":"created","kind":"event","entryId":593,"text":"📚 背单词 25 分钟",
            "pending":false},{"action":"created","kind":"event","entryId":594,"text":"🛒 给儿子买运动鞋 ¥259",
            "pending":false},{"action":"created","kind":"todo","entryId":595,"text":"📝 待办：给客户回电话（⏰ 10月19日 10:0\#
            0 提醒）",
            "pending":false},{"action":"created","kind":"mood","entryId":596,"text":"💭 心情：挺好 · 放松（AI 推测）",
            "pending":false}],"reply":"","questions":[],"notices":[],"learned":["「小王」= 同事"],
            "advanced":["每周背单词 4 次 +1 次"]},"entries":[{"id":592,"kind":"event","category":
            "study","text":"📚 看书 59 分钟 42 页"},{"id":593,"kind":"event","category":"study",
            "text":"📚 背单词 25 分钟"},{"id":594,"kind":"event","category":"c-84f6a689","text":
            "🛒 给儿子买运动鞋 ¥259"},{"id":595,"kind":"todo","category":"todo","text":"📝 待办：给客户回电话（⏰ 10月19日 10:00 提醒）"},
            {"id":596,"kind":"mood","category":"mood","text":"💭 心情：挺好 · 放松（AI 推测）"}]},{"id":
            364,"text":"5点带儿子去看了场电影 三张票150 整理了一下衣柜 给猫买了一袋猫粮 一百二 带猫去打了疫苗 花了八十","createdAt":
            "2026-10-18T13:10:00.000Z","day":"2026-10-18","status":"done","result":{"receipt":
            [{"action":"created","kind":"event","entryId":588,"text":"🎬 看电影 110 分钟 电影票 ¥150 · 在电影院 · 和老婆、儿子",
            "pending":false},{"action":"created","kind":"event","entryId":589,"text":"🧹 整理衣柜 40 分钟",
            "pending":false},{"action":"created","kind":"event","entryId":590,"text":"🐕 买猫粮 ¥120",
            "pending":false},{"action":"created","kind":"event","entryId":591,"text":"🐕 打疫苗 ¥80",
            "pending":false}],"reply":"","questions":[],"notices":[]},"entries":[{"id":588,
            "kind":"event","category":"c-c916946f","text":"🎬 看电影 110 分钟 电影票 ¥150 · 在电影院 · 和老婆、儿子"},
            {"id":589,"kind":"event","category":"c-b7328bba","text":"🧹 整理衣柜 40 分钟"},{"id":
            590,"kind":"event","category":"c-f4b9b270","text":"🐕 买猫粮 ¥120"},{"id":591,"kind":
            "event","category":"c-f4b9b270","text":"🐕 打疫苗 ¥80"}]},{"id":363,"text":"下午三点到四点开了个会",
            "createdAt":"2026-10-18T09:50:00.000Z","day":"2026-10-18","status":"done","result":
            {"receipt":[{"action":"created","kind":"event","entryId":587,"text":"💼 开会 60 分钟",
            "pending":false}],"reply":"","questions":[],"notices":[]},"entries":[{"id":587,
            "kind":"event","category":"work","text":"💼 开会 60 分钟"}]},{"id":362,"text":"下午方案被改了三遍 烦得不行",
            "createdAt":"2026-10-18T10:50:00.000Z","day":"2026-10-18","status":"done","result":
            {"receipt":[{"action":"created","kind":"event","entryId":585,"text":"💼 改方案","pending":
            false},{"action":"created","kind":"mood","entryId":586,"text":"💭 心情：不太好 · 烦躁（AI 推测）",
            "pending":false}],"reply":"","questions":[],"notices":[]},"entries":[{"id":585,
            "kind":"event","category":"work","text":"💼 改方案"},{"id":586,"kind":"mood","category":
            "mood","text":"💭 心情：不太好 · 烦躁（AI 推测）"}]},{"id":361,"text":"昨晚12点20分才睡 早上8点40分起 今天继续168 量了血压 130/83 \#
            称了一下 70.8公斤",
            "createdAt":"2026-10-18T03:40:00.000Z","day":"2026-10-18","status":"done","result":
            {"receipt":[{"action":"created","kind":"event","entryId":581,"text":"😴 0:20 → 8:40",
            "pending":false},{"action":"created","kind":"event","entryId":582,"text":"🍽 16:8 轻断食",
            "pending":false},{"action":"created","kind":"event","entryId":583,"text":"🩺 量血压 收缩压 130 mmHg、舒张压 8\#
            3 mmHg",
            "pending":false},{"action":"created","kind":"event","entryId":584,"text":"🩺 称体重 70.8 公斤",
            "pending":false}],"reply":"","questions":[],"notices":[],"advanced":["连续 30 天 16:8 轻断食 连续第 7 天",
            "平均睡眠 7.5 小时","体重降到 69.5 公斤"]},"entries":[{"id":581,"kind":"event","category":
            "sleep","text":"😴 0:20 → 8:40"},{"id":582,"kind":"event","category":"diet","text":
            "🍽 16:8 轻断食"},{"id":583,"kind":"event","category":"c-09897138","text":"🩺 量血压 收缩压 130 mmHg、舒张压 83 mmHg"},
            {"id":584,"kind":"event","category":"c-09897138","text":"🩺 称体重 70.8 公斤"}]}],"hasMore":
            true}
            """#

        static let people = #"""
            {"items":[{"name":"儿子","kind":"person","count":43},{"name":"老婆","kind":"person",
            "count":23},{"name":"小王","kind":"person","count":11},{"name":"装修师傅","kind":"person",
            "count":9},{"name":"小李","kind":"person","count":8},{"name":"同事","kind":"person",
            "count":5},{"name":"《三体》","kind":"thing","count":22},{"name":"空气炸锅","kind":"thing",
            "count":13},{"name":"红衣服","kind":"thing","count":9},{"name":"茶百道","kind":"thing",
            "count":9},{"name":"降噪耳机","kind":"thing","count":5},{"name":"篮球课","kind":"thing",
            "count":4},{"name":"学校","kind":"place","count":18},{"name":"小区","kind":"place",
            "count":11},{"name":"星巴克","kind":"place","count":9},{"name":"超市","kind":"place",
            "count":9},{"name":"公司食堂","kind":"place","count":7},{"name":"新家","kind":"place",
            "count":7},{"name":"囤货","kind":"tag","count":5},{"name":"健康管理","kind":"tag","count":
            1}]}
            """#

        static let insights = #"""
            {"insights":[{"id":558,"day":"2026-10-15","title":"专注比时间长更重要","quote":"关掉消息专心做一件事 两个小时顶一天 以后应该每天留出这么一段",
            "tags":["专注","效率"],"noteId":348},{"id":507,"day":"2026-10-11","title":"陪孩子不在于时间长",
            "quote":"陪儿子二十分钟 手机放远一点 比陪一下午心不在焉强","tags":["育儿","专注"],"noteId":324},{"id":462,
            "day":"2026-10-07","title":"读书让我安静","quote":"睡前读半小时书 比刷手机睡得踏实","tags":["阅读","睡眠"],
            "noteId":303},{"id":434,"day":"2026-10-05","title":"累的时候先休息","quote":"上线熬到三点多 今天什么都不想干 与其硬撑不如早点睡",
            "tags":["精力","休息"],"noteId":287},{"id":386,"day":"2026-09-30","title":"手机吃掉了晚上",
            "quote":"晚上又刷了两个小时手机 什么都没干成 下次应该放客厅充电","tags":["手机","时间"],"noteId":262},{"id":
            321,"day":"2026-09-25","title":"早睡的第二天效率高","quote":"昨晚十一点就睡了 今天上午做事特别顺","tags":
            ["睡眠","效率"],"noteId":230},{"id":254,"day":"2026-09-19","title":"小目标更容易坚持","quote":
            "每次只跑五公里反而坚持下来了 以前总觉得必须一上来就十公里 跑两次就放弃","tags":["运动","习惯"],"noteId":192},{"id":
            242,"day":"2026-09-18","title":"家安顿好了心才定","quote":"装修这两个月一直悬着 今天看着收拾好的家 心才算落了地",
            "tags":["家","安定"],"noteId":186}],"tags":[{"tag":"专注","count":2},{"tag":"效率","count":
            2},{"tag":"睡眠","count":2},{"tag":"育儿","count":1},{"tag":"阅读","count":1},{"tag":
            "精力","count":1},{"tag":"休息","count":1},{"tag":"手机","count":1},{"tag":"时间","count":
            1},{"tag":"运动","count":1},{"tag":"习惯","count":1},{"tag":"家","count":1},{"tag":
            "安定","count":1}]}
            """#

        static let moments = #"""
            {"moments":[{"id":596,"day":"2026-10-18","kind":"mood","category":"mood","data":
            {"mood":4,"emotions":["放松"],"tone":"good","strength":"medium","moment":"晚上楼下飘上来烤红薯的香味"},
            "confidence":0.75,"status":"ok","sources":[{"noteId":365,"span":"晚上楼下飘上来烤红薯的香味 一下子放松了",
            "action":"created","text":"睡前看了42页人类简史 单词背了25分钟 给儿子买了双运动鞋 259 明天上午十","createdAt":
            "2026-10-18T16:20:00.000Z"}],"noteId":365},{"id":557,"day":"2026-10-15","kind":
            "mood","category":"mood","data":{"mood":4,"emotions":["放松"],"tone":"good","strength":
            "medium","moment":"午休听见楼下有人在拉二胡"},"confidence":0.75,"status":"ok","sources":[{
            "noteId":348,"span":"午休听见楼下有人在拉二胡 挺放松的","action":"created","text":"和老婆追了两集剧 睡前看了33页人类简史 背了40个新单词 半\#
            小时 房贷扣了 6",
            "createdAt":"2026-10-15T16:10:00.000Z"}],"noteId":348},{"id":543,"day":"2026-10-14",
            "kind":"mood","category":"mood","data":{"mood":4,"emotions":["满足"],"tone":"good",
            "strength":"medium","moment":"晚上10点 三体终于看完了"},"confidence":0.75,"status":"ok",
            "sources":[{"noteId":342,"span":"很满足","action":"created","text":"单词背了25分钟 给猫换了猫砂 晚上10点 三体终于看完了 很满足\#
             下一本看人类",
            "createdAt":"2026-10-14T16:10:00.000Z"}],"noteId":342},{"id":506,"day":"2026-10-11",
            "kind":"mood","category":"mood","data":{"mood":4,"emotions":["开心"],"tone":"good",
            "strength":"medium","moment":"等红灯的时候看见一只小狗冲我摇尾巴"},"confidence":0.75,"status":"ok",
            "sources":[{"noteId":324,"span":"等红灯的时候看见一只小狗冲我摇尾巴 忍不住笑了","action":"created","text":
            "看了会儿三体 42页 背了40个新单词 半小时 跟着APP冥想了20分钟 等红灯","createdAt":"2026-10-11T16:20:00.000Z"}],
            "noteId":324}]}
            """#
    }
#endif
