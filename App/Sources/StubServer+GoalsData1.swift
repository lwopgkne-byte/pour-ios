// swift-format-ignore-file
#if DEBUG
    /// 3.0 目标的假服务器数据（第 1 份）：10月27日（原型那天）的演示数据，服务器 2.15.0 原样拿的（docs/3.0/01-需求文档.md 9.13）
    extension Goals3Stub {
        static let part1: [String: String] = [
            "/api/goals/home": #"""
                {"summary":{"lead":"这周 7 个目标里 4 个在正轨上","lagId":4,"lagTitle":"今年跑 500 公里"},"weekly":{"from":"2026-10-\#
                19","to":"2026-10-25","text":"上周的回顾还没看 · 3 分钟"},"care":[{"key":"health","name":"健康","icon":"heart","\#
                count":4,"pct":0.583,"state":"behind"},{"key":"money","name":"钱","icon":"yen","count":1,"pct":0.787,\#
                "state":"track"},{"key":"growth","name":"成长","icon":"book","count":2,"pct":0.375,"state":"track"},{"\#
                key":"family","name":"关系","icon":"people","count":0,"pct":0,"state":"paused"}],"groups":[{"key":"hea\#
                lth","name":"健康","icon":"heart","cards":[{"id":4,"parentId":null,"title":"今年跑 500 公里","care":"health\#
                ","kind":"quantity","calc":"sum","state":"behind","line":"比应达少 78 公里","second":"落后两周了，聊聊怎么调？","ring"\#
                :"18%","pct":0.185,"lagging":true,"asking":false,"paused":false,"streak":null,"closed":null,"why":nu\#
                ll},{"id":3,"parentId":null,"title":"平均睡 7.5 小时","care":"health","kind":"quantity","calc":"avg","sta\#
                te":"behind","line":"这周平均每晚差 40 分钟","second":null,"ring":"91%","pct":0.911,"lagging":false,"asking":\#
                false,"paused":false,"streak":null,"closed":null,"why":null},{"id":8,"parentId":null,"title":"三个月瘦 5\#
                 斤","care":"health","kind":"parent","calc":null,"state":"behind","line":"2 个里 1 个在正轨上","second":null\#
                ,"ring":"1/2","pct":0.37,"lagging":false,"asking":false,"paused":false,"streak":null,"closed":null,"\#
                why":null}]},{"key":"money","name":"钱","icon":"yen","cards":[{"id":11,"parentId":null,"title":"每月外卖不\#
                超过 300 元","care":"money","kind":"quantity","calc":"sum","state":"track","line":"这个月还能花 ¥64","second"\#
                :null,"ring":"79%","pct":0.787,"lagging":false,"asking":false,"paused":false,"streak":null,"closed":\#
                null,"why":null}]},{"key":"growth","name":"成长","icon":"book","cards":[{"id":12,"parentId":null,"titl\#
                e":"读完《人类简史》","care":"growth","kind":"completion","calc":null,"state":"track","line":"看完两部分，到第 220 页\#
                ","second":"在等你回答一句 ›","ring":"2/4","pct":0.5,"lagging":false,"asking":true,"paused":false,"streak":\#
                null,"closed":null,"why":null}]}],"streaks":[{"id":1,"parentId":null,"title":"每周背单词 4 次","care":"gro\#
                wth","kind":"quantity","calc":"count","state":"track","line":"这周 1 次，还差 3 次","second":null,"ring":"2\#
                5%","pct":0.25,"lagging":false,"asking":false,"paused":false,"streak":{"weekly":true,"marks":["done"\#
                ,"done","miss","done","miss","done","miss","done","done","done","done","miss","done","today"],"habit\#
                ":true},"closed":null,"why":null},{"id":2,"parentId":null,"title":"每天走 8000 步","care":"health","kind\#
                ":"quantity","calc":"daily","state":"track","line":"30 天做到 26 天","second":"这周用了 1 次补假","ring":"26 天"\#
                ,"pct":0.867,"lagging":false,"asking":false,"paused":false,"streak":{"weekly":false,"marks":["rest",\#
                "rest","miss","done","done","done","done","done","done","done","done","done","rest","today"],"habit"\#
                :false},"closed":null,"why":null}],"budgets":[{"id":10,"parentId":8,"title":"每周外卖不超过 2 次","care":nul\#
                l,"kind":"quantity","calc":"count","state":"track","line":"这周还能 1 次","second":null,"ring":"50%","pct\#
                ":0.5,"lagging":false,"asking":false,"paused":false,"streak":null,"closed":null,"why":null,"parent":\#
                "三个月瘦 5 斤"},{"id":11,"parentId":null,"title":"每月外卖不超过 300 元","care":"money","kind":"quantity","calc"\#
                :"sum","state":"track","line":"这个月还能花 ¥64","second":null,"ring":"79%","pct":0.787,"lagging":false,"a\#
                sking":false,"paused":false,"streak":null,"closed":null,"why":null,"parent":null}],"done":[{"id":6,"\#
                parentId":null,"title":"连续 7 天 12 点前睡","care":"health","kind":"quantity","calc":"streak","state":"do\#
                ne","line":"做到了","second":null,"ring":"100%","pct":1,"lagging":false,"asking":false,"paused":false,"\#
                streak":null,"closed":"10月6日做到","why":null},{"id":5,"parentId":null,"title":"跑完第一个 10 公里","care":nul\#
                l,"kind":"completion","calc":null,"state":"done","line":"做到了","second":null,"ring":null,"pct":0,"lag\#
                ging":false,"asking":false,"paused":false,"streak":null,"closed":"9月23日做到","why":null}],"letgo":[{"i\#
                d":7,"parentId":null,"title":"每天冥想 10 分钟","care":"health","kind":"quantity","calc":"daily","state":"\#
                letgo","line":"放下了","second":null,"ring":null,"pct":0,"lagging":false,"asking":false,"paused":false,\#
                "streak":{"weekly":false,"marks":["rest","done","miss","done","miss","rest","rest","done","miss","mi\#
                ss","done","done","rest","today"],"habit":false},"closed":"10月12日放下","why":"工作太忙，先放一放"}],"lagging":1\#
                ,"empty":null}
                """#,
            "/api/goals/weekly": #"""
                {"from":"2026-10-19","to":"2026-10-25","title":"每周回顾 10月19日–25日","rows":[{"id":4,"title":"今年跑 500 公里\#
                ","done":false,"sub":"1 次，周六早上","value":"+8.4 公里"},{"id":3,"title":"平均睡 7.5 小时","done":false,"sub":"\#
                差 7 分钟","value":"平均 7 小时 23 分"},{"id":9,"title":"体重降到 69.5 公斤","done":false,"sub":"比上周轻 0.1","value"\#
                :"平均 71.6 公斤"},{"id":10,"title":"每周外卖不超过 2 次","done":true,"sub":"没超","value":"2 次"},{"id":11,"title"\#
                :"每月外卖不超过 300 元","done":true,"sub":"到 ¥198，还能花 ¥102","value":"+¥70"},{"id":12,"title":"读完《人类简史》","do\#
                ne":true,"sub":"10月25日","value":"看完第二部分"},{"id":1,"title":"每周背单词 4 次","done":true,"sub":"","value":"\#
                5 次"},{"id":2,"title":"每天走 8000 步","done":true,"sub":"","value":"7 天都做到"}],"observation":{"text":"这周\#
                跑步只有周六早上那一次；10 月的 3 次都在周末早上。","foot":"程序找的规律，AI 只写成一句话；同一件事只说一遍"},"adjust":[{"id":4,"title":"今年跑 500\#
                 公里","why":"落后两周了：10 月只在周末跑了 3 次","option":{"key":"weekend","title":"改成周末长跑","how":"每个周六、周日各跑 8 公里；目\#
                标改成 230 公里","when":"照周末各 8 公里，12月27日能到 230","cost":"工作日不再要求跑","target":230,"newTitle":"今年跑 230 公里","\#
                ifthen":"如果周六早上没安排，就先出门跑 8 公里","remind":{"kind":"time","text":"周六 08:00","at":"08:00","days":[5]},"l\#
                ine":"周末长跑 · 12月27日能到"}}],"next":[{"id":4,"goal":"今年跑 500 公里","text":"周六早上 8 点在小区跑 8 公里","todo":{"co\#
                ntent":"在小区跑 8 公里","remindAt":"2026-10-31T08:00"}},{"id":12,"goal":"读完《人类简史》","text":"周日晚上 9 点看第三部分 \#
                40 页","todo":{"content":"看《人类简史》第三部分 40 页","remindAt":"2026-11-01T21:00"}},{"id":3,"goal":"平均睡 7.5 小\#
                时","text":"周三晚上 11 点半躺下睡觉","todo":{"content":"躺下睡觉","remindAt":"2026-10-28T23:30"}}],"nextFoot":"新的一\#
                周是重新开始的好时候：落后的目标可以从下周一重新算","seen":false}
                """#,
            "/api/care": #"""
                {"areas":[{"key":"health","name":"健康","icon":"heart","categories":["sleep","exercise","c-874bb6a3","\#
                c-77bc57be"],"scores":{"2026-Q4":9,"2026-Q3":8},"wish":{"text":"我想成为一个陪儿子踢一下午球也不喘的爸爸","agreed":false\#
                ,"sources":[{"noteId":362,"day":"2026-10-18","text":"早上跑了 6.9 公里 有点喘"},{"noteId":410,"day":"2026-10-\#
                24","text":"下午3点陪儿子去公园玩了一个半小时"}]}},{"key":"money","name":"钱","icon":"yen","categories":[],"scores":{\#
                "2026-Q4":6,"2026-Q3":6},"wish":{"text":"我想心里有数，不为钱发愁","agreed":false,"sources":[{"noteId":360,"day"\#
                :"2026-10-17","text":"老同学找我借了 2000 说下个月还"}]}},{"key":"growth","name":"成长","icon":"book","categories"\#
                :["study"],"scores":{"2026-Q4":8,"2026-Q3":7},"wish":{"text":"我想成为一年能读完 12 本书的人","agreed":false,"sou\#
                rces":[{"noteId":322,"day":"2026-10-12","text":"今年想多看点书 先把人类简史看完"}]}},{"key":"family","name":"关系","i\#
                con":"people","categories":["c-afd30e60"],"scores":{"2026-Q4":9,"2026-Q3":9},"wish":{"text":"我想成为儿子什\#
                么都愿意跟我说的爸爸","agreed":false,"sources":[{"noteId":410,"day":"2026-10-24","text":"下午3点陪儿子去公园玩了一个半小时"},{\#
                "noteId":415,"day":"2026-10-25","text":"下午3点带儿子去游泳 游了一个小时"}]}}],"agreed":true,"max":6}
                """#,
            "/api/care/health": #"""
                {"area":{"key":"health","name":"健康","icon":"heart","categories":["sleep","exercise","c-874bb6a3","c-\#
                77bc57be"]},"wish":{"text":"我想成为一个陪儿子踢一下午球也不喘的爸爸","agreed":false,"sources":[{"noteId":362,"day":"202\#
                6-10-18","text":"早上跑了 6.9 公里 有点喘"},{"noteId":410,"day":"2026-10-24","text":"下午3点陪儿子去公园玩了一个半小时"}]},"g\#
                oals":[{"id":2,"parentId":null,"title":"每天走 8000 步","care":"health","kind":"quantity","calc":"daily"\#
                ,"state":"track","line":"30 天做到 26 天","second":"这周用了 1 次补假","ring":"26 天","pct":0.867,"lagging":fals\#
                e,"asking":false,"paused":false,"streak":{"weekly":false,"marks":["rest","rest","miss","done","done"\#
                ,"done","done","done","done","done","done","done","rest","today"],"habit":false},"closed":null,"why"\#
                :null},{"id":3,"parentId":null,"title":"平均睡 7.5 小时","care":"health","kind":"quantity","calc":"avg","\#
                state":"behind","line":"这周平均每晚差 40 分钟","second":null,"ring":"91%","pct":0.911,"lagging":false,"askin\#
                g":false,"paused":false,"streak":null,"closed":null,"why":null},{"id":4,"parentId":null,"title":"今年跑\#
                 500 公里","care":"health","kind":"quantity","calc":"sum","state":"behind","line":"比应达少 78 公里","second\#
                ":"落后两周了，聊聊怎么调？","ring":"18%","pct":0.185,"lagging":true,"asking":false,"paused":false,"streak":null\#
                ,"closed":null,"why":null},{"id":8,"parentId":null,"title":"三个月瘦 5 斤","care":"health","kind":"parent\#
                ","calc":null,"state":"behind","line":"2 个里 1 个在正轨上","second":null,"ring":"1/2","pct":0.37,"lagging"\#
                :false,"asking":false,"paused":false,"streak":null,"closed":null,"why":null}],"empty":null,"invest":\#
                {"line":"关系你打了 9 分，最近 30 天花在上面的时间却最少：10 小时 10 分。","rows":[{"key":"health","name":"健康","score":9,"val\#
                ue":"16 小时 16 分","minutes":976,"mine":true},{"key":"money","name":"钱","score":6,"value":"92 笔","minu\#
                tes":0,"mine":false},{"key":"growth","name":"成长","score":8,"value":"22 小时 25 分","minutes":1345,"mine\#
                ":false},{"key":"family","name":"关系","score":9,"value":"10 小时 10 分","minutes":610,"mine":false}],"fo\#
                ot":"花的时间按「我在乎的」对照表合：睡觉不算，钱不算时间、写这 30 天记了几笔 · 只是放在一起看，不评判"},"score":{"quarter":"2026-Q4","value":9,"\#
                prev":8,"foot":"1 是一点不在乎，10 是最在乎 · 每季度打一次，下次 1月1日"},"money":false}
                """#,
            "/api/care/money": #"""
                {"area":{"key":"money","name":"钱","icon":"yen","categories":[]},"wish":{"text":"我想心里有数，不为钱发愁","agree\#
                d":false,"sources":[{"noteId":360,"day":"2026-10-17","text":"老同学找我借了 2000 说下个月还"}]},"goals":[{"id":1\#
                1,"parentId":null,"title":"每月外卖不超过 300 元","care":"money","kind":"quantity","calc":"sum","state":"tra\#
                ck","line":"这个月还能花 ¥64","second":null,"ring":"79%","pct":0.787,"lagging":false,"asking":false,"pause\#
                d":false,"streak":null,"closed":null,"why":null}],"empty":null,"invest":{"line":"关系你打了 9 分，最近 30 天花在\#
                上面的时间却最少：10 小时 10 分。","rows":[{"key":"health","name":"健康","score":9,"value":"16 小时 16 分","minutes":9\#
                76,"mine":false},{"key":"money","name":"钱","score":6,"value":"92 笔","minutes":0,"mine":true},{"key":\#
                "growth","name":"成长","score":8,"value":"22 小时 25 分","minutes":1345,"mine":false},{"key":"family","na\#
                me":"关系","score":9,"value":"10 小时 10 分","minutes":610,"mine":false}],"foot":"花的时间按「我在乎的」对照表合：睡觉不算，钱不\#
                算时间、写这 30 天记了几笔 · 只是放在一起看，不评判"},"score":{"quarter":"2026-Q4","value":6,"prev":6,"foot":"1 是一点不在乎，10 \#
                是最在乎 · 每季度打一次，下次 1月1日"},"money":true}
                """#,
            "/api/care/growth": #"""
                {"area":{"key":"growth","name":"成长","icon":"book","categories":["study"]},"wish":{"text":"我想成为一年能读完 \#
                12 本书的人","agreed":false,"sources":[{"noteId":322,"day":"2026-10-12","text":"今年想多看点书 先把人类简史看完"}]},"go\#
                als":[{"id":1,"parentId":null,"title":"每周背单词 4 次","care":"growth","kind":"quantity","calc":"count","\#
                state":"track","line":"这周 1 次，还差 3 次","second":null,"ring":"25%","pct":0.25,"lagging":false,"asking"\#
                :false,"paused":false,"streak":{"weekly":true,"marks":["done","done","miss","done","miss","done","mi\#
                ss","done","done","done","done","miss","done","today"],"habit":true},"closed":null,"why":null},{"id"\#
                :12,"parentId":null,"title":"读完《人类简史》","care":"growth","kind":"completion","calc":null,"state":"trac\#
                k","line":"看完两部分，到第 220 页","second":"在等你回答一句 ›","ring":"2/4","pct":0.5,"lagging":false,"asking":true\#
                ,"paused":false,"streak":null,"closed":null,"why":null}],"empty":null,"invest":{"line":"关系你打了 9 分，最近\#
                 30 天花在上面的时间却最少：10 小时 10 分。","rows":[{"key":"health","name":"健康","score":9,"value":"16 小时 16 分","min\#
                utes":976,"mine":false},{"key":"money","name":"钱","score":6,"value":"92 笔","minutes":0,"mine":false}\#
                ,{"key":"growth","name":"成长","score":8,"value":"22 小时 25 分","minutes":1345,"mine":true},{"key":"fami\#
                ly","name":"关系","score":9,"value":"10 小时 10 分","minutes":610,"mine":false}],"foot":"花的时间按「我在乎的」对照表合：\#
                睡觉不算，钱不算时间、写这 30 天记了几笔 · 只是放在一起看，不评判"},"score":{"quarter":"2026-Q4","value":8,"prev":7,"foot":"1 是一点\#
                不在乎，10 是最在乎 · 每季度打一次，下次 1月1日"},"money":false}
                """#,
            "/api/care/family": #"""
                {"area":{"key":"family","name":"关系","icon":"people","categories":["c-afd30e60"]},"wish":{"text":"我想成\#
                为儿子什么都愿意跟我说的爸爸","agreed":false,"sources":[{"noteId":410,"day":"2026-10-24","text":"下午3点陪儿子去公园玩了一个半小时\#
                "},{"noteId":415,"day":"2026-10-25","text":"下午3点带儿子去游泳 游了一个小时"}]},"goals":[],"empty":{"from":"你说过 3 \#
                次想多陪儿子","title":"每周陪儿子出去玩 2 次"},"invest":{"line":"关系你打了 9 分，最近 30 天花在上面的时间却最少：10 小时 10 分。","rows":[{\#
                "key":"health","name":"健康","score":9,"value":"16 小时 16 分","minutes":976,"mine":false},{"key":"money"\#
                ,"name":"钱","score":6,"value":"92 笔","minutes":0,"mine":false},{"key":"growth","name":"成长","score":8\#
                ,"value":"22 小时 25 分","minutes":1345,"mine":false},{"key":"family","name":"关系","score":9,"value":"10\#
                 小时 10 分","minutes":610,"mine":true}],"foot":"花的时间按「我在乎的」对照表合：睡觉不算，钱不算时间、写这 30 天记了几笔 · 只是放在一起看，不评判"}\#
                ,"score":{"quarter":"2026-Q4","value":9,"prev":9,"foot":"1 是一点不在乎，10 是最在乎 · 每季度打一次，下次 1月1日"},"money"\#
                :false}
                """#,
            "/api/goals/1": #"""
                {"title":"每周背单词 4 次","kind":"quantity","period":"week","repeat":true,"start":"2026-08-31","end":null\#
                ,"calc":"count","direction":"gte","target":4,"unit":"次","binding":{"category":"study","metric":"coun\#
                t","keywords":["背单词","单词"]},"id":1,"parentId":null,"status":"active","createdAt":"2026-08-31T14:30:0\#
                0.000Z","range":{"from":"2026-10-26","to":"2026-11-01"},"rangeLabel":"10月26日–11月1日","progress":{"tar\#
                get":4,"unit":"次","ended":false,"daysLeft":6,"tone":"good","pct":0.25,"actual":1,"expected":0,"diff"\#
                :1,"diffRatio":0,"reached":false,"prediction":{"kind":"not_enough"},"headline":"已完成 1 次 · 还差 3 次"},"\#
                prediction":"数据还不够，预测不了","page":{"card":{"id":1,"parentId":null,"title":"每周背单词 4 次","care":"growth",\#
                "kind":"quantity","calc":"count","state":"track","line":"这周 1 次，还差 3 次","second":null,"ring":"25%","\#
                pct":0.25,"lagging":false,"asking":false,"paused":false,"streak":{"weekly":true,"marks":["done","don\#
                e","miss","done","miss","done","miss","done","done","done","done","miss","done","today"],"habit":tru\#
                e},"closed":null,"why":null},"sub":"成长 · 每周 · 10月26日–11月1日","head":{"big":"1","bigUnit":" / 4 次 · 这周\#
                ","line":"成习惯了 · 连续 8 周都做到","more":"这周 1 次，还差 3 次 · 还有 6 天","nums":[]},"ask":null,"three":null,"remi\#
                nd":null,"chart":{"kind":"weeks","rows":[{"label":"8月31日","value":4,"note":null,"current":false},{"l\#
                abel":"9月7日","value":4,"note":null,"current":false},{"label":"9月14日","value":5,"note":null,"current"\#
                :false},{"label":"9月21日","value":4,"note":null,"current":false},{"label":"9月28日","value":6,"note":nu\#
                ll,"current":false},{"label":"10月5日","value":4,"note":null,"current":false},{"label":"10月12日","value\#
                ":5,"note":null,"current":false},{"label":"10月19日","value":5,"note":null,"current":false},{"label":"\#
                10月26日","value":1,"note":"这周到今天","current":true}],"line":4,"lineLabel":"目标","format":"count","unit":\#
                "次","money":false},"chartTitle":"每周几次","chartMeta":"按住拖动看每一周","best":{"grid":[[9,0,0],[7,0,0],[4,0,0\#
                ],[8,0,0],[2,0,0],[8,0,0],[0,0,0]],"text":"工作日早上 30 次；周末早上 8 次。","best":{"days":[0,1,2,3,4],"part":0\#
                ,"at":"08:00","text":"每个工作日 08:00"},"suggest":{"remind":{"kind":"time","text":"每个工作日 08:00","at":"08\#
                :00","days":[0,1,2,3,4]},"label":"把提醒放在每个工作日 08:00"},"already":null},"recent":[{"entryId":624,"day":\#
                "2026-10-26","text":"地铁上背了 25 分钟单词","when":"10月26日 07:50","plus":"+1 次"},{"entryId":594,"day":"2026-\#
                10-24","text":"背单词 20 分钟","when":"10月24日 08:05","plus":"+1 次"},{"entryId":580,"day":"2026-10-23","te\#
                xt":"地铁上背单词","when":"10月23日 07:55","plus":"+1 次"},{"entryId":568,"day":"2026-10-22","text":"背单词 25 分\#
                钟","when":"10月22日 07:55","plus":"+1 次"},{"entryId":555,"day":"2026-10-21","text":"地铁上背了20分钟单词","when\#
                ":"10月21日 07:50","plus":"+1 次"},{"entryId":531,"day":"2026-10-19","text":"用APP背了20分钟单词","when":"10月1\#
                9日 07:52","plus":"+1 次"},{"entryId":506,"day":"2026-10-17","text":"地铁上背了20分钟单词","when":"10月17日 07:50\#
                ","plus":"+1 次"},{"entryId":480,"day":"2026-10-15","text":"用APP背了20分钟单词","when":"10月15日 07:52","plus\#
                ":"+1 次"},{"entryId":470,"day":"2026-10-14","text":"背单词 25 分钟","when":"10月14日 07:55","plus":"+1 次"},\#
                {"entryId":455,"day":"2026-10-13","text":"地铁上背了20分钟单词","when":"10月13日 07:50","plus":"+1 次"},{"entryI\#
                d":443,"day":"2026-10-12","text":"地铁上背了半小时单词","when":"10月12日 07:48","plus":"+1 次"},{"entryId":423,"d\#
                ay":"2026-10-10","text":"背单词 25 分钟","when":"10月10日 07:55","plus":"+1 次"},{"entryId":392,"day":"2026-\#
                10-08","text":"地铁上背了半小时单词","when":"10月8日 07:48","plus":"+1 次"},{"entryId":369,"day":"2026-10-06","te\#
                xt":"背单词 25 分钟","when":"10月6日 07:55","plus":"+1 次"},{"entryId":357,"day":"2026-10-05","text":"地铁上背了2\#
                0分钟单词","when":"10月5日 07:50","plus":"+1 次"},{"entryId":330,"day":"2026-10-03","text":"用APP背了20分钟单词","\#
                when":"10月3日 07:52","plus":"+1 次"},{"entryId":318,"day":"2026-10-02","text":"背单词 25 分钟","when":"10月2\#
                日 07:55","plus":"+1 次"},{"entryId":305,"day":"2026-10-01","text":"地铁上背了20分钟单词","when":"10月1日 07:50",\#
                "plus":"+1 次"},{"entryId":291,"day":"2026-09-30","text":"地铁上背了半小时单词","when":"9月30日 07:48","plus":"+1\#
                 次"},{"entryId":281,"day":"2026-09-29","text":"用APP背了20分钟单词","when":"9月29日 07:52","plus":"+1 次"},{"e\#
                ntryId":272,"day":"2026-09-28","text":"背单词 25 分钟","when":"9月28日 07:55","plus":"+1 次"},{"entryId":247\#
                ,"day":"2026-09-26","text":"地铁上背了半小时单词","when":"9月26日 07:48","plus":"+1 次"},{"entryId":227,"day":"20\#
                26-09-24","text":"背单词 25 分钟","when":"9月24日 07:55","plus":"+1 次"},{"entryId":211,"day":"2026-09-22","\#
                text":"地铁上背了半小时单词","when":"9月22日 07:48","plus":"+1 次"},{"entryId":204,"day":"2026-09-21","text":"用AP\#
                P背了20分钟单词","when":"9月21日 07:52","plus":"+1 次"},{"entryId":190,"day":"2026-09-19","text":"地铁上背了20分钟单词\#
                ","when":"9月19日 07:50","plus":"+1 次"},{"entryId":177,"day":"2026-09-17","text":"用APP背了20分钟单词","when"\#
                :"9月17日 07:52","plus":"+1 次"},{"entryId":166,"day":"2026-09-16","text":"背单词 25 分钟","when":"9月16日 07:\#
                55","plus":"+1 次"},{"entryId":157,"day":"2026-09-15","text":"地铁上背了20分钟单词","when":"9月15日 07:50","plus\#
                ":"+1 次"},{"entryId":148,"day":"2026-09-14","text":"地铁上背了半小时单词","when":"9月14日 07:48","plus":"+1 次"},\#
                {"entryId":133,"day":"2026-09-12","text":"背单词 25 分钟","when":"9月12日 07:55","plus":"+1 次"},{"entryId":\#
                117,"day":"2026-09-10","text":"地铁上背了半小时单词","when":"9月10日 07:48","plus":"+1 次"},{"entryId":99,"day":"\#
                2026-09-08","text":"背单词 25 分钟","when":"9月8日 07:55","plus":"+1 次"},{"entryId":91,"day":"2026-09-07","\#
                text":"地铁上背了20分钟单词","when":"9月7日 07:50","plus":"+1 次"},{"entryId":77,"day":"2026-09-05","text":"用APP\#
                背了20分钟单词","when":"9月5日 07:52","plus":"+1 次"},{"entryId":62,"day":"2026-09-03","text":"地铁上背了20分钟单词","\#
                when":"9月3日 07:50","plus":"+1 次"},{"entryId":46,"day":"2026-09-01","text":"用APP背了20分钟单词","when":"9月1\#
                日 07:52","plus":"+1 次"},{"entryId":36,"day":"2026-08-31","text":"背单词 25 分钟","when":"8月31日 07:55","pl\#
                us":"+1 次"}],"recentTotal":38,"days":null,"daysNote":null,"mood":{"moved":18,"movedGood":10,"other":\#
                8,"otherGood":3,"text":"做了的 18 天里 10 天挺好以上；别的日子 8 天里 3 天","few":false,"title":"做了的 18 天里 10 天挺好以上；别的\#
                日子 8 天里 3 天。","foot":null},"milestones":null,"children":null,"said":null,"rest":null,"habit":{"quiet\#
                ":false},"settings":{"title":"每周背单词 4 次","target":{"value":4,"unit":"次"},"targetText":"4 次","categor\#
                y":"学习","only":"名称里带「背单词」「单词」的记录","period":"每周","start":"8月31日","care":{"key":"growth","name":"成长"},\#
                "remind":null,"rest":null}}}
                """#,
            "/api/goals/2": #"""
                {"restPerWeek":2,"title":"每天走 8000 步","kind":"quantity","period":"week","repeat":true,"start":"2026-\#
                09-01","end":null,"calc":"daily","direction":"gte","target":8000,"unit":"步","binding":{"category":"e\#
                xercise","metric":"value","metricUnit":"步"},"id":2,"parentId":null,"status":"active","createdAt":"20\#
                26-09-01T01:20:00.000Z","range":{"from":"2026-10-26","to":"2026-11-01"},"rangeLabel":"10月26日–11月1日",\#
                "progress":{"target":8000,"unit":"步","ended":false,"daysLeft":6,"tone":"warn","pct":0,"actual":0,"da\#
                ys":2,"reached":false,"prediction":{"kind":"none"},"headline":"做到 0 天"},"prediction":"","page":{"car\#
                d":{"id":2,"parentId":null,"title":"每天走 8000 步","care":"health","kind":"quantity","calc":"daily","st\#
                ate":"track","line":"30 天做到 26 天","second":"这周用了 1 次补假","ring":"26 天","pct":0.867,"lagging":false,"a\#
                sking":false,"paused":false,"streak":{"weekly":false,"marks":["rest","rest","miss","done","done","do\#
                ne","done","done","done","done","done","done","rest","today"],"habit":false},"closed":null,"why":nul\#
                l},"sub":"健康 · 每天","head":{"big":"26","bigUnit":" / 30 天做到","line":"这周用了 1 次补假，还剩 1 次","more":"连续 10\#
                 天没断 · 最近 30 天里最长 19 天","nums":[{"label":"做到","value":"26 天"},{"label":"用了补假","value":"3 天"},{"label\#
                ":"没做到","value":"1 天"},{"label":"今天","value":"4,605 步"}]},"ask":null,"three":null,"remind":null,"cha\#
                rt":{"kind":"days","days":[{"day":"2026-09-27","mark":"done","value":10948},{"day":"2026-09-28","mar\#
                k":"done","value":12725},{"day":"2026-09-29","mark":"done","value":9102},{"day":"2026-09-30","mark":\#
                "done","value":10879},{"day":"2026-10-01","mark":"done","value":12656},{"day":"2026-10-02","mark":"d\#
                one","value":9033},{"day":"2026-10-03","mark":"done","value":10810},{"day":"2026-10-04","mark":"done\#
                ","value":12587},{"day":"2026-10-05","mark":"done","value":8964},{"day":"2026-10-06","mark":"done","\#
                value":10741},{"day":"2026-10-07","mark":"done","value":12518},{"day":"2026-10-08","mark":"done","va\#
                lue":8895},{"day":"2026-10-09","mark":"done","value":10672},{"day":"2026-10-10","mark":"done","value\#
                ":12449},{"day":"2026-10-11","mark":"done","value":8826},{"day":"2026-10-12","mark":"done","value":1\#
                0603},{"day":"2026-10-13","mark":"done","value":12380},{"day":"2026-10-14","mark":"rest","value":620\#
                0},{"day":"2026-10-15","mark":"rest","value":5900},{"day":"2026-10-16","mark":"miss","value":4800},{\#
                "day":"2026-10-17","mark":"done","value":8688},{"day":"2026-10-18","mark":"done","value":10465},{"da\#
                y":"2026-10-19","mark":"done","value":12242},{"day":"2026-10-20","mark":"done","value":8619},{"day":\#
                "2026-10-21","mark":"done","value":10396},{"day":"2026-10-22","mark":"done","value":12173},{"day":"2\#
                026-10-23","mark":"done","value":8550},{"day":"2026-10-24","mark":"done","value":10327},{"day":"2026\#
                -10-25","mark":"done","value":12104},{"day":"2026-10-26","mark":"rest","value":6039},{"day":"2026-10\#
                -27","mark":"today","value":4605}]},"chartTitle":"最近 30 天","chartMeta":"做到 26 · 补假 3 · 没做到 1","best"\#
                :null,"recent":[],"recentTotal":0,"days":[{"day":"2026-10-27","label":"10月27日 周二","value":"4,605 步",\#
                "mark":"today"},{"day":"2026-10-26","label":"10月26日 周一","value":"6,039 步","mark":"rest"},{"day":"202\#
                6-10-25","label":"10月25日 周日","value":"12,104 步","mark":"done"},{"day":"2026-10-24","label":"10月24日 周\#
                六","value":"10,327 步","mark":"done"},{"day":"2026-10-23","label":"10月23日 周五","value":"8,550 步","mark\#
                ":"done"},{"day":"2026-10-22","label":"10月22日 周四","value":"12,173 步","mark":"done"},{"day":"2026-10-\#
                21","label":"10月21日 周三","value":"10,396 步","mark":"done"}],"daysNote":"来自健康 App，不用说","mood":null,"mi\#
                lestones":null,"children":null,"said":null,"rest":{"perWeek":2,"lines":[{"day":"10月14日 周三","text":"6\#
                ,200 步 · 用了补假"},{"day":"10月15日 周四","text":"5,900 步 · 用了补假"},{"day":"10月16日 周五","text":"4,800 步 · 这周 \#
                2 次补假用完了"},{"day":"10月26日 周一","text":"6,039 步 · 用了补假"}],"habitLeft":"再连续 7 周每周都做到，就算成习惯了（上一次没做到是 10月\#
                16日）。"},"habit":null,"settings":{"title":"每天走 8000 步","target":{"value":8000,"unit":"步"},"targetText\#
                ":"每天 8000 步","category":"运动","only":null,"period":"每天","start":"9月1日","care":{"key":"health","name"\#
                :"健康"},"remind":null,"rest":2}}}
                """#,
        ]
    }
#endif
