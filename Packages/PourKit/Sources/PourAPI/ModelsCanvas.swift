// 产品优化（docs/模块/产品优化.md）加的几样：我的卡片、我的语录、名字表

extension API {
    /// 一眼（桌面小组件、锁屏，docs/模块/产品优化.md R7）：服务器挑好的今天还没做的待办、下一件提醒、今天那句「你说过」
    public struct Glance: Codable, Hashable, Sendable {
        public struct Todo: Codable, Hashable, Sendable, Identifiable {
            public var id: Int
            public var content: String
            /// 几点提醒（「19:00」）
            public var remindAt: String?
            /// 以前该做、还没做的
            public var overdue: Bool

            public init(id: Int, content: String, remindAt: String?, overdue: Bool) {
                self.id = id
                self.content = content
                self.remindAt = remindAt
                self.overdue = overdue
            }
        }

        public struct Quote: Codable, Hashable, Sendable {
            public var text: String
            public var day: String
            public var asked: Bool

            public init(text: String, day: String, asked: Bool) {
                self.text = text
                self.day = day
                self.asked = asked
            }
        }

        public var today: String
        public var open: [Todo]
        public var done: Int
        public var total: Int
        public var next: Todo?
        public var quote: Quote?

        public init(today: String, open: [Todo], done: Int, total: Int, next: Todo?, quote: Quote?) {
            self.today = today
            self.open = open
            self.done = done
            self.total = total
            self.next = next
            self.quote = quote
        }
    }

    /// 输入 PIN 配对的回复（设备登录，docs/模块/产品优化.md R8）：新服务器给这台设备一把钥匙；旧服务器只有 ok
    public struct Pairing: Codable, Hashable, Sendable {
        public struct Device: Codable, Hashable, Sendable {
            public var id: Int
            public var name: String
        }

        public var ok: Bool
        public var token: String?
        public var device: Device?
    }

    /// 画布上的一张「我的卡片」（docs/模块/产品优化.md R3）：服务器按查询条件现算，手机只管画
    public struct CardView: Codable, Hashable, Sendable, Identifiable {
        public struct Item: Codable, Hashable, Sendable {
            public var text: String
            public var day: String
            public var entryId: Int
        }

        public struct Bar: Codable, Hashable, Sendable {
            public var label: String
            public var value: Double
        }

        public var id: Int
        public var title: String
        /// number 一个数 · list 一张清单 · chart 一张小图
        public var show: String
        /// 怎么查的：「今年 · 读书 · 说到的东西」
        public var basis: String
        public var value: String?
        public var items: [Item]?
        public var more: Int?
        public var bars: [Bar]?
        /// 还没说到：卡片照样在，hint 写怎么说才会有
        public var empty: Bool
        public var hint: String?
    }

    /// 我的语录的一句（docs/模块/产品优化.md R4）：用户说「记一句」的，和感悟里原话的那一句
    public struct MyQuote: Codable, Hashable, Sendable, Identifiable {
        public var entryId: Int
        public var text: String
        public var day: String
        public var noteId: Int?
        /// 用户说「记一句」让记的
        public var asked: Bool

        public var id: Int { entryId }
    }

    public struct MyQuotes: Codable, Hashable, Sendable {
        public var quotes: [MyQuote]
    }

    /// 名字表的一条（docs/模块/产品优化.md R2）：「说到的」里改过的名字、不再显示的
    public struct NameRule: Codable, Hashable, Sendable, Identifiable {
        /// person · thing · place · tag
        public var kind: String
        public var name: String
        /// 改成的名字；只藏不改是 nil
        public var canonical: String?
        public var hidden: Bool
        public var updatedAt: String

        public var id: String { "\(kind)|\(name)" }

        public init(kind: String, name: String, canonical: String?, hidden: Bool, updatedAt: String) {
            self.kind = kind
            self.name = name
            self.canonical = canonical
            self.hidden = hidden
            self.updatedAt = updatedAt
        }
    }

    public struct NameRules: Codable, Hashable, Sendable {
        public var rules: [NameRule]
    }
}
