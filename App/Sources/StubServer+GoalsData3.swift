// swift-format-ignore-file
#if DEBUG
    /// 3.0 目标的假服务器数据（第 3 份）：10月27日（原型那天）的演示数据，服务器 2.15.0 原样拿的（docs/3.0/01-需求文档.md 9.13）
    extension Goals3Stub {
        static let part3: [String: String] = [
            "/api/goals/8": #"""
                {"title":"三个月瘦 5 斤","kind":"parent","period":"year","start":"2026-10-01","end":"2026-12-30","id":8,"\#
                parentId":null,"status":"active","createdAt":"2026-10-01T11:30:00.000Z","range":{"from":"2026-10-01"\#
                ,"to":"2026-12-30"},"rangeLabel":"","progress":{"tone":"warn","pct":0.735,"actual":1,"target":2,"uni\#
                t":"","reached":false,"ended":false,"daysLeft":0,"prediction":{"kind":"none"},"headline":"2 个子目标，1 个\#
                在正轨上"},"children":[{"title":"体重降到 69.5 公斤","kind":"quantity","period":"month","start":"2026-10-01","\#
                end":"2026-12-30","calc":"avg","direction":"lte","target":69.5,"unit":"公斤","binding":{"category":"c-\#
                77bc57be","metric":"value","metricUnit":"公斤","keywords":["体重"]},"id":9,"parentId":8,"status":"active\#
                ","createdAt":"2026-10-01T11:30:00.000Z","range":{"from":"2026-10-01","to":"2026-12-30"},"rangeLabel\#
                ":"10月1日–12月30日","progress":{"target":69.5,"unit":"公斤","ended":false,"daysLeft":65,"tone":"warn","pc\#
                t":0.969,"actual":71.72,"days":5,"neededPerDay":69.329,"reached":false,"prediction":{"kind":"none"},\#
                "headline":"实际 71.7 公斤 · 多 2.2 公斤"},"weekRows":[{"key":"2026-10-01","label":"10月1日–10月4日","range":{"\#
                from":"2026-10-01","to":"2026-10-04"},"target":69.5,"locked":false,"current":false,"progress":{"targ\#
                et":69.5,"unit":"公斤","ended":true,"daysLeft":0,"tone":"none","pct":0.965,"actual":72,"days":1,"neede\#
                dPerDay":null,"reached":false,"prediction":{"kind":"none"},"headline":"实际 72 公斤 · 多 2.5 公斤"}},{"key"\#
                :"2026-10-05","label":"10月5日–10月11日","range":{"from":"2026-10-05","to":"2026-10-11"},"target":69.5,"\#
                locked":false,"current":false,"progress":{"target":69.5,"unit":"公斤","ended":true,"daysLeft":0,"tone"\#
                :"none","pct":0.967,"actual":71.9,"days":1,"neededPerDay":null,"reached":false,"prediction":{"kind":\#
                "none"},"headline":"实际 71.9 公斤 · 多 2.4 公斤"}},{"key":"2026-10-12","label":"10月12日–10月18日","range":{"f\#
                rom":"2026-10-12","to":"2026-10-18"},"target":69.5,"locked":false,"current":false,"progress":{"targe\#
                t":69.5,"unit":"公斤","ended":true,"daysLeft":0,"tone":"none","pct":0.969,"actual":71.7,"days":1,"need\#
                edPerDay":null,"reached":false,"prediction":{"kind":"none"},"headline":"实际 71.7 公斤 · 多 2.2 公斤"}},{"k\#
                ey":"2026-10-19","label":"10月19日–10月25日","range":{"from":"2026-10-19","to":"2026-10-25"},"target":69\#
                .5,"locked":false,"current":false,"progress":{"target":69.5,"unit":"公斤","ended":true,"daysLeft":0,"t\#
                one":"none","pct":0.971,"actual":71.6,"days":1,"neededPerDay":null,"reached":false,"prediction":{"ki\#
                nd":"none"},"headline":"实际 71.6 公斤 · 多 2.1 公斤"}},{"key":"2026-10-26","label":"10月26日–11月1日","range":\#
                {"from":"2026-10-26","to":"2026-11-01"},"target":69.5,"locked":false,"current":true,"progress":{"tar\#
                get":69.5,"unit":"公斤","ended":false,"daysLeft":6,"tone":"warn","pct":0.973,"actual":71.4,"days":1,"n\#
                eededPerDay":69.183,"reached":false,"prediction":{"kind":"none"},"headline":"实际 71.4 公斤 · 多 1.9 公斤"}\#
                },{"key":"2026-11-02","label":"11月2日–11月8日","range":{"from":"2026-11-02","to":"2026-11-08"},"target"\#
                :69.5,"locked":false,"current":false,"progress":{"target":69.5,"unit":"公斤","ended":false,"daysLeft":\#
                7,"tone":"idle","pct":0,"actual":0,"days":0,"neededPerDay":69.5,"reached":false,"prediction":{"kind"\#
                :"none"},"headline":"还没有记录"}},{"key":"2026-11-09","label":"11月9日–11月15日","range":{"from":"2026-11-09\#
                ","to":"2026-11-15"},"target":69.5,"locked":false,"current":false,"progress":{"target":69.5,"unit":"\#
                公斤","ended":false,"daysLeft":7,"tone":"idle","pct":0,"actual":0,"days":0,"neededPerDay":69.5,"reache\#
                d":false,"prediction":{"kind":"none"},"headline":"还没有记录"}},{"key":"2026-11-16","label":"11月16日–11月22\#
                日","range":{"from":"2026-11-16","to":"2026-11-22"},"target":69.5,"locked":false,"current":false,"pro\#
                gress":{"target":69.5,"unit":"公斤","ended":false,"daysLeft":7,"tone":"idle","pct":0,"actual":0,"days"\#
                :0,"neededPerDay":69.5,"reached":false,"prediction":{"kind":"none"},"headline":"还没有记录"}},{"key":"202\#
                6-11-23","label":"11月23日–11月29日","range":{"from":"2026-11-23","to":"2026-11-29"},"target":69.5,"lock\#
                ed":false,"current":false,"progress":{"target":69.5,"unit":"公斤","ended":false,"daysLeft":7,"tone":"i\#
                dle","pct":0,"actual":0,"days":0,"neededPerDay":69.5,"reached":false,"prediction":{"kind":"none"},"h\#
                eadline":"还没有记录"}},{"key":"2026-11-30","label":"11月30日–12月6日","range":{"from":"2026-11-30","to":"202\#
                6-12-06"},"target":69.5,"locked":false,"current":false,"progress":{"target":69.5,"unit":"公斤","ended"\#
                :false,"daysLeft":7,"tone":"idle","pct":0,"actual":0,"days":0,"neededPerDay":69.5,"reached":false,"p\#
                rediction":{"kind":"none"},"headline":"还没有记录"}},{"key":"2026-12-07","label":"12月7日–12月13日","range":{\#
                "from":"2026-12-07","to":"2026-12-13"},"target":69.5,"locked":false,"current":false,"progress":{"tar\#
                get":69.5,"unit":"公斤","ended":false,"daysLeft":7,"tone":"idle","pct":0,"actual":0,"days":0,"neededPe\#
                rDay":69.5,"reached":false,"prediction":{"kind":"none"},"headline":"还没有记录"}},{"key":"2026-12-14","la\#
                bel":"12月14日–12月20日","range":{"from":"2026-12-14","to":"2026-12-20"},"target":69.5,"locked":false,"c\#
                urrent":false,"progress":{"target":69.5,"unit":"公斤","ended":false,"daysLeft":7,"tone":"idle","pct":0\#
                ,"actual":0,"days":0,"neededPerDay":69.5,"reached":false,"prediction":{"kind":"none"},"headline":"还没\#
                有记录"}},{"key":"2026-12-21","label":"12月21日–12月27日","range":{"from":"2026-12-21","to":"2026-12-27"},"\#
                target":69.5,"locked":false,"current":false,"progress":{"target":69.5,"unit":"公斤","ended":false,"day\#
                sLeft":7,"tone":"idle","pct":0,"actual":0,"days":0,"neededPerDay":69.5,"reached":false,"prediction":\#
                {"kind":"none"},"headline":"还没有记录"}},{"key":"2026-12-28","label":"12月28日–12月30日","range":{"from":"20\#
                26-12-28","to":"2026-12-30"},"target":69.5,"locked":false,"current":false,"progress":{"target":69.5,\#
                "unit":"公斤","ended":false,"daysLeft":3,"tone":"idle","pct":0,"actual":0,"days":0,"neededPerDay":69.5\#
                ,"reached":false,"prediction":{"kind":"none"},"headline":"还没有记录"}}]},{"title":"每周外卖不超过 2 次","kind":"\#
                quantity","period":"week","repeat":true,"start":"2026-10-01","end":null,"calc":"count","direction":"\#
                lte","target":2,"unit":"次","binding":{"category":"diet","metric":"count","keywords":["外卖"]},"id":10,\#
                "parentId":8,"status":"active","createdAt":"2026-10-01T11:30:00.000Z","range":{"from":"2026-10-26","\#
                to":"2026-11-01"},"rangeLabel":"10月26日–11月1日","progress":{"target":2,"unit":"次","ended":false,"daysL\#
                eft":6,"tone":"good","pct":0.5,"actual":1,"expected":1,"reached":false,"prediction":{"kind":"not_eno\#
                ugh"},"headline":"已用 1 / 2 次"}}],"prediction":"","page":{"card":{"id":8,"parentId":null,"title":"三个月\#
                瘦 5 斤","care":"health","kind":"parent","calc":null,"state":"behind","line":"2 个里 1 个在正轨上","second":n\#
                ull,"ring":"1/2","pct":0.37,"lagging":false,"asking":false,"paused":false,"streak":null,"closed":nul\#
                l,"why":null},"sub":"健康 · 10月1日–12月30日","head":{"big":"2","bigUnit":" 个子目标","line":"2 个里 1 个在正轨上","m\#
                ore":null,"nums":[]},"ask":null,"three":null,"remind":null,"chart":null,"chartTitle":null,"chartMeta\#
                ":null,"best":null,"recent":[],"recentTotal":0,"days":null,"daysNote":null,"mood":null,"milestones":\#
                null,"children":[{"id":9,"parentId":8,"title":"体重降到 69.5 公斤","care":"health","kind":"quantity","calc\#
                ":"avg","state":"behind","line":"还差 1.9 公斤","second":null,"ring":"24%","pct":0.24,"lagging":false,"a\#
                sking":false,"paused":false,"streak":null,"closed":null,"why":null},{"id":10,"parentId":8,"title":"每\#
                周外卖不超过 2 次","care":null,"kind":"quantity","calc":"count","state":"track","line":"这周还能 1 次","second":\#
                null,"ring":"50%","pct":0.5,"lagging":false,"asking":false,"paused":false,"streak":null,"closed":nul\#
                l,"why":null}],"said":{"text":"三个月瘦5斤","when":"10月1日 你说"},"rest":null,"habit":null,"settings":{"titl\#
                e":"三个月瘦 5 斤","target":null,"targetText":"看子目标","category":null,"only":null,"period":"今年","start":"1\#
                0月1日","care":{"key":"health","name":"健康"},"remind":null,"rest":null}}}
                """#,
            "/api/goals/9": #"""
                {"title":"体重降到 69.5 公斤","kind":"quantity","period":"month","start":"2026-10-01","end":"2026-12-30","\#
                calc":"avg","direction":"lte","target":69.5,"unit":"公斤","binding":{"category":"c-77bc57be","metric":\#
                "value","metricUnit":"公斤","keywords":["体重"]},"id":9,"parentId":8,"status":"active","createdAt":"2026\#
                -10-01T11:30:00.000Z","range":{"from":"2026-10-01","to":"2026-12-30"},"rangeLabel":"10月1日–12月30日","p\#
                rogress":{"target":69.5,"unit":"公斤","ended":false,"daysLeft":65,"tone":"warn","pct":0.969,"actual":7\#
                1.72,"days":5,"neededPerDay":69.329,"reached":false,"prediction":{"kind":"none"},"headline":"实际 71.7\#
                 公斤 · 多 2.2 公斤"},"weekRows":[{"key":"2026-10-01","label":"10月1日–10月4日","range":{"from":"2026-10-01",\#
                "to":"2026-10-04"},"target":69.5,"locked":false,"current":false,"progress":{"target":69.5,"unit":"公斤\#
                ","ended":true,"daysLeft":0,"tone":"none","pct":0.965,"actual":72,"days":1,"neededPerDay":null,"reac\#
                hed":false,"prediction":{"kind":"none"},"headline":"实际 72 公斤 · 多 2.5 公斤"}},{"key":"2026-10-05","labe\#
                l":"10月5日–10月11日","range":{"from":"2026-10-05","to":"2026-10-11"},"target":69.5,"locked":false,"curr\#
                ent":false,"progress":{"target":69.5,"unit":"公斤","ended":true,"daysLeft":0,"tone":"none","pct":0.967\#
                ,"actual":71.9,"days":1,"neededPerDay":null,"reached":false,"prediction":{"kind":"none"},"headline":\#
                "实际 71.9 公斤 · 多 2.4 公斤"}},{"key":"2026-10-12","label":"10月12日–10月18日","range":{"from":"2026-10-12","\#
                to":"2026-10-18"},"target":69.5,"locked":false,"current":false,"progress":{"target":69.5,"unit":"公斤"\#
                ,"ended":true,"daysLeft":0,"tone":"none","pct":0.969,"actual":71.7,"days":1,"neededPerDay":null,"rea\#
                ched":false,"prediction":{"kind":"none"},"headline":"实际 71.7 公斤 · 多 2.2 公斤"}},{"key":"2026-10-19","l\#
                abel":"10月19日–10月25日","range":{"from":"2026-10-19","to":"2026-10-25"},"target":69.5,"locked":false,"\#
                current":false,"progress":{"target":69.5,"unit":"公斤","ended":true,"daysLeft":0,"tone":"none","pct":0\#
                .971,"actual":71.6,"days":1,"neededPerDay":null,"reached":false,"prediction":{"kind":"none"},"headli\#
                ne":"实际 71.6 公斤 · 多 2.1 公斤"}},{"key":"2026-10-26","label":"10月26日–11月1日","range":{"from":"2026-10-26\#
                ","to":"2026-11-01"},"target":69.5,"locked":false,"current":true,"progress":{"target":69.5,"unit":"公\#
                斤","ended":false,"daysLeft":6,"tone":"warn","pct":0.973,"actual":71.4,"days":1,"neededPerDay":69.183\#
                ,"reached":false,"prediction":{"kind":"none"},"headline":"实际 71.4 公斤 · 多 1.9 公斤"}},{"key":"2026-11-0\#
                2","label":"11月2日–11月8日","range":{"from":"2026-11-02","to":"2026-11-08"},"target":69.5,"locked":fals\#
                e,"current":false,"progress":{"target":69.5,"unit":"公斤","ended":false,"daysLeft":7,"tone":"idle","pc\#
                t":0,"actual":0,"days":0,"neededPerDay":69.5,"reached":false,"prediction":{"kind":"none"},"headline"\#
                :"还没有记录"}},{"key":"2026-11-09","label":"11月9日–11月15日","range":{"from":"2026-11-09","to":"2026-11-15"\#
                },"target":69.5,"locked":false,"current":false,"progress":{"target":69.5,"unit":"公斤","ended":false,"\#
                daysLeft":7,"tone":"idle","pct":0,"actual":0,"days":0,"neededPerDay":69.5,"reached":false,"predictio\#
                n":{"kind":"none"},"headline":"还没有记录"}},{"key":"2026-11-16","label":"11月16日–11月22日","range":{"from":\#
                "2026-11-16","to":"2026-11-22"},"target":69.5,"locked":false,"current":false,"progress":{"target":69\#
                .5,"unit":"公斤","ended":false,"daysLeft":7,"tone":"idle","pct":0,"actual":0,"days":0,"neededPerDay":6\#
                9.5,"reached":false,"prediction":{"kind":"none"},"headline":"还没有记录"}},{"key":"2026-11-23","label":"1\#
                1月23日–11月29日","range":{"from":"2026-11-23","to":"2026-11-29"},"target":69.5,"locked":false,"current"\#
                :false,"progress":{"target":69.5,"unit":"公斤","ended":false,"daysLeft":7,"tone":"idle","pct":0,"actua\#
                l":0,"days":0,"neededPerDay":69.5,"reached":false,"prediction":{"kind":"none"},"headline":"还没有记录"}},\#
                {"key":"2026-11-30","label":"11月30日–12月6日","range":{"from":"2026-11-30","to":"2026-12-06"},"target":\#
                69.5,"locked":false,"current":false,"progress":{"target":69.5,"unit":"公斤","ended":false,"daysLeft":7\#
                ,"tone":"idle","pct":0,"actual":0,"days":0,"neededPerDay":69.5,"reached":false,"prediction":{"kind":\#
                "none"},"headline":"还没有记录"}},{"key":"2026-12-07","label":"12月7日–12月13日","range":{"from":"2026-12-07"\#
                ,"to":"2026-12-13"},"target":69.5,"locked":false,"current":false,"progress":{"target":69.5,"unit":"公\#
                斤","ended":false,"daysLeft":7,"tone":"idle","pct":0,"actual":0,"days":0,"neededPerDay":69.5,"reached\#
                ":false,"prediction":{"kind":"none"},"headline":"还没有记录"}},{"key":"2026-12-14","label":"12月14日–12月20日\#
                ","range":{"from":"2026-12-14","to":"2026-12-20"},"target":69.5,"locked":false,"current":false,"prog\#
                ress":{"target":69.5,"unit":"公斤","ended":false,"daysLeft":7,"tone":"idle","pct":0,"actual":0,"days":\#
                0,"neededPerDay":69.5,"reached":false,"prediction":{"kind":"none"},"headline":"还没有记录"}},{"key":"2026\#
                -12-21","label":"12月21日–12月27日","range":{"from":"2026-12-21","to":"2026-12-27"},"target":69.5,"locke\#
                d":false,"current":false,"progress":{"target":69.5,"unit":"公斤","ended":false,"daysLeft":7,"tone":"id\#
                le","pct":0,"actual":0,"days":0,"neededPerDay":69.5,"reached":false,"prediction":{"kind":"none"},"he\#
                adline":"还没有记录"}},{"key":"2026-12-28","label":"12月28日–12月30日","range":{"from":"2026-12-28","to":"202\#
                6-12-30"},"target":69.5,"locked":false,"current":false,"progress":{"target":69.5,"unit":"公斤","ended"\#
                :false,"daysLeft":3,"tone":"idle","pct":0,"actual":0,"days":0,"neededPerDay":69.5,"reached":false,"p\#
                rediction":{"kind":"none"},"headline":"还没有记录"}}],"prediction":"","page":{"card":{"id":9,"parentId":8\#
                ,"title":"体重降到 69.5 公斤","care":"health","kind":"quantity","calc":"avg","state":"behind","line":"还差 1\#
                .9 公斤","second":null,"ring":"24%","pct":0.24,"lagging":false,"asking":false,"paused":false,"streak":\#
                null,"closed":null,"why":null},"sub":"「三个月瘦 5 斤」的子目标 · 10月1日–12月30日","head":{"big":"71.4","bigUnit":\#
                " → 69.5 公斤","line":"还差 1.9 公斤","more":"比应达重 0.1 公斤 · 10月1日起轻了 0.6 公斤","nums":[]},"ask":null,"three"\#
                :null,"remind":null,"chart":{"kind":"curve","points":[{"label":"10月1日","value":72},{"label":"10月5日",\#
                "value":71.9},{"label":"10月12日","value":71.7},{"label":"10月19日","value":71.6},{"label":"10月26日","val\#
                ue":71.4}],"title":"10月1日 72 公斤，这周平均 71.4","sub":"每个点是一周的平均 · 目标 12月30日 69.5 公斤"},"chartTitle":"每周平均\#
                ","chartMeta":null,"best":null,"recent":[{"entryId":644,"day":"2026-10-27","text":"称了一下 71.4 公斤","wh\#
                en":"10月27日 早上","plus":""},{"entryId":542,"day":"2026-10-20","text":"体重 71.6 比上周少了一点","when":"10月20日\#
                 早上","plus":""},{"entryId":454,"day":"2026-10-13","text":"称了一下 71.7公斤","when":"10月13日 早上","plus":""}\#
                ,{"entryId":368,"day":"2026-10-06","text":"称了一下 71.9公斤","when":"10月6日 早上","plus":""},{"entryId":304,\#
                "day":"2026-10-01","text":"称了一下 72.0公斤","when":"10月1日 早上","plus":""}],"recentTotal":5,"days":null,"d\#
                aysNote":null,"mood":null,"milestones":null,"children":null,"said":null,"rest":null,"habit":null,"se\#
                ttings":{"title":"体重降到 69.5 公斤","target":{"value":69.5,"unit":"公斤"},"targetText":"69.5 公斤","category\#
                ":"健康","only":"名称里带「体重」的记录","period":"这个月","start":"10月1日","care":{"key":"health","name":"健康"},"remi\#
                nd":null,"rest":null}}}
                """#,
            "/api/goals/10": #"""
                {"title":"每周外卖不超过 2 次","kind":"quantity","period":"week","repeat":true,"start":"2026-10-01","end":nu\#
                ll,"calc":"count","direction":"lte","target":2,"unit":"次","binding":{"category":"diet","metric":"cou\#
                nt","keywords":["外卖"]},"id":10,"parentId":8,"status":"active","createdAt":"2026-10-01T11:30:00.000Z"\#
                ,"range":{"from":"2026-10-26","to":"2026-11-01"},"rangeLabel":"10月26日–11月1日","progress":{"target":2,\#
                "unit":"次","ended":false,"daysLeft":6,"tone":"good","pct":0.5,"actual":1,"expected":1,"reached":fals\#
                e,"prediction":{"kind":"not_enough"},"headline":"已用 1 / 2 次"},"prediction":"数据还不够，预测不了","page":{"car\#
                d":{"id":10,"parentId":8,"title":"每周外卖不超过 2 次","care":null,"kind":"quantity","calc":"count","state":\#
                "track","line":"这周还能 1 次","second":null,"ring":"50%","pct":0.5,"lagging":false,"asking":false,"pause\#
                d":false,"streak":null,"closed":null,"why":null},"sub":"「三个月瘦 5 斤」的子目标 · 每周","head":{"big":"1","bigU\#
                nit":" / 2 次 · 这周","line":"这周还能 1 次","more":"这周还剩 6 天","nums":[]},"ask":null,"three":null,"remind":n\#
                ull,"chart":{"kind":"weeks","rows":[{"label":"10月5日","value":2,"note":null,"current":false},{"label"\#
                :"10月12日","value":2,"note":null,"current":false},{"label":"10月19日","value":2,"note":null,"current":f\#
                alse},{"label":"10月26日","value":1,"note":"这周到今天","current":true}],"line":2,"lineLabel":"最多","format"\#
                :"count","unit":"次","money":false},"chartTitle":"每周几次","chartMeta":"按住拖动看每一周","best":null,"recent":[\#
                {"entryId":625,"day":"2026-10-26","text":"外卖点了沙拉 38 减肥","when":"10月26日 12:40","plus":"+1 次"},{"entry\#
                Id":570,"day":"2026-10-22","text":"外卖点了沙拉 38","when":"10月22日 12:40","plus":"+1 次"},{"entryId":545,"d\#
                ay":"2026-10-20","text":"外卖点了个黄焖鸡 32","when":"10月20日 12:40","plus":"+1 次"},{"entryId":482,"day":"202\#
                6-10-15","text":"外卖点了麻辣香锅 33","when":"10月15日 12:40","plus":"+1 次"},{"entryId":456,"day":"2026-10-13"\#
                ,"text":"点了个外卖 黄焖鸡 32","when":"10月13日 12:40","plus":"+1 次"},{"entryId":411,"day":"2026-10-09","text"\#
                :"外卖点了饺子 25","when":"10月9日 19:20","plus":"+1 次"},{"entryId":396,"day":"2026-10-08","text":"外卖点了沙拉 38\#
                ","when":"10月8日 12:40","plus":"+1 次"}],"recentTotal":7,"days":null,"daysNote":null,"mood":null,"mile\#
                stones":null,"children":null,"said":null,"rest":null,"habit":null,"settings":{"title":"每周外卖不超过 2 次",\#
                "target":{"value":2,"unit":"次"},"targetText":"2 次","category":"饮食","only":"名称里带「外卖」的记录","period":"每周\#
                ","start":"10月1日","care":null,"remind":null,"rest":null}}}
                """#,
            "/api/goals/11": #"""
                {"title":"每月外卖不超过 300 元","kind":"quantity","period":"month","repeat":true,"start":"2026-10-08","end"\#
                :null,"calc":"sum","direction":"lte","target":300,"unit":"元","binding":{"category":"diet","metric":"\#
                value","metricUnit":"元","keywords":["外卖"]},"id":11,"parentId":null,"status":"active","createdAt":"20\#
                26-10-08T14:40:00.000Z","range":{"from":"2026-10-08","to":"2026-10-31"},"rangeLabel":"10月8日–10月31日",\#
                "progress":{"target":300,"unit":"元","ended":false,"daysLeft":5,"tone":"good","pct":0.787,"actual":23\#
                6,"expected":250,"reached":false,"prediction":{"kind":"projected","value":285.684},"headline":"已用 23\#
                6 / 300 元"},"weekRows":[{"key":"2026-10-08","label":"10月8日–10月11日","range":{"from":"2026-10-08","to"\#
                :"2026-10-11"},"target":50,"locked":false,"current":false,"progress":{"target":50,"unit":"元","ended"\#
                :true,"daysLeft":0,"tone":"none","pct":1,"actual":63,"expected":50,"reached":false,"prediction":{"ki\#
                nd":"none"},"headline":"已超过上限 13 元"}},{"key":"2026-10-12","label":"10月12日–10月18日","range":{"from":"2\#
                026-10-12","to":"2026-10-18"},"target":87.5,"locked":false,"current":false,"progress":{"target":87.5\#
                ,"unit":"元","ended":true,"daysLeft":0,"tone":"good","pct":0.743,"actual":65,"expected":87.5,"reached\#
                ":true,"prediction":{"kind":"none"},"headline":"已用 65 / 87.5 元"}},{"key":"2026-10-19","label":"10月19\#
                日–10月25日","range":{"from":"2026-10-19","to":"2026-10-25"},"target":87.5,"locked":false,"current":fal\#
                se,"progress":{"target":87.5,"unit":"元","ended":true,"daysLeft":0,"tone":"good","pct":0.8,"actual":7\#
                0,"expected":87.5,"reached":true,"prediction":{"kind":"none"},"headline":"已用 70 / 87.5 元"}},{"key":"\#
                2026-10-26","label":"10月26日–10月31日","range":{"from":"2026-10-26","to":"2026-10-31"},"target":75,"loc\#
                ked":false,"current":true,"progress":{"target":75,"unit":"元","ended":false,"daysLeft":5,"tone":"bad"\#
                ,"pct":0.507,"actual":38,"expected":25,"reached":false,"prediction":{"kind":"not_enough"},"headline"\#
                :"已用 38 / 75 元"}}],"prediction":"按最近的速度，到期末大约 285.7 元","page":{"card":{"id":11,"parentId":null,"titl\#
                e":"每月外卖不超过 300 元","care":"money","kind":"quantity","calc":"sum","state":"track","line":"这个月还能花 ¥64"\#
                ,"second":null,"ring":"79%","pct":0.787,"lagging":false,"asking":false,"paused":false,"streak":null,\#
                "closed":null,"why":null},"sub":"钱 · 每月 · 10月8日–10月31日","head":{"big":"¥236","bigUnit":" / ¥300 已用",\#
                "line":"这个月还能花 ¥64","more":"还剩 5 天，每天能花 ¥12","nums":[]},"ask":null,"three":null,"remind":null,"chart\#
                ":{"kind":"weeks","rows":[{"label":"10月8日","value":63,"note":"10月8日–10月11日","current":false},{"label\#
                ":"10月12日","value":65,"note":null,"current":false},{"label":"10月19日","value":70,"note":null,"current\#
                ":false},{"label":"10月26日","value":38,"note":"这周到今天","current":true}],"line":88,"lineLabel":"平均每周能花"\#
                ,"format":"yuan","unit":"元","money":true},"chartTitle":"每周花了多少","chartMeta":"10月8日起 · 按住拖动","best":n\#
                ull,"recent":[{"entryId":625,"day":"2026-10-26","text":"外卖点了沙拉 38 减肥","when":"10月26日 12:40","plus":"\#
                ¥38"},{"entryId":570,"day":"2026-10-22","text":"外卖点了沙拉 38","when":"10月22日 12:40","plus":"¥38"},{"ent\#
                ryId":545,"day":"2026-10-20","text":"外卖点了个黄焖鸡 32","when":"10月20日 12:40","plus":"¥32"},{"entryId":482\#
                ,"day":"2026-10-15","text":"外卖点了麻辣香锅 33","when":"10月15日 12:40","plus":"¥33"},{"entryId":456,"day":"2\#
                026-10-13","text":"点了个外卖 黄焖鸡 32","when":"10月13日 12:40","plus":"¥32"},{"entryId":411,"day":"2026-10-0\#
                9","text":"外卖点了饺子 25","when":"10月9日 19:20","plus":"¥25"},{"entryId":396,"day":"2026-10-08","text":"外\#
                卖点了沙拉 38","when":"10月8日 12:40","plus":"¥38"}],"recentTotal":7,"days":null,"daysNote":null,"mood":nul\#
                l,"milestones":null,"children":null,"said":null,"rest":null,"habit":null,"settings":{"title":"每月外卖不超\#
                过 300 元","target":{"value":300,"unit":"元"},"targetText":"300 元","category":"饮食","only":"名称里带「外卖」的记录"\#
                ,"period":"每月","start":"10月8日","care":{"key":"money","name":"钱"},"remind":null,"rest":null}}}
                """#,
            "/api/goals/12": #"""
                {"milestones":[{"title":"第一部分 认知革命","doneAt":"2026-10-16"},{"title":"第二部分 农业革命","doneAt":"2026-10-25\#
                "},{"title":"第三部分 人类的融合统一"},{"title":"第四部分 科学革命"}],"ask":{"entryId":584,"question":"这句没说书名，算《人类简史》吗？\#
                ","text":"午休看了 40 页书","at":"10月23日 12:50","add":40,"unit":"页"},"title":"读完《人类简史》","kind":"completion\#
                ","period":"year","start":"2026-10-12","end":"2026-12-31","unit":"页","binding":{"category":"study","\#
                metric":"value","metricUnit":"页","keywords":["人类简史"]},"id":12,"parentId":null,"status":"active","cre\#
                atedAt":"2026-10-12T14:40:00.000Z","range":{"from":"2026-10-12","to":"2026-12-31"},"rangeLabel":"10月\#
                12日–12月31日","progress":{"tone":"idle","pct":0,"actual":0,"target":1,"unit":"","reached":false,"ended\#
                ":false,"daysLeft":0,"prediction":{"kind":"none"},"headline":"进行中"},"prediction":"","page":{"card":{\#
                "id":12,"parentId":null,"title":"读完《人类简史》","care":"growth","kind":"completion","calc":null,"state":"\#
                track","line":"看完两部分，到第 220 页","second":"在等你回答一句 ›","ring":"2/4","pct":0.5,"lagging":false,"asking":\#
                true,"paused":false,"streak":null,"closed":null,"why":null},"sub":"成长 · 10月12日–12月31日","head":{"big"\#
                :"2","bigUnit":" / 4 部分","line":"看完两部分，到第 220 页","more":null,"nums":[]},"ask":{"entryId":584,"questi\#
                on":"这句没说书名，算《人类简史》吗？","text":"午休看了 40 页书","at":"10月23日 12:50","add":40,"unit":"页"},"three":null,"re\#
                mind":null,"chart":null,"chartTitle":null,"chartMeta":null,"best":null,"recent":[{"entryId":609,"day\#
                ":"2026-10-25","text":"晚上看了 40 页人类简史 第二部分看完了","when":"10月25日 晚上","plus":"+40 页"},{"entryId":571,"day\#
                ":"2026-10-22","text":"睡前看了会儿人类简史 看到 180 页","when":"10月22日 晚上","plus":"+180 页"},{"entryId":498,"day"\#
                :"2026-10-16","text":"人类简史第一部分看完了","when":"10月16日 晚上","plus":""}],"recentTotal":3,"days":null,"daysN\#
                ote":null,"mood":null,"milestones":[{"title":"第一部分 认知革命","doneAt":"2026-10-16"},{"title":"第二部分 农业革命"\#
                ,"doneAt":"2026-10-25"},{"title":"第三部分 人类的融合统一"},{"title":"第四部分 科学革命"}],"children":null,"said":null,\#
                "rest":null,"habit":null,"settings":{"title":"读完《人类简史》","target":null,"targetText":"4 个里程碑","categor\#
                y":"学习","only":"名称里带「人类简史」的记录","period":"今年","start":"10月12日","care":{"key":"growth","name":"成长"},"r\#
                emind":null,"rest":null}}}
                """#,
            "/api/goals/4/grow": #"""
                {"title":"今年跑 500 公里","sub":"今年跑 500 公里 · 落后两周了","ask":"「今年跑 500 公里」这件事，现在还重要吗？","askSub":"落后两周了，不急着\#
                改数，先想想还要不要","facts":{"lead":"10 月你跑了 3 次，都在周末早上；工作日一次没跑。","more":"9 月刚开始的时候，工作日晚上跑了 4 次。","quotes":[\#
                {"text":"早上在小区跑了8.4公里 配速5分50","when":"10月24日 周六 早上 · 8.4 公里"},{"text":"早上跑了 6.9 公里 有点喘","when":"10月1\#
                8日 周日 早上 · 6.9 公里"},{"text":"早上在小区跑了 7 公里 下午带儿子游泳","when":"10月11日 周日 早上 · 7.2 公里"},{"text":"晚上跑了 14.\#
                4 公里 明天开始放假","when":"9月30日 周三 晚上 · 14.4 公里"},{"text":"下班跑了快 10 公里","when":"9月29日 周二 晚上 · 9.8 公里"},{"\#
                text":"早上跑了 15 公里 有点上头","when":"9月27日 周日 早上 · 15 公里"},{"text":"早上在小区跑了 12.5 公里","when":"9月26日 周六 早上 \#
                · 12.5 公里"},{"text":"晚上又跑了 8.2 公里 腿有点酸","when":"9月24日 周四 晚上 · 8.2 公里"},{"text":"下班跑了 10 公里 第一次跑这么远",\#
                "when":"9月23日 周三 晚上 · 10 公里"}]},"blockers":[{"text":"下班太累就不想动","source":{"text":"下班太累了 本来想跑步 还是算了","\#
                when":"10月23日"},"how":null},{"text":"周末也想多睡会儿","source":null,"how":null},{"text":"天黑得早，不想晚上出门","sour\#
                ce":null,"how":null}],"blockerFoot":"第一个是你 10月23日说的：「下班太累了 本来想跑步 还是算了」","options":[{"key":"down","ti\#
                tle":"降到 200 公里","how":"每周 13 公里：周三 3 公里，周六、周日各 5 公里","when":"照每周 13 公里，12月29日能到","cost":"目标小了一大截","\#
                target":200,"newTitle":"今年跑 200 公里","ifthen":"如果周六早上没安排，就先出门跑 5 公里","remind":{"kind":"time","text":"\#
                周六 08:00","at":"08:00","days":[5]},"line":"从 11月2日重新开始 · 照每周 13 公里，12月29日能到"},{"key":"weekend","titl\#
                e":"改成周末长跑","how":"每个周六、周日各跑 8 公里；目标改成 230 公里","when":"照周末各 8 公里，12月27日能到 230","cost":"工作日不再要求跑","ta\#
                rget":230,"newTitle":"今年跑 230 公里","ifthen":"如果周六早上没安排，就先出门跑 8 公里","remind":{"kind":"time","text":"周六\#
                 08:00","at":"08:00","days":[5]},"line":"周末长跑 · 12月27日能到"},{"key":"ifthen","title":"换个「如果就」，目标不变","h\#
                ow":"周末照旧；再加周二、周四早上各跑 3 公里，每周约 14 公里","when":"年底约 222 公里；500 公里要到明年 5 月","cost":"目标不变，还是落后，但每周多两次","\#
                ifthen":"如果周二、周四早上 7 点前醒了，就先在小区跑 3 公里","remind":{"kind":"time","text":"周二、周四 06:50","at":"06:50","da\#
                ys":[1,3]},"line":"换了个「如果就」"},{"key":"pause","title":"先停一个月","how":"到 11月27日；这期间不提醒、不算落后","when":"11\#
                月27日回来再定","cost":"这一个月不算进度","until":"2026-11-27","line":"暂停中 · 11月28日回来"}],"restart":{"on":"2026-11-\#
                02","text":"从下周一（11月2日）重新开始"},"letgoWhys":["最近工作太忙","换成游泳了","本来就定高了"]}
                """#,
            "/api/goals/4/woop": #"""
                {"title":"今年跑 500 公里","steps":[{"key":"why","q":"做到了，你最期待的是什么？","sub":null,"options":[{"text":"体检那几项\#
                回到正常","source":{"text":"体检报告出来了 血压有点高 体重也超了 医生让每天量血压","when":"10月1日"},"how":null},{"text":"明年跑一个半马",\#
                "source":{"text":"早上跑了 15 公里 有点上头","when":"9月27日"},"how":null},{"text":"陪儿子踢球不喘","source":{"text":"早\#
                上跑了 6.9 公里 有点喘","when":"10月18日"},"how":null}]},{"key":"obstacle","q":"你说过「下班太累就不想动」，是它吗？","sub":"只问你\#
                自己的，不问天气、加班","options":[{"text":"下班太累就不想动","source":{"text":"下班太累了 本来想跑步 还是算了","when":"10月23日"},"how\#
                ":null},{"text":"一忙起来就忘了","source":{"text":"这周忙疯了 什么都没顾上","when":"10月16日"},"how":null},{"text":"周末想多\#
                睡会儿","source":{"text":"12点40分睡的 8点40分醒 睡了8个小时","when":"10月25日"},"how":null}]},{"key":"plan","q":"遇到它\#
                的时候，你打算怎么做？","sub":null,"options":[{"text":"如果下班觉得累，就先换上跑鞋出门走 10 分钟","source":null,"how":"照着上一步「下班太累\#
                就不想动」写的"},{"text":"如果周六早上没安排，就先出门跑 5 公里","source":null,"how":"周末早上你跑了 5 次（什么时候最容易做到）"},{"text":"如果 7\#
                 点前醒了，就在小区跑 3 公里","source":null,"how":"10 月的 3 次都在早上"}]}],"remindQ":"要在下班的时候提醒你吗？","reminds":[{"kind\#
                ":"time","text":"每个工作日 18:30","at":"18:30","days":[0,1,2,3,4]},{"kind":"time","text":"周六 08:00","at"\#
                :"08:00","days":[5]},{"kind":"place","text":"到家的时候"}],"three":{"why":"体检那几项回到正常","obstacle":"下班太累就不想\#
                动","plan":"如果下班觉得累，就先换上跑鞋出门走 10 分钟"}}
                """#,
            "understand:我想每天喝 8 杯水": #"""
                {"kind":"plan","plan":{"title":"每天喝 8 杯水","type":"坚持","period":"每天","from":"从你说的「喝水」算，一天够 8 杯算做到","c\#
                ounted":"还没找到相关的记录，从今天开始算","quotes":[],"care":"health","op":{"kind":"quantity","title":"每天喝 8 杯水","p\#
                eriod":"week","repeat":true,"calc":"daily","direction":"gte","target":8,"unit":"杯","category":"diet"\#
                ,"metric":"value","metric_unit":"杯","keywords":["喝水"]}},"note":null,"positive":null}
                """#,
            "understand:我想多带儿子去游泳": #"""
                {"kind":"ask","question":"多久一次？","sub":null,"options":[{"text":"每天","say":"我想多带儿子去游泳 每天"},{"text":"每\#
                周 3 次","say":"我想多带儿子去游泳 每周 3 次"},{"text":"每月 4 次","say":"我想多带儿子去游泳 每月 4 次"}]}
                """#,
            "understand:少吃外卖": #"""
                {"kind":"dup","goal":{"id":10,"parentId":8,"title":"每周外卖不超过 2 次","care":null,"kind":"quantity","calc\#
                ":"count","state":"track","line":"这周还能 1 次","second":null,"ring":"50%","pct":0.5,"lagging":false,"as\#
                king":false,"paused":false,"streak":null,"closed":null,"why":null},"offer":{"value":1,"unit":"次","te\#
                xt":"改成每周 1 次"},"note":"这个已经有了：在「三个月瘦 5 斤」下面，这周还能 1 次。另外「每月外卖不超过 300 元」也在算。","positive":{"why":"换成「每\#
                周自己做饭 4 次」会更容易坚持，要一起加上吗？加一件事，比戒一件事更容易坚持。点不点都行","plan":{"title":"每周自己做饭 4 次","type":"坚持","period":"每周\#
                ","from":"从你说的「做饭」算","counted":"还没找到相关的记录，从今天开始算","quotes":[],"care":"health","op":{"kind":"quantity\#
                ","title":"每周自己做饭 4 次","period":"week","repeat":true,"calc":"count","direction":"gte","target":4,"un\#
                it":"次","category":"diet","metric":"count","keywords":["做饭","自己做"]}}}}
                """#,
            "understand:每天走 8000 步": #"""
                {"kind":"dup","goal":{"id":2,"parentId":null,"title":"每天走 8000 步","care":"health","kind":"quantity",\#
                "calc":"daily","state":"track","line":"30 天做到 26 天","second":"这周用了 1 次补假","ring":"26 天","pct":0.867,\#
                "lagging":false,"asking":false,"paused":false,"streak":{"weekly":false,"marks":["rest","rest","miss"\#
                ,"done","done","done","done","done","done","done","done","done","rest","today"],"habit":false},"clos\#
                ed":null,"why":null},"offer":null,"note":null,"positive":null}
                """#,
        ]
    }
#endif
