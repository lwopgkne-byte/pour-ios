public import Foundation

// 钱（shared money.ts、money-watch.ts、money-worth.ts、money-days.ts、renqing.ts），字段名一字不差
extension API {
    /// 一笔钱属于生活里的哪一块（顶级类别）
    public struct MoneyDomainRef: Codable, Hashable, Sendable {
        public var key: String
        public var name: String
        public var color: String
    }

    /// 整理好的一笔钱
    public struct MoneyItem: Codable, Hashable, Sendable {
        public var entryId: Int
        /// 这一笔是记录里的第几个数：标记已报销、不再算固定的时改的就是它
        public var index: Int
        public var day: String
        public var time: String?
        public var name: String
        public var amount: Double
        /// daily、fixed、reimburse、lend、income、back、gift
        public var kind: String
        public var domain: MoneyDomainRef
        /// 给谁花的：「儿子」「一家人」「自己」；收到的人情是谁给的
        public var who: String
        public var verdict: Verdict?
        public var settled: Bool?
        public var flag: String?
        public var label: String
        public var pack: Double?
        public var ended: Bool?
        public var monthly: Bool?
        public var renqing: Renqing?
        public var returned: Metric.Returned?
        public var people: [String]?
    }

    public struct MoneyDomain: Codable, Hashable, Sendable {
        public var key: String
        public var name: String
        public var color: String
        public var amount: Double
        public var count: Int
    }

    public struct MoneyCompare: Codable, Hashable, Sendable {
        public var prevSpent: Double
        public var diff: Double
        public var text: String
    }

    public struct MoneySpentDay: Codable, Hashable, Sendable {
        public var day: String
        public var spent: Double
        public var count: Int
    }

    public struct FixedSeries: Codable, Hashable, Sendable {
        public var name: String
        public var dayOfMonth: Int
        public var amount: Double
        public var lastDay: String
        public var ended: Bool?
    }

    public struct MoneyFixed: Codable, Hashable, Sendable {
        public var paid: Double
        public var paidCount: Int
        public var upcoming: Double
        public var monthly: Double
        public var series: [FixedSeries]
    }

    public struct MoneyIncome: Codable, Hashable, Sendable {
        public struct Item: Codable, Hashable, Sendable {
            public var day: String
            public var name: String
            public var amount: Double
            public var entryId: Int
        }

        public var total: Double
        public var items: [Item]
    }

    public struct MoneyEarly: Codable, Hashable, Sendable {
        public var days: Int
        public var daily: Int
    }

    /// 「钱」一个月：数字全部是服务器现算的
    public struct MoneyMonth: Codable, Hashable, Sendable {
        public var month: String
        public var today: String
        public var current: Bool
        /// 第一次说话的那天；还没说过话是 nil
        public var started: String?
        /// 日常花的
        public var spent: Double
        public var count: Int
        public var todaySpent: Double?
        public var days: [MoneySpentDay]
        public var compare: MoneyCompare?
        public var compareFrom: String?
        public var fixed: MoneyFixed
        public var income: MoneyIncome
        public var domains: [MoneyDomain]
        public var domainNote: String?
        /// 这个月的每一笔（新的在前）
        public var items: [MoneyItem]
        /// 每一种几笔（没有的种类不在里面）
        public var counts: [String: Int]
        public var early: MoneyEarly?
        public var prevMonth: String?
        public var nextMonth: String?
    }

    /// 一天的钱
    public struct MoneyDayPage: Codable, Hashable, Sendable {
        public struct Note: Codable, Hashable, Sendable {
            public var time: String
            public var text: String
        }

        public var day: String
        public var items: [MoneyItem]
        public var spent: Double
        public var count: Int
        public var people: [String]
        public var feelings: [String]
        public var notes: [Note]
        public var prev: String?
        public var next: String?
    }

    /// 主页「留意」的一条
    public struct WatchLine: Codable, Hashable, Sendable {
        /// reimburse、lend、fixed、unused
        public var kind: String
        public var name: String
        public var amount: Double
        public var sub: String
        public var entryId: Int?
    }

    public struct MoneyWhoRow: Codable, Hashable, Sendable {
        public var name: String
        public var amount: Double
        public var strong: Bool
    }

    /// 花给了谁
    public struct MoneyWho: Codable, Hashable, Sendable {
        public struct Family: Codable, Hashable, Sendable {
            public var amount: Double
            public var share: String
        }

        public var from: String
        public var total: Double
        public var family: Family?
        public var people: [MoneyWhoRow]
        public var sentence: String?
    }

    /// 说到用它的一次
    public struct ThingUse: Codable, Hashable, Sendable {
        public var day: String
        public var entryId: Int
        public var label: String
        /// 「一样东西的那一页」才有：你怎么说的
        public var text: String?
    }

    /// 值不值里的一样东西
    public struct MoneyThing: Codable, Hashable, Sendable {
        public var entryId: Int
        public var day: String
        public var name: String
        public var amount: Double
        public var who: String
        public var verdict: Verdict?
        /// 是东西（每次多少钱 = 价钱 ÷ 用了几次）；出去玩这类不除
        public var durable: Bool
        public var uses: [ThingUse]
        public var perUse: Double?
        public var sub: String
    }

    public struct MoneyWorth: Codable, Hashable, Sendable {
        public var good: [MoneyThing]
        public var regret: [MoneyThing]
    }

    public struct RenqingBrief: Codable, Hashable, Sendable {
        public var out: Double
        public var into: Double
        public var times: Int

        enum CodingKeys: String, CodingKey {
            case out, times
            case into = "in"
        }
    }

    /// 「钱」主页下面几块（这个月才有）
    public struct MoneyOverview: Codable, Hashable, Sendable {
        public var watch: [WatchLine]
        public var who: MoneyWho?
        public var whoCount: Int
        public var worth: MoneyWorth
        public var renqing: RenqingBrief?
    }

    /// 一条发现（「钱和你的日子」「关于我」的新发现）
    public struct FindingView: Codable, Hashable, Sendable {
        public struct Bar: Codable, Hashable, Sendable {
            public var label: String
            public var value: String
            public var share: Double
            public var strong: Bool
        }

        public struct Day: Codable, Hashable, Sendable {
            public var day: String
            public var text: String
        }

        public var key: String
        public var sentence: String
        public var bars: [Bar]
        public var sub: String
        /// good、bad；没写是要留意的
        public var tone: String?
        public var days: [Day]
        /// right、known、boring、wrong
        public var vote: String?
    }

    public struct MoneyFindingsPage: Codable, Hashable, Sendable {
        public var recorded: Int
        public var early: Bool
        public var findings: [FindingView]
    }
}
