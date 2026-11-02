// swift-format-ignore-file
#if DEBUG
    /// 3.0 目标的假服务器数据（第 4 份）：10月27日（原型那天）的演示数据，服务器 2.15.0 原样拿的（docs/3.0/01-需求文档.md 9.13）
    extension Goals3Stub {
        static let part4: [String: String] = [
            "understand:我今年想跑 1000 公里": #"""
                {"kind":"dup","goal":{"id":4,"parentId":null,"title":"今年跑 500 公里","care":"health","kind":"quantity",\#
                "calc":"sum","state":"behind","line":"比应达少 78 公里","second":"落后两周了，聊聊怎么调？","ring":"18%","pct":0.185,"\#
                lagging":true,"asking":false,"paused":false,"streak":null,"closed":null,"why":null},"offer":{"value"\#
                :1000,"unit":"公里","text":"你这次说的是 1000 公里，要把它改成 1000 公里吗？"},"note":null,"positive":null}
                """#,
            "understand:我想变健康": #"""
                {"kind":"vague","question":"最想先改变的是哪一点？","options":[{"text":"睡得更好","say":"我想睡得更好"},{"text":"动起来","sa\#
                y":"我想多动一动"},{"text":"吃得清淡","say":"我想吃得清淡点"},{"text":"瘦一点","say":"我想瘦一点"}]}
                """#,
            "understand:我想多动一动": #"""
                {"kind":"split","title":"变健康 · 先动起来","lead":"照你最近说的，拆成这几个：","children":[{"title":"每周运动 3 次","type":"\#
                坚持","period":"每周","from":"从你说的「运动」算","counted":"这周还没有；上周 4 次","quotes":[],"care":"health","op":{"kin\#
                d":"quantity","title":"每周运动 3 次","period":"week","repeat":true,"calc":"count","direction":"gte","tar\#
                get":3,"unit":"次","category":"exercise","metric":"count"}},{"title":"每周力量训练 1 次","type":"坚持","period\#
                ":"每周","from":"从你说的「力量」算","counted":"这周还没有；上周 1 次","quotes":[],"care":"health","op":{"kind":"quantit\#
                y","title":"每周力量训练 1 次","period":"week","repeat":true,"calc":"count","direction":"gte","target":1,"u\#
                nit":"次","category":"strength","metric":"count","keywords":["力量"]}}],"skipped":["「每天走 8000 步」已经有了，不重\#
                复建"]}
                """#,
            "understand:我想学吉他": #"""
                {"kind":"ask","question":"多久一次？","sub":null,"options":[{"text":"每天","say":"我想学吉他 每天"},{"text":"每周 3 \#
                次","say":"我想学吉他 每周 3 次"},{"text":"每月 4 次","say":"我想学吉他 每月 4 次"}]}
                """#,
            "understand:读完一本书": #"""
                {"kind":"ask","question":"读哪一本？","sub":"从你说过的话里找的书名","options":[{"text":"《置身事内》","say":"读完《置身事内》"},{\#
                "text":"《三体》","say":"读完《三体》"}]}
                """#,
        ]
    }
#endif
