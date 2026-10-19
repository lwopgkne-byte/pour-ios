import Foundation

// 设置页的数据（网页版 lib/queries.ts 的 LlmStatus、ReminderStatus、LanInfo、Growth、AuditStatus，
// pages/EvalSettings.tsx、DataSettings.tsx 里的类型），字段名一字不差
extension API {
    /// 大模型：用哪个模型、密钥（只有打码的）、本月用量、排队
    public struct LlmStatus: Codable, Hashable, Sendable {
        public struct Usage: Codable, Hashable, Sendable {
            public var month: String
            public var calls: Int
            public var promptTokens: Int
            public var cacheHitTokens: Int
            public var totalTokens: Int
            /// 按官方价格估算的本月花费（人民币）
            public var costCny: Double
            public var costPartial: Bool
            public var byFeature: [FeatureUsage]
        }

        public struct FeatureUsage: Codable, Hashable, Sendable {
            public var feature: String
            public var calls: Int
            public var totalTokens: Int
            public var costCny: Double
        }

        public struct Queue: Codable, Hashable, Sendable {
            public var pending: Int
            public var blocker: String?
        }

        public var baseUrl: String
        public var model: String
        /// settings 设置页选的、env 来自 .env、default 默认
        public var modelSource: String
        /// env、settings；还没有是 nil
        public var keySource: String?
        public var keyMasked: String?
        public var configured: Bool
        public var consentAccepted: Bool
        public var confidenceThreshold: Double
        public var monthlyTokenLimit: Int
        public var usage: Usage
        public var queue: Queue
        /// 在电脑上打开的（手机上永远是 false：密钥、PIN 只能在电脑上改）
        public var local: Bool
    }

    /// 提醒和推送
    public struct ReminderStatus: Codable, Hashable, Sendable {
        public struct Timed: Codable, Hashable, Sendable {
            public var enabled: Bool
            public var time: String
        }

        public struct Toggle: Codable, Hashable, Sendable {
            public var enabled: Bool
        }

        public struct Channels: Codable, Hashable, Sendable {
            public var serverchan: Bool
            public var bark: Bool
        }

        /// 推送密钥，只有打码的
        public struct Keys: Codable, Hashable, Sendable {
            public var serverchan: String?
            public var bark: String?
        }

        public var morning: Timed
        public var evening: Timed
        public var warning: Timed
        public var weekly: Toggle
        public var monthly: Toggle
        public var dnd: QuietHours
        public var bedtime: String?
        public var channels: Channels
        public var keys: Keys
    }

    /// 免打扰时段：「23:00」到「07:00」
    public struct QuietHours: Codable, Hashable, Sendable {
        public var enabled: Bool
        public var from: String
        public var to: String
    }

    /// 局域网访问
    public struct LanInfo: Codable, Hashable, Sendable {
        public var local: Bool
        public var pinEnabled: Bool
        public var pinUnset: Bool
        public var urls: [String]
        public var rememberDays: Int
    }

    /// 越来越懂你：每周要你改几次、追问几次，记住了多少说法
    public struct Growth: Codable, Hashable, Sendable {
        public struct Week: Codable, Hashable, Sendable {
            public var start: String
            public var notes: Int
            public var corrections: Int
            public var asks: Int
        }

        public struct Learned: Codable, Hashable, Sendable {
            public var total: Int
            public var thisWeek: Int
        }

        public struct AboutMarks: Codable, Hashable, Sendable {
            public var right: Int
            public var wrong: Int
        }

        public struct Checklist: Codable, Hashable, Sendable {
            public var general: Int
            public var personal: Int
        }

        public struct Knows: Codable, Hashable, Sendable {
            public var people: Int
            public var habits: Int
            public var places: Int
        }

        public var weeks: [Week]
        public var dictionary: Learned
        public var about: AboutMarks
        public var checklist: Checklist?
        public var knows: Knows
    }

    /// 自动检查（夜里用更强的模型复查前一天的整理）
    public struct AuditStatus: Codable, Hashable, Sendable {
        public struct Exam: Codable, Hashable, Sendable {
            public var at: String
            public var caught: Int
            public var wrongTotal: Int
            public var falseAlarms: Int
            public var rightTotal: Int
            public var passed: Bool
            public var current: Bool
        }

        public struct Week: Codable, Hashable, Sendable {
            public var found: Int
            public var confirmed: Int
        }

        public struct Decided: Codable, Hashable, Sendable {
            public var confirmed: Int
            public var dismissed: Int
        }

        public struct LastRun: Codable, Hashable, Sendable {
            public var day: String
            /// done、empty、budget 这个月的钱用完了、exam、failed
            public var outcome: String
            public var detail: String?
        }

        public var model: String
        public var capCny: Double
        public var monthCostCny: Double
        public var exam: Exam?
        public var examRunning: Bool
        public var week: Week
        public var decided: Decided
        public var lastRun: LastRun?
    }

    /// 评测（AI 准不准）：最近几次的结果和正在跑的进度
    public struct Evals: Codable, Hashable, Sendable {
        public struct Run: Codable, Hashable, Sendable {
            public var file: String
            public var at: String
            public var model: String
            public var overall: Double
            public var cases: Int
            public var costCny: Double?
            public var summary: [String: Dimension]
            public var scopes: Scopes?
            public var failures: [Failure]
        }

        public struct Dimension: Codable, Hashable, Sendable {
            public var rate: Double
            public var checks: Int
        }

        /// 通用的和你个人的分开算（旧的结果没有）
        public struct Scopes: Codable, Hashable, Sendable {
            public var general: ScopeRate
            public var personal: ScopeRate
        }

        public struct ScopeRate: Codable, Hashable, Sendable {
            public var rate: Double
            public var cases: Int
        }

        public struct Failure: Codable, Hashable, Sendable {
            public var id: String
            public var text: String
            public var problems: [Problem]
        }

        public struct Problem: Codable, Hashable, Sendable {
            public var dim: String
            public var what: String
        }

        public struct Progress: Codable, Hashable, Sendable {
            public var running: Bool
            public var done: Int
            public var total: Int?
            public var error: String?
        }

        public var runs: [Run]
        public var progress: Progress
    }

    /// 你改过的地方（评测候选）：只数有几条
    public struct Candidates: Codable, Hashable, Sendable {
        public struct Item: Codable, Hashable, Sendable {
            public var id: Int
            public var text: String
        }

        public var candidates: [Item]
        public var classifying: Bool
    }

    /// 数据：真实还是演示、自动备份、日界线
    public struct DataStatus: Codable, Hashable, Sendable {
        public struct Backup: Codable, Hashable, Sendable {
            public var name: String
            public var size: Int
            public var at: String
        }

        public var mode: String
        public var backups: [Backup]
        public var backupCount: Int
        public var dayBoundary: Int
        public var notes: Int
    }

    /// 重新解析之前的估算
    public struct ReparseEstimate: Codable, Hashable, Sendable {
        public var notes: Int
        public var tokens: Int
        public var cny: Double
        public var model: String
    }

    /// 类别的整理建议：merge 合并两个、rare 很少用的删掉、tidy-other「其他」里的重新归类
    public struct CategorySuggestion: Codable, Hashable, Sendable {
        public var kind: String
        public var keys: [String]
        public var text: String
    }

    /// 测试连接、测试推送的结果
    public struct TestResult: Codable, Hashable, Sendable {
        public var ok: Bool
        public var message: String
    }

    struct PushTest: Decodable {
        let results: [PushResult]
    }

    /// 「试一下」：发出了一条（在对话里），或者说为什么没发
    public struct TryResult: Codable, Hashable, Sendable {
        public var message: SystemMessage?
        public var skipped: String?
    }
}
