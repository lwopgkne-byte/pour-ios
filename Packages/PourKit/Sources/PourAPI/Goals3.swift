public import Foundation

// 3.0 目标（服务器 shared/src/goals3.ts、care.ts，2.15.0 起；docs/3.0/01-需求文档.md 第 9 章），字段名一字不差
extension API {
    /// 一个目标页头上一排数的一个（「到昨天应达 · 170 公里」）
    public struct GoalHeadNum: Codable, Hashable, Sendable {
        public var label: String
        public var value: String
    }

    /// 补假那张卡的一行（「10月14日 周三 · 6,200 步 · 用了补假」）
    public struct GoalRestLine: Codable, Hashable, Sendable {
        public var day: String
        public var text: String
    }

    public struct GoalSettingTarget: Codable, Hashable, Sendable {
        public var value: Double
        public var unit: String
    }

    public struct GoalSettingCare: Codable, Hashable, Sendable {
        public var key: String
        public var name: String
    }

    /// 每周回顾「下周最重要的一件」放进待办：内容、几点提醒
    public struct WeeklyTodo: Codable, Hashable, Sendable {
        public var content: String
        public var remindAt: String
    }

    /// 在乎和投入的一行
    public struct CareInvestRow: Codable, Hashable, Sendable, Identifiable {
        public var key: String
        public var name: String
        public var score: Int?
        public var value: String
        public var minutes: Int
        public var mine: Bool

        public var id: String { key }
    }

    /// 「如果就」的提醒：按时间（每个工作日 18:30）或地点（到家的时候）
    public struct GoalRemind: Codable, Hashable, Sendable {
        /// time、place
        public var kind: String
        public var text: String
        public var at: String?
        /// 哪几天（0 周一 … 6 周日）；不写是每天
        public var days: [Int]?
        /// 一句：「每个工作日 18:30 提醒你「如果就」」（目标页上有）
        public var line: String?
        /// 在设置 → 提醒和通知里关了：手机不排，目标页写「提醒关着」
        public var off: Bool?

        public init(kind: String, text: String, at: String? = nil, days: [Int]? = nil, off: Bool? = nil) {
            self.kind = kind
            self.text = text
            self.at = at
            self.days = days
            self.off = off
        }
    }

    /// 手机排的目标通知（GET /api/goals/reminders，01 9.10「提醒」）：「如果就」、每周回顾、先停一个月回来的前一天
    public struct GoalReminderList: Codable, Hashable, Sendable {
        /// 设了「如果就」提醒的一个目标（暂停的、关了的也列出来，手机不排）
        public struct IfThen: Codable, Hashable, Sendable, Identifiable {
            public var id: Int
            public var title: String
            /// 那句「如果……就……」（没写过是 nil）
            public var plan: String?
            public var remind: GoalRemind
            public var line: String
            public var paused: Bool
        }

        /// 每周回顾：周几（0 周一 … 6 周日）几点
        public struct Weekly: Codable, Hashable, Sendable {
            public var weekday: Int
            public var time: String
        }

        /// 先停一个月：回来的前一天晚上（at 是本地钟点「2026-11-27T20:00」）
        public struct Resume: Codable, Hashable, Sendable, Identifiable {
            public var id: Int
            public var title: String
            public var back: String
            public var at: String
            public var text: String
        }

        public var ifthen: [IfThen]
        public var weekly: Weekly?
        public var resume: [Resume]
    }

    /// 三句话：为什么想要 · 最可能拦住我的 · 如果……就……
    public struct GoalThree: Codable, Hashable, Sendable {
        public var why: String?
        public var obstacle: String?
        public var plan: String?

        public init(why: String? = nil, obstacle: String? = nil, plan: String? = nil) {
            self.why = why
            self.obstacle = obstacle
            self.plan = plan
        }
    }

    /// 在等你回答：AI 拿不准一条记录算不算
    public struct GoalAsk: Codable, Hashable, Sendable {
        public var entryId: Int
        public var question: String
        public var text: String
        public var at: String
        public var add: Double
        public var unit: String
    }

    public struct GoalMilestone: Codable, Hashable, Sendable {
        public var title: String
        public var doneAt: String?
    }

    /// 坚持的一行：最近 14 天的格子（done、rest、miss、today、paused、before）
    public struct StreakRow: Codable, Hashable, Sendable {
        public var weekly: Bool
        public var marks: [String]
        public var habit: Bool
    }

    /// 首页的一张卡（子目标的小卡、坚持的一行、做到的 · 放下的一行）
    public struct GoalCard: Codable, Hashable, Sendable, Identifiable {
        public var id: Int
        public var parentId: Int?
        public var title: String
        public var care: String?
        public var kind: String
        public var calc: String?
        /// track 正轨、behind 落后、new 刚定的、paused 暂停、done、letgo
        public var state: String
        public var line: String
        public var second: String?
        /// 环中间：「18%」「2/4」「1/2」；空心圈、浅灰是 nil
        public var ring: String?
        public var pct: Double
        public var lagging: Bool
        public var asking: Bool
        public var paused: Bool
        public var streak: StreakRow?
        /// 「9月23日做到」「10月12日放下」
        public var closed: String?
        public var why: String?
        /// 预算那一页：是哪个大目标的子目标
        public var parent: String?
    }

    /// 「我在乎的」一个胶囊
    public struct CareChip: Codable, Hashable, Sendable, Identifiable {
        public var key: String
        public var name: String
        public var icon: String
        public var count: Int
        public var pct: Double
        public var state: String

        public var id: String { key }
    }

    public struct GoalGroup: Codable, Hashable, Sendable {
        public var key: String?
        public var name: String
        public var icon: String
        public var cards: [GoalCard]
    }

    /// 目标首页（GET /api/goals/home）
    public struct GoalsHome: Codable, Hashable, Sendable {
        public struct Summary: Codable, Hashable, Sendable {
            public var lead: String
            public var lagId: Int?
            public var lagTitle: String?
        }

        public struct Weekly: Codable, Hashable, Sendable {
            public var from: String
            public var to: String
            public var text: String
        }

        public struct Suggestion: Codable, Hashable, Sendable {
            public var from: String
            public var title: String
        }

        public struct Empty: Codable, Hashable, Sendable {
            public var suggestions: [Suggestion]
            public var careAgreed: Bool
        }

        public var summary: Summary
        public var weekly: Weekly?
        public var care: [CareChip]
        public var groups: [GoalGroup]
        public var streaks: [GoalCard]
        public var done: [GoalCard]
        public var letgo: [GoalCard]
        /// 我的 → 预算：说过的「不超过」（含子目标）
        public var budgets: [GoalCard]?
        public var lagging: Int
        public var empty: Empty?
    }

    /// 一个目标的图：line 应达和实际 + 预测带；weeks 按周的柱子；curve 往下的小曲线；days 30 天的格子
    public struct GoalChart: Hashable, Sendable {
        public struct Row: Codable, Hashable, Sendable {
            public var label: String
            public var value: Double
            public var note: String?
            public var current: Bool
        }

        public struct Point: Codable, Hashable, Sendable {
            public var label: String
            public var value: Double
        }

        public struct Day: Codable, Hashable, Sendable {
            public var day: String
            public var mark: String
            public var value: Double
        }

        public struct Tick: Codable, Hashable, Sendable {
            public var at: Int
            public var text: String
        }

        public var kind: String
        // line
        public var from: String?
        public var length: Int?
        public var today: Int?
        public var target: Double?
        public var unit: String?
        public var actual: [Double]?
        public var expected: [Double]?
        public var slow: Double?
        public var fast: Double?
        public var ticks: [Tick]?
        // weeks
        public var rows: [Row]?
        public var line: Double?
        public var lineLabel: String?
        /// hm、yuan、count、num
        public var format: String?
        public var money: Bool?
        // curve
        public var points: [Point]?
        public var title: String?
        public var sub: String?
        // days
        public var cells: [Day]?
    }

    /// 什么时候最容易做到（七天 × 早中晚）
    public struct BestTimes: Codable, Hashable, Sendable {
        public struct Suggest: Codable, Hashable, Sendable {
            public var remind: GoalRemind
            public var label: String
        }

        public var grid: [[Int]]
        public var text: String
        public var suggest: Suggest?
        public var already: String?
    }

    public struct GoalQuote: Codable, Hashable, Sendable {
        public var text: String
        public var when: String
    }

    /// 一个目标的页（GET /api/goals/:id 的 page）
    public struct GoalPage: Codable, Hashable, Sendable {
        public struct Head: Codable, Hashable, Sendable {
            public var big: String
            public var bigUnit: String
            public var line: String
            public var more: String?
            public var nums: [GoalHeadNum]
        }

        public struct Recent: Codable, Hashable, Sendable, Identifiable {
            public var entryId: Int
            public var day: String?
            public var text: String
            public var when: String
            public var plus: String

            public var id: Int { entryId }
        }

        public struct DayRow: Codable, Hashable, Sendable, Identifiable {
            public var day: String
            public var label: String
            public var value: String
            public var mark: String

            public var id: String { day }
        }

        public struct Mood: Codable, Hashable, Sendable {
            public var moved: Int
            public var movedGood: Int
            public var other: Int
            public var otherGood: Int
            public var title: String
            public var foot: String?
        }

        public struct Rest: Codable, Hashable, Sendable {
            public var perWeek: Int
            public var lines: [GoalRestLine]
            public var habitLeft: String?
        }

        public struct Habit: Codable, Hashable, Sendable {
            public var quiet: Bool
        }

        public struct Settings: Codable, Hashable, Sendable {
            public var title: String
            public var target: GoalSettingTarget?
            public var targetText: String
            public var category: String?
            public var only: String?
            public var period: String
            public var start: String
            public var care: GoalSettingCare?
            public var remind: String?
            public var rest: Int?
        }

        public var card: GoalCard
        public var sub: String
        public var head: Head
        public var ask: GoalAsk?
        public var three: GoalThree?
        public var remind: GoalRemind?
        public var chart: GoalChart?
        public var chartTitle: String?
        public var chartMeta: String?
        public var best: BestTimes?
        public var recent: [Recent]
        public var recentTotal: Int
        public var days: [DayRow]?
        public var daysNote: String?
        public var mood: Mood?
        public var milestones: [GoalMilestone]?
        public var children: [GoalCard]?
        public var said: GoalQuote?
        public var rest: Rest?
        public var habit: Habit?
        public var settings: Settings
    }

    /// 目标详情里 3.0 的那一块（旧的字段照旧在 GoalDetail 里）
    struct GoalPageHolder: Decodable {
        let page: GoalPage
        let monthRows: [SubPeriod]?
    }

    /// 改了以后：轻提示那一句、撤销用的版本号
    public struct GoalDone: Codable, Hashable, Sendable {
        public var toast: String
        public var undo: [Int]
        public var finished: Bool?
    }
}
