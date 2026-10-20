#if DEBUG
    import Foundation

    extension StubServer.State {
        /// 钱：从网页版演示数据里拿的 10 月（每一笔只留几笔）、留意的、钱和你的日子、10月18日的钱、空气炸锅、人情往来
        /// （日子是演示数据的日子，界面测试只看页面打得开、点得动）
        func moneyReply(_ method: String, _ path: String) -> Any? {
            guard path.hasPrefix("/api/money") else { return nil }
            if method == "POST" { return ["ok": true] }
            let rest = String(path.dropFirst("/api/money".count))
            switch rest {
            case "/overview": return MoneyStub.json(MoneyStub.overview)
            case "/watch": return MoneyStub.json(MoneyStub.watch)
            case "/findings": return MoneyStub.json(MoneyStub.findings)
            case "/renqing": return MoneyStub.json(MoneyStub.renqing)
            case let other where other.hasPrefix("/renqing/"): return MoneyStub.json(MoneyStub.person)
            case let other where other.hasPrefix("/day/"): return MoneyStub.json(MoneyStub.day)
            case let other where other.hasPrefix("/thing/"): return MoneyStub.json(MoneyStub.thing)
            default: return MoneyStub.json(MoneyStub.month)
            }
        }
    }

    /// 钱的演示数据（网页版 5199 演示服务器拿的，原样）
    enum MoneyStub {
        static func json(_ text: String) -> Any {
            (try? JSONSerialization.jsonObject(with: Data(text.utf8))) ?? [String: Any]()
        }

        static let month = #"""
            {"month":"2026-10","from":"2026-10-01","to":"2026-10-20","today":"2026-10-20",
            "current":true,"started":"2026-08-18","spent":5924,"count":51,"todaySpent":0,"days":
            [{"day":"2026-10-01","spent":27,"count":2},{"day":"2026-10-02","spent":86,"count":
            3},{"day":"2026-10-03","spent":942,"count":5},{"day":"2026-10-04","spent":90,"count":
            1},{"day":"2026-10-05","spent":28,"count":1},{"day":"2026-10-06","spent":224,"count":
            2},{"day":"2026-10-07","spent":100,"count":3},{"day":"2026-10-08","spent":28,"count":
            1},{"day":"2026-10-09","spent":60,"count":2},{"day":"2026-10-10","spent":373,"count":
            6},{"day":"2026-10-11","spent":347,"count":3},{"day":"2026-10-12","spent":633,
            "count":4},{"day":"2026-10-13","spent":187,"count":2},{"day":"2026-10-14","spent":
            38,"count":1},{"day":"2026-10-15","spent":95,"count":2},{"day":"2026-10-16","spent":
            1064,"count":3},{"day":"2026-10-17","spent":978,"count":5},{"day":"2026-10-18",
            "spent":609,"count":4},{"day":"2026-10-19","spent":15,"count":1}],"compare":{"prevSpent":
            18113,"diff":-12189,"text":"比上个月这时候少 ¥12,189：上个月这时候有装修尾款 ¥8,000、买沙发 ¥4,200。"},
            "compareFrom":null,"fixed":{"paid":7127,"paidCount":3,"upcoming":0,"next":[],"monthly":
            7152,"series":[{"name":"话费","dayOfMonth":5,"amount":128,"lastDay":"2026-10-05",
            "entryIds":[139,432]},{"name":"瑜伽月卡","dayOfMonth":8,"amount":199,"lastDay":"2026-10-08",
            "entryIds":[160,465]},{"name":"房贷","dayOfMonth":15,"amount":6800,"lastDay":"2026-10-15",
            "entryIds":[208,555]},{"name":"视频会员","dayOfMonth":20,"amount":25,"lastDay":"2026-09-20",
            "entryIds":[19,265]}]},"income":{"total":18500,"items":[{"day":"2026-10-10","name":
            "工资","amount":18500,"entryId":493}]},"domains":[{"key":"c-8dc516e6","name":"家人朋友",
            "color":"pink","amount":2600,"count":3},{"key":"c-84f6a689","name":"购物","color":
            "orange","amount":1562,"count":19},{"key":"diet","name":"饮食","color":"purple",
            "amount":861,"count":19},{"key":"c-f4b9b270","name":"宠物","color":"blue","amount":
            379,"count":4},{"key":"c-c916946f","name":"娱乐","color":"yellow","amount":240,"count":
            2},{"key":"c-b27062be","name":"办事","color":"gray","amount":186,"count":1},{"key":
            "work","name":"工作","color":"brown","amount":96,"count":3}],"domainNote":"家人朋友里，给妈妈转钱 ¥1,000，满月红包 ¥800。",
            "items":[{"entryId":600,"index":0,"day":"2026-10-19","time":"12:40","name":"食堂午饭",
            "amount":15,"kind":"daily","domain":{"key":"diet","name":"饮食","color":"orange"},
            "who":"自己","label":"食堂午饭","things":[],"places":["公司食堂"],"people":[]},{"entryId":
            594,"index":0,"day":"2026-10-18","time":"21:50","name":"给儿子买运动鞋","amount":259,
            "kind":"daily","domain":{"key":"c-84f6a689","name":"购物","color":"orange"},"who":
            "儿子","label":"给儿子买运动鞋","things":["运动鞋"],"places":[],"people":["儿子"]},{"entryId":
            591,"index":0,"day":"2026-10-18","time":"18:40","name":"打疫苗","amount":80,"kind":
            "daily","domain":{"key":"c-f4b9b270","name":"宠物","color":"orange"},"who":"宠物",
            "label":"打疫苗","things":[],"places":[],"people":[]},{"entryId":590,"index":0,"day":
            "2026-10-18","time":"18:40","name":"买猫粮","amount":120,"kind":"daily","domain":
            {"key":"c-f4b9b270","name":"宠物","color":"orange"},"who":"猫","label":"买猫粮","things":
            [],"places":[],"people":[]},{"entryId":588,"index":0,"day":"2026-10-18","time":
            "17:00","name":"电影票","amount":150,"kind":"daily","domain":{"key":"c-c916946f",
            "name":"娱乐","color":"purple"},"who":"一家人","label":"看电影","things":[],"places":[
            "电影院"],"people":["老婆","儿子"]},{"entryId":575,"index":0,"day":"2026-10-17","time":
            "19:40","name":"满月红包","amount":800,"kind":"daily","domain":{"key":"c-8dc516e6",
            "name":"家人朋友","color":"pink"},"who":"老同学","label":"满月红包","things":[],"places":
            [],"people":["老同学"],"renqing":{"dir":"out","occasion":"满月"}},{"entryId":555,"index":
            0,"day":"2026-10-15","time":"21:40","name":"房贷","amount":6800,"kind":"fixed","domain":
            {"key":"c-b27062be","name":"办事","color":"gray"},"who":"一家人","label":"房贷","things":
            [],"places":[],"people":[]},{"entryId":493,"index":0,"day":"2026-10-10","time":
            "21:50","name":"工资","amount":18500,"kind":"income","domain":{"key":"work","name":
            "工作","color":"brown"},"who":"","label":"工资到账","things":[],"places":[],"people":
            []},{"entryId":566,"index":0,"day":"2026-10-16","time":"19:10","name":"打车回家","amount":
            56,"kind":"reimburse","domain":{"key":"c-94fb6da3","name":"出行","color":"blue"},
            "who":"自己","flag":"reimburse","label":"打车回家","things":[],"places":[],"people":
            []}],"counts":{"daily":51,"fixed":3,"reimburse":1,"lend":1,"income":1,"back":2},
            "early":null,"prevMonth":"2026-09","nextMonth":null}
            """#

        static let overview = #"""
            {"watch":[{"kind":"reimburse","name":"等报销","amount":56,"sub":"1 笔打车回家，最早一笔是 10月16日",
            "entryId":null},{"kind":"lend","name":"借给老同学","amount":2000,"sub":"10月9日借的 · 过去 11 天了",
            "entryId":481},{"kind":"fixed","name":"视频会员","amount":25,"sub":"20日扣，就是今天","entryId":
            null},{"kind":"unused","name":"瑜伽月卡 每月","amount":199,"sub":"10月8日又扣了；9月1日以后没说到瑜伽",
            "entryId":465}],"who":{"from":"2026-08-18","total":53055,"family":{"amount":37059,
            "share":"大半"},"people":[{"name":"自己","amount":8036,"strong":true},{"name":"儿子",
            "amount":3139,"strong":true},{"name":"妈妈","amount":1000,"strong":false},{"name":
            "表弟","amount":1000,"strong":false},{"name":"小王","amount":800,"strong":false},{
            "name":"老同学","amount":800,"strong":false}],"sentence":"花在你自己身上的最多，是花在儿子身上的 2.6 倍。"},
            "whoCount":153,"worth":{"good":[{"entryId":367,"day":"2026-09-29","name":"降噪耳机",
            "amount":899,"who":"自己","verdict":{"tone":"good","quote":"通勤戴着太安静了"},"durable":
            true,"uses":[{"day":"2026-10-01","entryId":389,"label":"坐地铁"},{"day":"2026-10-08",
            "entryId":466,"label":"坐地铁"},{"day":"2026-10-12","entryId":513,"label":"坐地铁"},
            {"day":"2026-10-15","entryId":546,"label":"坐地铁"}],"perUse":225,"sub":"9月29日买的 · 用了 4 次，每次 ¥225"},
            {"entryId":83,"day":"2026-08-29","name":"海洋馆","amount":560,"who":"一家人","verdict":
            {"tone":"good","quote":"他一路都在笑"},"durable":false,"uses":[{"day":"2026-08-31","entryId":
            94,"label":"儿子说起海洋馆"},{"day":"2026-09-07","entryId":149,"label":"儿子画海洋馆"},{"day":
            "2026-09-18","entryId":234,"label":"儿子想再去海洋馆"}],"perUse":null,"sub":"8月29日 · 之后又说起 3 次"},
            {"entryId":22,"day":"2026-08-21","name":"空气炸锅","amount":399,"who":"自己","verdict":
            {"tone":"good","quote":"空气炸锅真香 以后少点外卖","said":"2026-08-24"},"durable":true,"uses":
            [{"day":"2026-08-23","entryId":39,"label":"烤鸡翅"},{"day":"2026-08-24","entryId":
            45,"label":"烤红薯"},{"day":"2026-08-28","entryId":75,"label":"热披萨"},{"day":"2026-09-01",
            "entryId":103,"label":"烤蛋挞"},{"day":"2026-09-04","entryId":123,"label":"烤鸡翅"},
            {"day":"2026-09-08","entryId":159,"label":"烤红薯"},{"day":"2026-09-11","entryId":
            179,"label":"热披萨"},{"day":"2026-09-17","entryId":222,"label":"烤蛋挞"},{"day":"2026-09-24",
            "entryId":301,"label":"烤鸡翅"},{"day":"2026-09-30","entryId":374,"label":"烤红薯"},
            {"day":"2026-10-07","entryId":450,"label":"热披萨"},{"day":"2026-10-14","entryId":
            537,"label":"烤蛋挞"}],"perUse":33,"sub":"8月21日买的 · 用了 12 次，每次 ¥33"}],"regret":[{
            "entryId":520,"day":"2026-10-12","name":"按摩枪","amount":399,"who":"自己","verdict":
            {"tone":"regret","quote":"有点后悔"},"durable":true,"uses":[],"perUse":null,"sub":
            "10月12日买的 · 之后还没说到用它"}]},"renqing":{"out":4066,"in":3100,"times":9}}
            """#

        static let watch = #"""
            {"today":"2026-10-20","pending":{"total":2056,"reimburse":{"total":56,"items":
            [{"entryId":566,"index":0,"day":"2026-10-16","time":null,"name":"打车回家","amount":
            56,"kind":"reimburse","domain":{"key":"c-94fb6da3","name":"出行","color":"blue"},
            "who":"自己","flag":"reimburse","label":"打车回家","things":[],"places":[],"people":
            []}]},"lends":[{"item":{"entryId":481,"index":0,"day":"2026-10-09","time":null,
            "name":"借给老同学","amount":2000,"kind":"lend","domain":{"key":"c-8dc516e6","name":
            "家人朋友","color":"pink"},"who":"老同学","flag":"lend","label":"借给老同学","things":[],"places":
            [],"people":["老同学"]},"days":11}]},"fixed":{"total":7152,"rows":[{"name":"话费","dayOfMonth":
            5,"amount":128,"paidOn":"2026-10-05","lastDay":"2026-10-05","dueIn":null,"lastEntryId":
            432,"lastIndex":0,"unused":null},{"name":"瑜伽月卡","dayOfMonth":8,"amount":199,"paidOn":
            "2026-10-08","lastDay":"2026-10-08","dueIn":null,"lastEntryId":465,"lastIndex":
            0,"unused":{"key":"瑜伽","lastMention":"2026-09-01"}},{"name":"房贷","dayOfMonth":
            15,"amount":6800,"paidOn":"2026-10-15","lastDay":"2026-10-15","dueIn":null,"lastEntryId":
            555,"lastIndex":0,"unused":null},{"name":"视频会员","dayOfMonth":20,"amount":25,"paidOn":
            null,"lastDay":"2026-09-20","dueIn":0,"lastEntryId":265,"lastIndex":0,"unused":
            null}]},"packs":[{"entryId":142,"name":"篮球课","who":"儿子","day":"2026-09-06","amount":
            2880,"pack":24,"used":["2026-09-20","2026-09-27","2026-10-11"]}],"frequent":[{
            "name":"牛奶","every":14,"last":"2026-10-10","next":"2026-10-24","recent":[{"day":
            "2026-09-19","amount":25},{"day":"2026-09-26","amount":25},{"day":"2026-10-10",
            "amount":25}],"price":null},{"name":"鸡蛋","every":18,"last":"2026-10-10","next":
            "2026-10-28","recent":[{"day":"2026-09-05","amount":18},{"day":"2026-09-19","amount":
            18},{"day":"2026-10-10","amount":18}],"price":null},{"name":"猫粮","every":14,"last":
            "2026-10-18","next":"2026-11-01","recent":[{"day":"2026-09-27","amount":120},{
            "day":"2026-10-11","amount":120},{"day":"2026-10-18","amount":120}],"price":"比8月贵了 ¥11"}],
            "top":[{"kind":"reimburse","name":"等报销","amount":56,"sub":"1 笔打车回家，最早一笔是 10月16日",
            "entryId":null},{"kind":"lend","name":"借给老同学","amount":2000,"sub":"10月9日借的 · 过去 11 天了",
            "entryId":481},{"kind":"fixed","name":"视频会员","amount":25,"sub":"20日扣，就是今天","entryId":
            null},{"kind":"unused","name":"瑜伽月卡 每月","amount":199,"sub":"10月8日又扣了；9月1日以后没说到瑜伽",
            "entryId":465}],"quotes":{"481":"老同学找我借了 2000 说下个月还"},"budgets":[{"id":10,"title":
            "每月外卖不超过 300 元","headline":"已用 178 / 300 元","pct":0.5933333333333334,"tone":"good"}]}
            """#

        static let findings = #"""
            {"recorded":63,"early":false,"week":"2026-10-19","findings":[{"key":"心情差→lateBuy",
            "sentence":"心情差的日子，大多在晚上 10 点以后买了点东西；别的日子很少这样。","bars":[{"label":"心情差的日子","value":
            "15 天里 13 天","share":0.8666666666666667,"strong":true},{"label":"别的日子","value":
            "48 天里 3 天","share":0.0625,"strong":false}],"sub":"前后两段都是这样 · 只是同时出现 · 点开看是哪几天",
            "days":[{"day":"2026-08-21","text":"23:20 网购香薰机 ¥129"},{"day":"2026-08-26","text":
            "23:15 网购保温杯 ¥69"},{"day":"2026-08-31","text":"23:40 网购颈椎按摩仪 ¥199"},{"day":"2026-09-04",
            "text":"22:45 网购靠垫 ¥79"},{"day":"2026-09-07","text":"22:50 网购漫画 ¥89"},{"day":"2026-09-11",
            "text":"23:30 网购书 ¥39"},{"day":"2026-09-16","text":"22:50 网购数据线 ¥25"},{"day":"2026-09-22",
            "text":"23:40 网购收纳盒 ¥45"},{"day":"2026-09-28","text":"00:40 网购跑鞋 ¥459"},{"day":
            "2026-09-29","text":"23:30 网购解压玩具 ¥39"},{"day":"2026-09-30","text":"23:05 网购面膜 ¥99"},
            {"day":"2026-10-07","text":"23:15 网购保温杯 ¥69"},{"day":"2026-10-13","text":"23:10 网购台灯 ¥159"}],
            "vote":null}]}
            """#

        static let day = #"""
            {"day":"2026-10-18","items":[{"entryId":588,"index":0,"day":"2026-10-18","time":
            "17:00","name":"电影票","amount":150,"kind":"daily","domain":{"key":"c-c916946f",
            "name":"娱乐","color":"purple"},"who":"一家人","label":"看电影","things":[],"places":[
            "电影院"],"people":["老婆","儿子"]},{"entryId":590,"index":0,"day":"2026-10-18","time":
            "18:40","name":"买猫粮","amount":120,"kind":"daily","domain":{"key":"c-f4b9b270",
            "name":"宠物","color":"orange"},"who":"猫","label":"买猫粮","things":[],"places":[],
            "people":[]},{"entryId":591,"index":0,"day":"2026-10-18","time":"18:40","name":
            "打疫苗","amount":80,"kind":"daily","domain":{"key":"c-f4b9b270","name":"宠物","color":
            "orange"},"who":"宠物","label":"打疫苗","things":[],"places":[],"people":[]},{"entryId":
            594,"index":0,"day":"2026-10-18","time":"21:50","name":"给儿子买运动鞋","amount":259,
            "kind":"daily","domain":{"key":"c-84f6a689","name":"购物","color":"orange"},"who":
            "儿子","label":"给儿子买运动鞋","things":["运动鞋"],"places":[],"people":["儿子"]}],"spent":
            609,"count":4,"people":["老婆","儿子"],"feelings":["烦躁","放松"],"notes":[{"time":"09:10",
            "text":"昨晚12点20分才睡 早上8点40分起 今天继续168 量了血压 130/83 称了一下 70.8公斤"},{"time":"15:20",
            "text":"下午三点到四点开了个会"},{"time":"16:20","text":"下午方案被改了三遍 烦得不行"}],"prev":"2026-10-17",
            "next":"2026-10-19"}
            """#

        static let thing = #"""
            {"entryId":22,"day":"2026-08-21","name":"空气炸锅","amount":399,"who":"自己","verdict":
            {"tone":"good","quote":"空气炸锅真香 以后少点外卖","said":"2026-08-24"},"durable":true,"uses":
            [{"day":"2026-08-23","entryId":39,"label":"烤鸡翅","text":"用空气炸锅烤了鸡翅"},{"day":"2026-08-24",
            "entryId":45,"label":"烤红薯","text":"空气炸锅烤了红薯"},{"day":"2026-08-28","entryId":75,
            "label":"热披萨","text":"用空气炸锅热了个披萨"},{"day":"2026-09-01","entryId":103,"label":"烤蛋挞",
            "text":"空气炸锅烤了几个蛋挞"},{"day":"2026-09-04","entryId":123,"label":"烤鸡翅","text":"用空气炸锅烤了鸡翅"},
            {"day":"2026-09-08","entryId":159,"label":"烤红薯","text":"空气炸锅烤了红薯"},{"day":"2026-09-11",
            "entryId":179,"label":"热披萨","text":"用空气炸锅热了个披萨"},{"day":"2026-09-17","entryId":
            222,"label":"烤蛋挞","text":"空气炸锅烤了几个蛋挞"},{"day":"2026-09-24","entryId":301,"label":
            "烤鸡翅","text":"用空气炸锅烤了鸡翅"},{"day":"2026-09-30","entryId":374,"label":"烤红薯","text":
            "空气炸锅烤了红薯"},{"day":"2026-10-07","entryId":450,"label":"热披萨","text":"用空气炸锅热了个披萨"},
            {"day":"2026-10-14","entryId":537,"label":"烤蛋挞","text":"空气炸锅烤了几个蛋挞"}],"perUse":
            33,"sub":"8月21日买的 · 用了 12 次，每次 ¥33","bought":{"day":"2026-08-21","text":"买了个空气炸锅 399"}}
            """#

        static let renqing = #"""
            {"started":"2026-08-18","out":{"amount":4066,"gifts":3,"treats":2},"in":{"amount":
            3100,"gifts":3,"treats":1},"people":[{"name":"老同学","relation":null,"out":{"amount":
            800,"gifts":1,"treats":1},"in":{"amount":600,"gifts":1,"treats":0},"last":{"day":
            "2026-10-17","text":"满月 · 你随的 ¥800"}},{"name":"小李","relation":null,"out":{"amount":
            186,"gifts":0,"treats":2},"in":{"amount":500,"gifts":1,"treats":1},"last":{"day":
            "2026-10-12","text":"你请的 ¥186"}},{"name":"小王","relation":"同事","out":{"amount":
            800,"gifts":1,"treats":0},"in":{"amount":0,"gifts":0,"treats":0},"last":{"day":
            "2026-10-03","text":"结婚 · 你随的 ¥800"}},{"name":"大姐","relation":null,"out":{"amount":
            0,"gifts":0,"treats":1},"in":{"amount":2000,"gifts":1,"treats":0},"last":{"day":
            "2026-09-19","text":"乔迁 · 大姐随的 ¥2,000"}},{"name":"表弟","relation":null,"out":{"amount":
            1000,"gifts":1,"treats":0},"in":{"amount":0,"gifts":0,"treats":0},"last":{"day":
            "2026-08-26","text":"升学 · 你随的 ¥1,000"}}],"unknown":null}
            """#

        static let person = #"""
            {"name":"小李","relation":null,"out":{"amount":186,"gifts":0,"treats":2},"in":{"amount":
            500,"gifts":1,"treats":1},"rows":[{"entryId":514,"day":"2026-10-12","dir":"out",
            "text":"你请的 ¥186","together":[],"quote":"晚上回请小李吃火锅 花了186"},{"entryId":349,"day":
            "2026-09-28","dir":"in","text":"小李请的","together":[],"quote":"下班小李请我吃了顿烤肉 说谢谢我帮他改方案"},
            {"entryId":248,"day":"2026-09-19","dir":"in","text":"乔迁 · 小李随的 ¥500","together":
            [],"quote":"大姐给了2000的红包 老同学给了600 小李给了500"},{"entryId":247,"day":"2026-09-19","dir":
            "out","text":"乔迁 · 你请的 ¥1,280","together":["大姐","老同学"],"quote":"今天请大姐一家和老同学、小李来新家暖房 在楼下饭店订了一桌 1280"}]}
            """#
    }
#endif
