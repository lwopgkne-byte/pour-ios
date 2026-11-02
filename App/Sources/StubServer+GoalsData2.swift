// swift-format-ignore-file
#if DEBUG
    /// 3.0 目标的假服务器数据（第 2 份）：10月27日（原型那天）的演示数据，服务器 2.15.0 原样拿的（docs/3.0/01-需求文档.md 9.13）
    extension Goals3Stub {
        static let part2: [String: String] = [
            "/api/goals/3": #"""
                {"title":"平均睡 7.5 小时","kind":"quantity","period":"week","repeat":true,"start":"2026-09-01","end":nul\#
                l,"calc":"avg","direction":"gte","target":7.5,"unit":"小时","binding":{"category":"sleep","metric":"du\#
                ration"},"id":3,"parentId":null,"status":"active","createdAt":"2026-09-01T01:20:00.000Z","range":{"f\#
                rom":"2026-10-26","to":"2026-11-01"},"rangeLabel":"10月26日–11月1日","progress":{"target":7.5,"unit":"小时\#
                ","ended":false,"daysLeft":6,"tone":"warn","pct":0.911,"actual":6.833,"days":2,"neededPerDay":7.722,\#
                "reached":false,"prediction":{"kind":"none"},"headline":"实际 6.8 小时 · 差 0.7 小时"},"prediction":"","pag\#
                e":{"card":{"id":3,"parentId":null,"title":"平均睡 7.5 小时","care":"health","kind":"quantity","calc":"av\#
                g","state":"behind","line":"这周平均每晚差 40 分钟","second":null,"ring":"91%","pct":0.911,"lagging":false,"a\#
                sking":false,"paused":false,"streak":null,"closed":null,"why":null},"sub":"健康 · 每周 · 10月26日–11月1日","\#
                head":{"big":"6:50","bigUnit":"","line":"这周平均每晚差 40 分钟","more":"这周两晚都是 6 小时 50 分，目标每晚 7:30","nums":[\#
                {"label":"这周实际","value":"6:50"},{"label":"还剩","value":"5 晚"},{"label":"剩下每晚要睡","value":"7:46"}]},"as\#
                k":null,"three":null,"remind":null,"chart":{"kind":"weeks","rows":[{"label":"9月7日","value":7.57,"not\#
                e":null,"current":false},{"label":"9月14日","value":7.12,"note":null,"current":false},{"label":"9月21日"\#
                ,"value":7.64,"note":null,"current":false},{"label":"9月28日","value":7.63,"note":null,"current":false\#
                },{"label":"10月5日","value":7.38,"note":null,"current":false},{"label":"10月12日","value":7.26,"note":n\#
                ull,"current":false},{"label":"10月19日","value":7.38,"note":null,"current":false},{"label":"10月26日","\#
                value":6.83,"note":"这周到今天","current":true}],"line":7.5,"lineLabel":"目标","format":"hm","unit":"小时","m\#
                oney":false},"chartTitle":"每周平均","chartMeta":"按住拖动看每一周","best":null,"recent":[{"entryId":642,"day":"\#
                2026-10-27","text":"又过了12点才睡 12点10分 早上7点起的","when":"10月27日 07:35","plus":""},{"entryId":621,"day":"2\#
                026-10-26","text":"昨晚12点10分才睡 早上7点起","when":"10月26日 07:35","plus":""},{"entryId":606,"day":"2026-10-\#
                25","text":"12点40分睡的 8点40分醒 睡了8个小时","when":"10月25日 09:10","plus":""},{"entryId":590,"day":"2026-10-2\#
                4","text":"又过了12点才睡 12点40分 早上8点20分起的","when":"10月24日 07:40","plus":""},{"entryId":578,"day":"2026-10\#
                -23","text":"昨晚12点10分才睡 早上7点10分起","when":"10月23日 07:35","plus":""},{"entryId":565,"day":"2026-10-22"\#
                ,"text":"12点10分睡的 7点20分醒 睡了7个小时","when":"10月22日 07:35","plus":""},{"entryId":553,"day":"2026-10-21",\#
                "text":"又过了12点才睡 12点10分 早上7点起的","when":"10月21日 07:35","plus":""},{"entryId":539,"day":"2026-10-20","\#
                text":"睡了7.5个小时 11点50分到7点10分","when":"10月20日 07:35","plus":""},{"entryId":529,"day":"2026-10-19","te\#
                xt":"昨天11点40分左右睡的 早上7点20分醒的","when":"10月19日 07:35","plus":""},{"entryId":516,"day":"2026-10-18","tex\#
                t":"凌晨5点40分就醒了 一直没睡着 好困","when":"10月18日 07:40","plus":""},{"entryId":503,"day":"2026-10-17","text":"\#
                昨晚12点才睡 早上8点20分起","when":"10月17日 09:10","plus":""},{"entryId":478,"day":"2026-10-15","text":"昨天11点半左\#
                右睡的 早上7点20分醒的","when":"10月15日 07:35","plus":""},{"entryId":466,"day":"2026-10-14","text":"11点10分睡 7点\#
                10分起","when":"10月14日 07:35","plus":""},{"entryId":452,"day":"2026-10-13","text":"昨晚上线 熬到凌晨3点40才睡 早上1\#
                0点05起的","when":"10月13日 07:35","plus":""},{"entryId":439,"day":"2026-10-12","text":"睡了7.5个小时 11点半到7点1\#
                0分","when":"10月12日 07:35","plus":""},{"entryId":431,"day":"2026-10-11","text":"昨晚12点20分才睡 早上8点20分起",\#
                "when":"10月11日 07:40","plus":""},{"entryId":419,"day":"2026-10-10","text":"12点20分睡的 8点半醒 睡了8个小时","wh\#
                en":"10月10日 09:10","plus":""},{"entryId":407,"day":"2026-10-09","text":"昨晚没睡好 5点10分就醒了 再也没睡着 困死了","w\#
                hen":"10月9日 07:35","plus":""},{"entryId":389,"day":"2026-10-08","text":"睡了7.5个小时 11点20分到7点","when":"\#
                10月8日 07:35","plus":""},{"entryId":376,"day":"2026-10-07","text":"昨天11点10分左右睡的 早上7点10分醒的","when":"10\#
                月7日 07:35","plus":""},{"entryId":365,"day":"2026-10-06","text":"昨晚睡得不踏实 5点半就醒了 头昏昏的 太困了","when":"10月\#
                6日 07:35","plus":""},{"entryId":355,"day":"2026-10-05","text":"昨晚11点20分睡的 早上7点10分起","when":"10月5日 07\#
                :35","plus":""},{"entryId":343,"day":"2026-10-04","text":"12点40分睡的 8点半醒 睡了8个小时","when":"10月4日 09:10"\#
                ,"plus":""},{"entryId":327,"day":"2026-10-03","text":"昨天11点左右睡的 早上8点40分醒的","when":"10月3日 09:10","plu\#
                s":""},{"entryId":315,"day":"2026-10-02","text":"凌晨5点半就醒了 一直没睡着","when":"10月2日 07:35","plus":""},{"e\#
                ntryId":302,"day":"2026-10-01","text":"昨晚11点半睡的 早上7点起","when":"10月1日 07:35","plus":""},{"entryId":28\#
                8,"day":"2026-09-30","text":"睡了7.5个小时 11点40分到7点10分","when":"9月30日 07:35","plus":""},{"entryId":269,"\#
                day":"2026-09-28","text":"11点20分睡 7点10分起","when":"9月28日 07:35","plus":""},{"entryId":257,"day":"2026\#
                -09-27","text":"又过了12点才睡 12点10分 早上8点半起的","when":"9月27日 07:40","plus":""},{"entryId":244,"day":"2026-\#
                09-26","text":"昨晚12点10分才睡 早上8点半起","when":"9月26日 07:40","plus":""},{"entryId":234,"day":"2026-09-25",\#
                "text":"昨晚没睡好 5点20分就醒了 再也没睡着 困死了","when":"9月25日 07:35","plus":""},{"entryId":224,"day":"2026-09-24",\#
                "text":"11点20分睡 7点10分起","when":"9月24日 07:35","plus":""},{"entryId":216,"day":"2026-09-23","text":"昨晚\#
                11点50分睡的 早上7点10分起","when":"9月23日 07:35","plus":""},{"entryId":210,"day":"2026-09-22","text":"睡了8个小时 \#
                11点20分到7点20分","when":"9月22日 07:35","plus":""},{"entryId":203,"day":"2026-09-21","text":"昨天11点20分左右睡的\#
                 早上7点醒的","when":"9月21日 07:35","plus":""},{"entryId":197,"day":"2026-09-20","text":"昨晚12点20分才睡 早上8点20\#
                分起","when":"9月20日 09:10","plus":""},{"entryId":189,"day":"2026-09-19","text":"昨晚睡得不踏实 5点50分就醒了 头昏昏的 \#
                太困了","when":"9月19日 09:10","plus":""},{"entryId":182,"day":"2026-09-18","text":"睡了7.5个小时 11点20分到7点","\#
                when":"9月18日 07:35","plus":""},{"entryId":176,"day":"2026-09-17","text":"昨天11点半左右睡的 早上7点10分醒的","when\#
                ":"9月17日 07:35","plus":""},{"entryId":165,"day":"2026-09-16","text":"凌晨5点40分就醒了 一直没睡着 好困","when":"9月\#
                16日 07:35","plus":""},{"entryId":156,"day":"2026-09-15","text":"昨晚11点50分睡的 早上7点起","when":"9月15日 07:3\#
                5","plus":""},{"entryId":147,"day":"2026-09-14","text":"睡了7.5个小时 11点半到7点10分","when":"9月14日 07:35","p\#
                lus":""},{"entryId":139,"day":"2026-09-13","text":"12点10分睡的 8点40分醒 睡了8.5个小时","when":"9月13日 09:10","p\#
                lus":""},{"entryId":132,"day":"2026-09-12","text":"又过了12点才睡 12点20分 早上8点20分起的","when":"9月12日 09:10","\#
                plus":""},{"entryId":126,"day":"2026-09-11","text":"昨晚11点40分睡的 早上7点起","when":"9月11日 07:35","plus":""\#
                },{"entryId":116,"day":"2026-09-10","text":"睡了8个小时 11点20分到7点10分","when":"9月10日 07:35","plus":""},{"e\#
                ntryId":108,"day":"2026-09-09","text":"昨晚没睡好 5点50分就醒了 再也没睡着 困死了","when":"9月9日 07:35","plus":""},{"en\#
                tryId":98,"day":"2026-09-08","text":"11点半睡 7点10分起","when":"9月8日 07:35","plus":""},{"entryId":90,"day\#
                ":"2026-09-07","text":"昨晚11点半睡的 早上7点10分起","when":"9月7日 07:35","plus":""},{"entryId":84,"day":"2026-0\#
                9-06","text":"昨晚睡得不踏实 5点半就醒了","when":"9月6日 09:10","plus":""}],"recentTotal":55,"days":null,"daysNote\#
                ":null,"mood":null,"milestones":null,"children":null,"said":null,"rest":null,"habit":null,"settings"\#
                :{"title":"平均睡 7.5 小时","target":{"value":7.5,"unit":"小时"},"targetText":"7.5 小时","category":"睡眠","onl\#
                y":null,"period":"每周","start":"9月1日","care":{"key":"health","name":"健康"},"remind":null,"rest":null}}\#
                }
                """#,
            "/api/goals/4": #"""
                {"three":{"why":"体检那几项回到正常","obstacle":"下班太累就不想动","plan":"如果下班觉得累，就先换上跑鞋出门走 10 分钟"},"remind":{"kind"\#
                :"time","text":"每个工作日 18:30","at":"18:30","days":[0,1,2,3,4]},"title":"今年跑 500 公里","kind":"quantity"\#
                ,"period":"year","start":"2026-09-23","end":"2026-12-31","calc":"sum","direction":"gte","target":500\#
                ,"unit":"公里","binding":{"category":"run","metric":"value","metricUnit":"公里"},"id":4,"parentId":null,\#
                "status":"active","createdAt":"2026-09-23T00:35:00.000Z","range":{"from":"2026-09-23","to":"2026-12-\#
                31"},"rangeLabel":"9月23日–12月31日","progress":{"target":500,"unit":"公里","ended":false,"daysLeft":66,"t\#
                one":"bad","pct":0.185,"actual":92.4,"expected":170,"diff":-77.6,"diffRatio":-0.456,"reached":false,\#
                "prediction":{"kind":"too_slow","percentAtEnd":0.402},"headline":"已完成 92.4 公里 · 落后 46%"},"overLocked\#
                ":false,"monthRows":[{"key":"2026-09","label":"9 月","range":{"from":"2026-09-23","to":"2026-09-30"},\#
                "target":40,"locked":false,"current":false,"progress":{"target":40,"unit":"公里","ended":true,"daysLef\#
                t":0,"tone":"good","pct":1,"actual":69.9,"expected":40,"diff":29.9,"diffRatio":0.748,"reached":true,\#
                "prediction":{"kind":"reached"},"headline":"已完成 69.9 公里 · 已达成"},"weeks":[{"key":"2026-09-23","label"\#
                :"9月23日–9月27日","range":{"from":"2026-09-23","to":"2026-09-27"},"target":25,"locked":false,"current":\#
                false,"progress":{"target":25,"unit":"公里","ended":true,"daysLeft":0,"tone":"good","pct":1,"actual":4\#
                5.7,"expected":25,"diff":20.7,"diffRatio":0.828,"reached":true,"prediction":{"kind":"reached"},"head\#
                line":"已完成 45.7 公里 · 已达成"}},{"key":"2026-09-28","label":"9月28日–9月30日","range":{"from":"2026-09-28","\#
                to":"2026-09-30"},"target":15,"locked":false,"current":false,"progress":{"target":15,"unit":"公里","en\#
                ded":true,"daysLeft":0,"tone":"good","pct":1,"actual":24.2,"expected":15,"diff":9.2,"diffRatio":0.61\#
                3,"reached":true,"prediction":{"kind":"reached"},"headline":"已完成 24.2 公里 · 已达成"}}]},{"key":"2026-10"\#
                ,"label":"10 月","range":{"from":"2026-10-01","to":"2026-10-31"},"target":155,"locked":false,"current\#
                ":true,"progress":{"target":155,"unit":"公里","ended":false,"daysLeft":5,"tone":"bad","pct":0.145,"act\#
                ual":22.5,"expected":130,"diff":-107.5,"diffRatio":-0.827,"reached":false,"prediction":{"kind":"too_\#
                slow","percentAtEnd":0.167},"headline":"已完成 22.5 公里 · 落后 83%"},"weeks":[{"key":"2026-10-01","label":\#
                "10月1日–10月4日","range":{"from":"2026-10-01","to":"2026-10-04"},"target":20,"locked":false,"current":f\#
                alse,"progress":{"target":20,"unit":"公里","ended":true,"daysLeft":0,"tone":"none","pct":0,"actual":0,\#
                "expected":20,"diff":-20,"diffRatio":-1,"reached":false,"prediction":{"kind":"none"},"headline":"已完成\#
                 0 公里 · 落后 100%"}},{"key":"2026-10-05","label":"10月5日–10月11日","range":{"from":"2026-10-05","to":"202\#
                6-10-11"},"target":35,"locked":false,"current":false,"progress":{"target":35,"unit":"公里","ended":tru\#
                e,"daysLeft":0,"tone":"none","pct":0.206,"actual":7.2,"expected":35,"diff":-27.8,"diffRatio":-0.794,\#
                "reached":false,"prediction":{"kind":"none"},"headline":"已完成 7.2 公里 · 落后 79%"}},{"key":"2026-10-12",\#
                "label":"10月12日–10月18日","range":{"from":"2026-10-12","to":"2026-10-18"},"target":35,"locked":false,"\#
                current":false,"progress":{"target":35,"unit":"公里","ended":true,"daysLeft":0,"tone":"none","pct":0.1\#
                97,"actual":6.9,"expected":35,"diff":-28.1,"diffRatio":-0.803,"reached":false,"prediction":{"kind":"\#
                none"},"headline":"已完成 6.9 公里 · 落后 80%"}},{"key":"2026-10-19","label":"10月19日–10月25日","range":{"from\#
                ":"2026-10-19","to":"2026-10-25"},"target":35,"locked":false,"current":false,"progress":{"target":35\#
                ,"unit":"公里","ended":true,"daysLeft":0,"tone":"none","pct":0.24,"actual":8.4,"expected":35,"diff":-2\#
                6.6,"diffRatio":-0.76,"reached":false,"prediction":{"kind":"none"},"headline":"已完成 8.4 公里 · 落后 76%"}\#
                },{"key":"2026-10-26","label":"10月26日–10月31日","range":{"from":"2026-10-26","to":"2026-10-31"},"targe\#
                t":30,"locked":false,"current":true,"progress":{"target":30,"unit":"公里","ended":false,"daysLeft":5,"\#
                tone":"bad","pct":0,"actual":0,"expected":5,"diff":-5,"diffRatio":-1,"reached":false,"prediction":{"\#
                kind":"not_enough"},"headline":"已完成 0 公里 · 落后 100%"}}]},{"key":"2026-11","label":"11 月","range":{"fr\#
                om":"2026-11-01","to":"2026-11-30"},"target":150,"locked":false,"current":false,"progress":{"target"\#
                :150,"unit":"公里","ended":false,"daysLeft":30,"tone":"idle","pct":0,"actual":0,"expected":0,"diff":0,\#
                "diffRatio":0,"reached":false,"prediction":{"kind":"not_enough"},"headline":"已完成 0 公里 · 刚开始"},"weeks\#
                ":[{"key":"2026-11-01","label":"11月1日","range":{"from":"2026-11-01","to":"2026-11-01"},"target":5,"l\#
                ocked":false,"current":false,"progress":{"target":5,"unit":"公里","ended":false,"daysLeft":1,"tone":"g\#
                ood","pct":0,"actual":0,"expected":0,"diff":0,"diffRatio":0,"reached":false,"prediction":{"kind":"no\#
                t_enough"},"headline":"已完成 0 公里 · 还差 5 公里"}},{"key":"2026-11-02","label":"11月2日–11月8日","range":{"fro\#
                m":"2026-11-02","to":"2026-11-08"},"target":35,"locked":false,"current":false,"progress":{"target":3\#
                5,"unit":"公里","ended":false,"daysLeft":7,"tone":"good","pct":0,"actual":0,"expected":0,"diff":0,"dif\#
                fRatio":0,"reached":false,"prediction":{"kind":"not_enough"},"headline":"已完成 0 公里 · 还差 35 公里"}},{"ke\#
                y":"2026-11-09","label":"11月9日–11月15日","range":{"from":"2026-11-09","to":"2026-11-15"},"target":35,"\#
                locked":false,"current":false,"progress":{"target":35,"unit":"公里","ended":false,"daysLeft":7,"tone":\#
                "good","pct":0,"actual":0,"expected":0,"diff":0,"diffRatio":0,"reached":false,"prediction":{"kind":"\#
                not_enough"},"headline":"已完成 0 公里 · 还差 35 公里"}},{"key":"2026-11-16","label":"11月16日–11月22日","range":\#
                {"from":"2026-11-16","to":"2026-11-22"},"target":35,"locked":false,"current":false,"progress":{"targ\#
                et":35,"unit":"公里","ended":false,"daysLeft":7,"tone":"good","pct":0,"actual":0,"expected":0,"diff":0\#
                ,"diffRatio":0,"reached":false,"prediction":{"kind":"not_enough"},"headline":"已完成 0 公里 · 还差 35 公里"}}\#
                ,{"key":"2026-11-23","label":"11月23日–11月29日","range":{"from":"2026-11-23","to":"2026-11-29"},"target\#
                ":35,"locked":false,"current":false,"progress":{"target":35,"unit":"公里","ended":false,"daysLeft":7,"\#
                tone":"good","pct":0,"actual":0,"expected":0,"diff":0,"diffRatio":0,"reached":false,"prediction":{"k\#
                ind":"not_enough"},"headline":"已完成 0 公里 · 还差 35 公里"}},{"key":"2026-11-30","label":"11月30日","range":{\#
                "from":"2026-11-30","to":"2026-11-30"},"target":5,"locked":false,"current":false,"progress":{"target\#
                ":5,"unit":"公里","ended":false,"daysLeft":1,"tone":"good","pct":0,"actual":0,"expected":0,"diff":0,"d\#
                iffRatio":0,"reached":false,"prediction":{"kind":"not_enough"},"headline":"已完成 0 公里 · 还差 5 公里"}}]},{\#
                "key":"2026-12","label":"12 月","range":{"from":"2026-12-01","to":"2026-12-31"},"target":155,"locked"\#
                :false,"current":false,"progress":{"target":155,"unit":"公里","ended":false,"daysLeft":31,"tone":"idle\#
                ","pct":0,"actual":0,"expected":0,"diff":0,"diffRatio":0,"reached":false,"prediction":{"kind":"not_e\#
                nough"},"headline":"已完成 0 公里 · 刚开始"},"weeks":[{"key":"2026-12-01","label":"12月1日–12月6日","range":{"fr\#
                om":"2026-12-01","to":"2026-12-06"},"target":30,"locked":false,"current":false,"progress":{"target":\#
                30,"unit":"公里","ended":false,"daysLeft":6,"tone":"good","pct":0,"actual":0,"expected":0,"diff":0,"di\#
                ffRatio":0,"reached":false,"prediction":{"kind":"not_enough"},"headline":"已完成 0 公里 · 还差 30 公里"}},{"k\#
                ey":"2026-12-07","label":"12月7日–12月13日","range":{"from":"2026-12-07","to":"2026-12-13"},"target":35,\#
                "locked":false,"current":false,"progress":{"target":35,"unit":"公里","ended":false,"daysLeft":7,"tone"\#
                :"good","pct":0,"actual":0,"expected":0,"diff":0,"diffRatio":0,"reached":false,"prediction":{"kind":\#
                "not_enough"},"headline":"已完成 0 公里 · 还差 35 公里"}},{"key":"2026-12-14","label":"12月14日–12月20日","range"\#
                :{"from":"2026-12-14","to":"2026-12-20"},"target":35,"locked":false,"current":false,"progress":{"tar\#
                get":35,"unit":"公里","ended":false,"daysLeft":7,"tone":"good","pct":0,"actual":0,"expected":0,"diff":\#
                0,"diffRatio":0,"reached":false,"prediction":{"kind":"not_enough"},"headline":"已完成 0 公里 · 还差 35 公里"}\#
                },{"key":"2026-12-21","label":"12月21日–12月27日","range":{"from":"2026-12-21","to":"2026-12-27"},"targe\#
                t":35,"locked":false,"current":false,"progress":{"target":35,"unit":"公里","ended":false,"daysLeft":7,\#
                "tone":"good","pct":0,"actual":0,"expected":0,"diff":0,"diffRatio":0,"reached":false,"prediction":{"\#
                kind":"not_enough"},"headline":"已完成 0 公里 · 还差 35 公里"}},{"key":"2026-12-28","label":"12月28日–12月31日","\#
                range":{"from":"2026-12-28","to":"2026-12-31"},"target":20,"locked":false,"current":false,"progress"\#
                :{"target":20,"unit":"公里","ended":false,"daysLeft":4,"tone":"good","pct":0,"actual":0,"expected":0,"\#
                diff":0,"diffRatio":0,"reached":false,"prediction":{"kind":"not_enough"},"headline":"已完成 0 公里 · 还差 2\#
                0 公里"}}]}],"prediction":"按最近的速度，到期末大约完成 40%","page":{"card":{"id":4,"parentId":null,"title":"今年跑 500\#
                 公里","care":"health","kind":"quantity","calc":"sum","state":"behind","line":"比应达少 78 公里","second":"落\#
                后两周了，聊聊怎么调？","ring":"18%","pct":0.185,"lagging":true,"asking":false,"paused":false,"streak":null,"cl\#
                osed":null,"why":null},"sub":"健康 · 今年 · 9月23日–12月31日","head":{"big":"92.4","bigUnit":" / 500 公里","li\#
                ne":"比应达少 78 公里","more":"照最近的速度，年底在 163–193 公里之间","nums":[{"label":"到昨天应达","value":"170 公里"},{"label\#
                ":"实际","value":"92.4 公里"},{"label":"还剩","value":"66 天"},{"label":"剩下每天","value":"6.2 公里"}]},"ask":nu\#
                ll,"three":{"why":"体检那几项回到正常","obstacle":"下班太累就不想动","plan":"如果下班觉得累，就先换上跑鞋出门走 10 分钟"},"remind":{"kin\#
                d":"time","text":"每个工作日 18:30","at":"18:30","days":[0,1,2,3,4],"line":"每个工作日 18:30 提醒你「如果就」"},"chart\#
                ":{"kind":"line","from":"2026-09-23","days":100,"today":34,"target":500,"unit":"公里","actual":[10,18.\#
                2,18.2,30.7,45.7,45.7,55.5,69.9,69.9,69.9,69.9,69.9,69.9,69.9,69.9,69.9,69.9,69.9,77.1,77.1,77.1,77.\#
                1,77.1,77.1,77.1,84,84,84,84,84,84,92.4,92.4,92.4,92.4],"expected":[5,10,15,20,25,30,35,40,45,50,55,\#
                60,65,70,75,80,85,90,95,100,105,110,115,120,125,130,135,140,145,150,155,160,165,170,175,180,185,190,\#
                195,200,205,210,215,220,225,230,235,240,245,250,255,260,265,270,275,280,285,290,295,300,305,310,315,\#
                320,325,330,335,340,345,350,355,360,365,370,375,380,385,390,395,400,405,410,415,420,425,430,435,440,\#
                445,450,455,460,465,470,475,480,485,490,495,500],"slow":1.093,"fast":1.543,"ticks":[{"at":0,"text":"\#
                9/23"},{"at":39,"text":"11月"},{"at":69,"text":"12月"},{"at":99,"text":"12/31"}]},"chartTitle":"应达和实际"\#
                ,"chartMeta":"按住拖动看每一天","best":{"grid":[[0,0,0],[0,0,1],[0,0,2],[0,0,1],[0,0,0],[2,0,0],[3,0,0]],"te\#
                xt":"周末早上跑了 5 次；工作日晚上 4 次，都在 9 月。","best":{"days":[5],"part":0,"at":"08:00","text":"周六 08:00"},"sugg\#
                est":{"remind":{"kind":"time","text":"周六 08:00","at":"08:00","days":[5]},"label":"把提醒放在周六 08:00"},"a\#
                lready":null},"recent":[{"entryId":593,"day":"2026-10-24","text":"早上在小区跑了8.4公里 配速5分50","when":"10月24\#
                日 早上","plus":"+8.4 公里"},{"entryId":519,"day":"2026-10-18","text":"早上跑了 6.9 公里 有点喘","when":"10月18日 早上\#
                ","plus":"+6.9 公里"},{"entryId":433,"day":"2026-10-11","text":"早上在小区跑了 7 公里 下午带儿子游泳","when":"10月11日 早\#
                上","plus":"+7.2 公里"},{"entryId":290,"day":"2026-09-30","text":"晚上跑了 14.4 公里 明天开始放假","when":"9月30日 晚上\#
                ","plus":"+14.4 公里"},{"entryId":280,"day":"2026-09-29","text":"下班跑了快 10 公里","when":"9月29日 晚上","plus"\#
                :"+9.8 公里"},{"entryId":259,"day":"2026-09-27","text":"早上跑了 15 公里 有点上头","when":"9月27日 早上","plus":"+15\#
                 公里"},{"entryId":246,"day":"2026-09-26","text":"早上在小区跑了 12.5 公里","when":"9月26日 早上","plus":"+12.5 公里"\#
                },{"entryId":226,"day":"2026-09-24","text":"晚上又跑了 8.2 公里 腿有点酸","when":"9月24日 晚上","plus":"+8.2 公里"},{\#
                "entryId":218,"day":"2026-09-23","text":"下班跑了 10 公里 第一次跑这么远","when":"9月23日 晚上","plus":"+10 公里"}],"re\#
                centTotal":9,"days":null,"daysNote":null,"mood":{"moved":3,"movedGood":2,"other":23,"otherGood":11,"\#
                text":"跑了的 3 天里 2 天挺好以上；别的日子 23 天里 11 天","few":true,"title":"跑了的 3 天里 2 天挺好以上；别的日子 23 天里 11 天。","foo\#
                t":"10 月只有 3 天跑了，天数还少，多跑几次再看。"},"milestones":null,"children":null,"said":null,"rest":null,"habit":nu\#
                ll,"settings":{"title":"今年跑 500 公里","target":{"value":500,"unit":"公里"},"targetText":"500 公里","catego\#
                ry":"运动 → 跑步","only":null,"period":"今年","start":"9月23日","care":{"key":"health","name":"健康"},"remind"\#
                :"每个工作日 18:30","rest":null}}}
                """#,
            "/api/goals/5": #"""
                {"title":"跑完第一个 10 公里","kind":"completion","period":"year","start":"2026-09-23","end":null,"id":5,"p\#
                arentId":null,"status":"done","doneAt":"2026-09-23T12:40:00.000Z","createdAt":"2026-09-23T00:35:00.0\#
                00Z","range":{"from":"2026-09-23","to":"2026-12-31"},"rangeLabel":"9月23日–12月31日","progress":{"tone":\#
                "good","pct":1,"actual":1,"target":1,"unit":"","reached":true,"ended":true,"daysLeft":0,"prediction"\#
                :{"kind":"none"},"headline":"已完成 · 9月23日"},"prediction":"","page":{"card":{"id":5,"parentId":null,"t\#
                itle":"跑完第一个 10 公里","care":null,"kind":"completion","calc":null,"state":"done","line":"做到了","second"\#
                :null,"ring":null,"pct":0,"lagging":false,"asking":false,"paused":false,"streak":null,"closed":"9月23\#
                日做到","why":null},"sub":"其他 · 9月23日起","head":{"big":"","bigUnit":"","line":"做到了","more":null,"nums":[\#
                ]},"ask":null,"three":null,"remind":null,"chart":null,"chartTitle":null,"chartMeta":null,"best":null\#
                ,"recent":[],"recentTotal":0,"days":null,"daysNote":null,"mood":null,"milestones":[],"children":null\#
                ,"said":null,"rest":null,"habit":null,"settings":{"title":"跑完第一个 10 公里","target":null,"targetText":"\#
                0 个里程碑","category":null,"only":null,"period":"今年","start":"9月23日","care":null,"remind":null,"rest":n\#
                ull}}}
                """#,
            "/api/goals/6": #"""
                {"title":"连续 7 天 12 点前睡","kind":"quantity","period":"week","start":"2026-09-29","end":"2026-10-12","\#
                calc":"streak","direction":"gte","target":7,"unit":"天","binding":{"category":"sleep","metric":"count\#
                "},"id":6,"parentId":null,"status":"done","doneAt":"2026-10-06T01:00:00.000Z","createdAt":"2026-09-2\#
                9T14:40:00.000Z","range":{"from":"2026-09-29","to":"2026-10-12"},"rangeLabel":"9月29日–10月12日","progre\#
                ss":{"target":7,"unit":"天","ended":true,"daysLeft":0,"tone":"good","pct":1,"actual":14,"best":14,"re\#
                ached":true,"prediction":{"kind":"reached"},"headline":"连续 14 天 · 最长 14 天"},"prediction":"已经达成","pag\#
                e":{"card":{"id":6,"parentId":null,"title":"连续 7 天 12 点前睡","care":"health","kind":"quantity","calc":\#
                "streak","state":"done","line":"做到了","second":null,"ring":"100%","pct":1,"lagging":false,"asking":fa\#
                lse,"paused":false,"streak":null,"closed":"10月6日做到","why":null},"sub":"健康 · 9月29日–10月12日","head":{"b\#
                ig":"14","bigUnit":" / 7 天","line":"做到了","more":null,"nums":[{"label":"到昨天应达","value":"0 天"},{"label\#
                ":"实际","value":"14 天"},{"label":"还剩","value":"0 天"},{"label":"剩下每天","value":"0 天"}]},"ask":null,"thr\#
                ee":null,"remind":null,"chart":{"kind":"line","from":"2026-09-29","days":14,"today":13,"target":7,"u\#
                nit":"天","actual":[1,2,3,4,5,6,7,8,9,10,11,12,13,14],"expected":[0.5,1,1.5,2,2.5,3,3.5,4,4.5,5,5.5,6\#
                ,6.5,7],"slow":null,"fast":null,"ticks":[{"at":0,"text":"9/29"},{"at":2,"text":"10月"},{"at":13,"text\#
                ":"10/12"}]},"chartTitle":"应达和实际","chartMeta":"按住拖动看每一天","best":{"grid":[[0,0,4],[0,0,4],[0,0,4],[0,\#
                0,4],[0,0,3],[0,0,4],[0,0,4]],"text":"工作日晚上 19 次；周末晚上 8 次。","best":{"days":[0,1,2,3,4],"part":2,"at"\#
                :"18:30","text":"每个工作日 18:30"},"suggest":{"remind":{"kind":"time","text":"每个工作日 18:30","at":"18:30",\#
                "days":[0,1,2,3,4]},"label":"把提醒放在每个工作日 18:30"},"already":null},"recent":[{"entryId":642,"day":"2026\#
                -10-27","text":"又过了12点才睡 12点10分 早上7点起的","when":"10月27日 晚上","plus":"+1 次"},{"entryId":621,"day":"2026\#
                -10-26","text":"昨晚12点10分才睡 早上7点起","when":"10月26日 晚上","plus":"+1 次"},{"entryId":606,"day":"2026-10-25\#
                ","text":"12点40分睡的 8点40分醒 睡了8个小时","when":"10月25日 晚上","plus":"+1 次"},{"entryId":590,"day":"2026-10-24\#
                ","text":"又过了12点才睡 12点40分 早上8点20分起的","when":"10月24日 晚上","plus":"+1 次"},{"entryId":578,"day":"2026-10\#
                -23","text":"昨晚12点10分才睡 早上7点10分起","when":"10月23日 晚上","plus":"+1 次"},{"entryId":565,"day":"2026-10-22\#
                ","text":"12点10分睡的 7点20分醒 睡了7个小时","when":"10月22日 晚上","plus":"+1 次"},{"entryId":553,"day":"2026-10-21\#
                ","text":"又过了12点才睡 12点10分 早上7点起的","when":"10月21日 晚上","plus":"+1 次"},{"entryId":539,"day":"2026-10-20\#
                ","text":"睡了7.5个小时 11点50分到7点10分","when":"10月20日 晚上","plus":"+1 次"},{"entryId":529,"day":"2026-10-19"\#
                ,"text":"昨天11点40分左右睡的 早上7点20分醒的","when":"10月19日 晚上","plus":"+1 次"},{"entryId":516,"day":"2026-10-18"\#
                ,"text":"凌晨5点40分就醒了 一直没睡着 好困","when":"10月18日 晚上","plus":"+1 次"},{"entryId":503,"day":"2026-10-17","t\#
                ext":"昨晚12点才睡 早上8点20分起","when":"10月17日 晚上","plus":"+1 次"},{"entryId":478,"day":"2026-10-15","text":"\#
                昨天11点半左右睡的 早上7点20分醒的","when":"10月15日 晚上","plus":"+1 次"},{"entryId":466,"day":"2026-10-14","text":"11\#
                点10分睡 7点10分起","when":"10月14日 晚上","plus":"+1 次"},{"entryId":452,"day":"2026-10-13","text":"昨晚上线 熬到凌晨3\#
                点40才睡 早上10点05起的","when":"10月13日 晚上","plus":"+1 次"},{"entryId":439,"day":"2026-10-12","text":"睡了7.5个小\#
                时 11点半到7点10分","when":"10月12日 晚上","plus":"+1 次"},{"entryId":431,"day":"2026-10-11","text":"昨晚12点20分才睡\#
                 早上8点20分起","when":"10月11日 晚上","plus":"+1 次"},{"entryId":419,"day":"2026-10-10","text":"12点20分睡的 8点半醒\#
                 睡了8个小时","when":"10月10日 晚上","plus":"+1 次"},{"entryId":407,"day":"2026-10-09","text":"昨晚没睡好 5点10分就醒了 \#
                再也没睡着 困死了","when":"10月9日 晚上","plus":"+1 次"},{"entryId":389,"day":"2026-10-08","text":"睡了7.5个小时 11点20\#
                分到7点","when":"10月8日 晚上","plus":"+1 次"},{"entryId":376,"day":"2026-10-07","text":"昨天11点10分左右睡的 早上7点10\#
                分醒的","when":"10月7日 晚上","plus":"+1 次"},{"entryId":365,"day":"2026-10-06","text":"昨晚睡得不踏实 5点半就醒了 头昏昏的 \#
                太困了","when":"10月6日 晚上","plus":"+1 次"},{"entryId":355,"day":"2026-10-05","text":"昨晚11点20分睡的 早上7点10分起"\#
                ,"when":"10月5日 晚上","plus":"+1 次"},{"entryId":343,"day":"2026-10-04","text":"12点40分睡的 8点半醒 睡了8个小时","w\#
                hen":"10月4日 晚上","plus":"+1 次"},{"entryId":327,"day":"2026-10-03","text":"昨天11点左右睡的 早上8点40分醒的","when"\#
                :"10月3日 晚上","plus":"+1 次"},{"entryId":315,"day":"2026-10-02","text":"凌晨5点半就醒了 一直没睡着","when":"10月2日 晚\#
                上","plus":"+1 次"},{"entryId":302,"day":"2026-10-01","text":"昨晚11点半睡的 早上7点起","when":"10月1日 晚上","plus"\#
                :"+1 次"},{"entryId":288,"day":"2026-09-30","text":"睡了7.5个小时 11点40分到7点10分","when":"9月30日 晚上","plus":"\#
                +1 次"}],"recentTotal":27,"days":null,"daysNote":null,"mood":{"moved":26,"movedGood":13,"other":0,"ot\#
                herGood":0,"text":"做了的 26 天里 13 天挺好以上","few":false,"title":"做了的 26 天里 13 天挺好以上。","foot":null},"miles\#
                tones":null,"children":null,"said":null,"rest":null,"habit":null,"settings":{"title":"连续 7 天 12 点前睡"\#
                ,"target":{"value":7,"unit":"天"},"targetText":"7 天","category":"睡眠","only":null,"period":"这周","start\#
                ":"9月29日","care":{"key":"health","name":"健康"},"remind":null,"rest":null}}}
                """#,
            "/api/goals/7": #"""
                {"restPerWeek":2,"letgoAt":"2026-10-12T15:30:00.000Z","letgoWhy":"工作太忙，先放一放","title":"每天冥想 10 分钟","k\#
                ind":"quantity","period":"week","repeat":true,"start":"2026-09-30","end":null,"calc":"daily","direct\#
                ion":"gte","target":10,"unit":"分钟","binding":{"category":"c-874bb6a3","metric":"duration"},"id":7,"p\#
                arentId":null,"status":"letgo","createdAt":"2026-09-30T14:40:00.000Z","range":{"from":"2026-10-26","\#
                to":"2026-11-01"},"rangeLabel":"10月26日–11月1日","progress":{"target":10,"unit":"分钟","ended":false,"day\#
                sLeft":6,"tone":"idle","pct":0,"actual":0,"days":0,"reached":false,"prediction":{"kind":"none"},"hea\#
                dline":"做到 0 天"},"prediction":"","page":{"card":{"id":7,"parentId":null,"title":"每天冥想 10 分钟","care":\#
                "health","kind":"quantity","calc":"daily","state":"letgo","line":"放下了","second":null,"ring":null,"pc\#
                t":0,"lagging":false,"asking":false,"paused":false,"streak":{"weekly":false,"marks":["rest","done","\#
                miss","done","miss","rest","rest","done","miss","miss","done","done","rest","today"],"habit":false},\#
                "closed":"10月12日放下","why":"工作太忙，先放一放"},"sub":"健康 · 每天","head":{"big":"11","bigUnit":" / 30 天做到","lin\#
                e":"这周用了 1 次补假，还剩 1 次","more":"连续 3 天没断 · 最近 30 天里最长 5 天","nums":[{"label":"做到","value":"11 天"},{"la\#
                bel":"用了补假","value":"9 天"},{"label":"没做到","value":"7 天"},{"label":"今天","value":"0 分钟"}]},"ask":null,\#
                "three":null,"remind":null,"chart":{"kind":"days","days":[{"day":"2026-09-27","mark":"before","value\#
                ":0},{"day":"2026-09-28","mark":"before","value":0},{"day":"2026-09-29","mark":"before","value":0},{\#
                "day":"2026-09-30","mark":"done","value":15},{"day":"2026-10-01","mark":"rest","value":0},{"day":"20\#
                26-10-02","mark":"rest","value":0},{"day":"2026-10-03","mark":"done","value":10},{"day":"2026-10-04"\#
                ,"mark":"miss","value":0},{"day":"2026-10-05","mark":"done","value":15},{"day":"2026-10-06","mark":"\#
                rest","value":0},{"day":"2026-10-07","mark":"done","value":20},{"day":"2026-10-08","mark":"done","va\#
                lue":15},{"day":"2026-10-09","mark":"rest","value":0},{"day":"2026-10-10","mark":"miss","value":0},{\#
                "day":"2026-10-11","mark":"miss","value":0},{"day":"2026-10-12","mark":"done","value":10},{"day":"20\#
                26-10-13","mark":"rest","value":0},{"day":"2026-10-14","mark":"rest","value":0},{"day":"2026-10-15",\#
                "mark":"done","value":10},{"day":"2026-10-16","mark":"miss","value":0},{"day":"2026-10-17","mark":"d\#
                one","value":15},{"day":"2026-10-18","mark":"miss","value":0},{"day":"2026-10-19","mark":"rest","val\#
                ue":0},{"day":"2026-10-20","mark":"rest","value":0},{"day":"2026-10-21","mark":"done","value":10},{"\#
                day":"2026-10-22","mark":"miss","value":0},{"day":"2026-10-23","mark":"miss","value":0},{"day":"2026\#
                -10-24","mark":"done","value":10},{"day":"2026-10-25","mark":"done","value":20},{"day":"2026-10-26",\#
                "mark":"rest","value":0},{"day":"2026-10-27","mark":"today","value":0}]},"chartTitle":"最近 30 天","cha\#
                rtMeta":"做到 11 · 补假 9 · 没做到 7","best":null,"recent":[{"entryId":616,"day":"2026-10-25","text":"跟着APP\#
                冥想了20分钟","when":"10月25日 21:50","plus":""},{"entryId":600,"day":"2026-10-24","text":"冥想10分钟","when":"\#
                10月24日 21:50","plus":""},{"entryId":561,"day":"2026-10-21","text":"冥想10分钟","when":"10月21日 21:40","pl\#
                us":""},{"entryId":511,"day":"2026-10-17","text":"睡前冥想了15分钟","when":"10月17日 21:50","plus":""},{"entr\#
                yId":489,"day":"2026-10-15","text":"冥想10分钟","when":"10月15日 21:40","plus":""},{"entryId":449,"day":"2\#
                026-10-12","text":"冥想10分钟","when":"10月12日 21:40","plus":""},{"entryId":402,"day":"2026-10-08","text"\#
                :"睡前冥想了15分钟","when":"10月8日 21:40","plus":""},{"entryId":384,"day":"2026-10-07","text":"跟着APP冥想了20分钟"\#
                ,"when":"10月7日 21:40","plus":""},{"entryId":362,"day":"2026-10-05","text":"睡前冥想了15分钟","when":"10月5日 \#
                21:40","plus":""},{"entryId":340,"day":"2026-10-03","text":"冥想10分钟","when":"10月3日 21:50","plus":""},\#
                {"entryId":298,"day":"2026-09-30","text":"第一次试了下冥想 15分钟","when":"9月30日 21:40","plus":""}],"recentTot\#
                al":11,"days":[{"day":"2026-10-27","label":"10月27日 周二","value":"0 分钟","mark":"today"},{"day":"2026-1\#
                0-26","label":"10月26日 周一","value":"0 分钟","mark":"rest"},{"day":"2026-10-25","label":"10月25日 周日","val\#
                ue":"20 分钟","mark":"done"},{"day":"2026-10-24","label":"10月24日 周六","value":"10 分钟","mark":"done"},{"\#
                day":"2026-10-23","label":"10月23日 周五","value":"0 分钟","mark":"miss"},{"day":"2026-10-22","label":"10月\#
                22日 周四","value":"0 分钟","mark":"miss"},{"day":"2026-10-21","label":"10月21日 周三","value":"10 分钟","mark"\#
                :"done"}],"daysNote":null,"mood":null,"milestones":null,"children":null,"said":null,"rest":{"perWeek\#
                ":2,"lines":[{"day":"10月1日 周四","text":"0 分钟 · 用了补假"},{"day":"10月2日 周五","text":"0 分钟 · 用了补假"},{"day":\#
                "10月4日 周日","text":"0 分钟 · 这周 2 次补假用完了"},{"day":"10月6日 周二","text":"0 分钟 · 用了补假"},{"day":"10月9日 周五","t\#
                ext":"0 分钟 · 用了补假"},{"day":"10月10日 周六","text":"0 分钟 · 这周 2 次补假用完了"},{"day":"10月11日 周日","text":"0 分钟 \#
                · 这周 2 次补假用完了"},{"day":"10月13日 周二","text":"0 分钟 · 用了补假"},{"day":"10月14日 周三","text":"0 分钟 · 用了补假"},{"\#
                day":"10月16日 周五","text":"0 分钟 · 这周 2 次补假用完了"},{"day":"10月18日 周日","text":"0 分钟 · 这周 2 次补假用完了"},{"day"\#
                :"10月19日 周一","text":"0 分钟 · 用了补假"},{"day":"10月20日 周二","text":"0 分钟 · 用了补假"},{"day":"10月22日 周四","text\#
                ":"0 分钟 · 这周 2 次补假用完了"},{"day":"10月23日 周五","text":"0 分钟 · 这周 2 次补假用完了"},{"day":"10月26日 周一","text":"0\#
                 分钟 · 用了补假"}],"habitLeft":"再连续 8 周每周都做到，就算成习惯了（上一次没做到是 10月23日）。"},"habit":null,"settings":{"title":"\#
                每天冥想 10 分钟","target":{"value":10,"unit":"分钟"},"targetText":"每天 10 分钟","category":"冥想","only":null,"p\#
                eriod":"每天","start":"9月30日","care":{"key":"health","name":"健康"},"remind":null,"rest":2}}}
                """#,
        ]
    }
#endif
