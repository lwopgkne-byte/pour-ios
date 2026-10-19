public import Foundation
public import PourCore

/// 网页版画布、对话里的那些写法（shared 的 format.ts、tidy.ts、receipt.ts、mood.ts、categories.ts，
/// web 的 entry-display.ts 原样），用在网页版服务器给的数据上：和网页版一字不差
public enum Show {
    // MARK: - 时间、日子、钱

    /// 「2026-09-24T07:30」→「7:30」
    public static func clock(_ local: String) -> String {
        let time = local.dropFirst(11).prefix(5)
        return time.hasPrefix("0") ? String(time.dropFirst()) : String(time)
    }

    /// 60 →「60 分钟」，150 →「2 小时 30 分」，120 →「2 小时」
    public static func minutes(_ min: Int) -> String {
        if min < 120 { return "\(min) 分钟" }
        return min % 60 == 0 ? "\(min / 60) 小时" : "\(min / 60) 小时 \(min % 60) 分"
    }

    /// 「10月19日 周一」；不是今年的带上年份
    public static func dayTitle(_ day: String, today: String) -> String {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return day }
        let weekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        let year = day.prefix(4) == today.prefix(4) ? "" : "\(parts[0])年"
        return "\(year)\(parts[1])月\(parts[2])日 \(weekdays[PourDate.weekdayMon0(day)])"
    }

    /// 只有「今天」「昨天」
    public static func relative(_ day: String, today: String) -> String? {
        switch PourDate.diffDays(day, today) {
        case 0: "今天"
        case -1: "昨天"
        default: nil
        }
    }

    /// 对话里按天分隔
    public static func daySeparator(_ day: String, today: String) -> String {
        relative(day, today: today) ?? dayTitle(day, today: today)
    }

    /// ¥8,000 · ¥12.5
    public static func yuan(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return "¥\(formatter.string(from: NSNumber(value: value)) ?? String(value))"
    }

    public static func amount(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String((value * 100).rounded() / 100)
    }

    /// 中文和数字、英文挨着时中间留一点空（浏览器的 text-autospace）
    public static func spaced(_ text: String) -> String { WebText.spaced(text) }

    // MARK: - 类别

    public struct Meta: Hashable, Sendable {
        public let name: String
        public let emoji: String
        public let color: String
    }

    private static let builtIn: [String: Meta] = [
        "exercise": Meta(name: "运动", emoji: "🏃", color: "green"),
        "sleep": Meta(name: "睡眠", emoji: "😴", color: "purple"),
        "diet": Meta(name: "饮食", emoji: "🍽", color: "orange"),
        "study": Meta(name: "学习", emoji: "📚", color: "blue"),
        "work": Meta(name: "工作", emoji: "💼", color: "brown"),
        "other": Meta(name: "其他", emoji: "📌", color: "gray"),
        "insight": Meta(name: "感悟", emoji: "💡", color: "yellow"),
        "todo": Meta(name: "待办", emoji: "📝", color: "gray"),
        "mood": Meta(name: "心情", emoji: "💭", color: "pink"),
    ]

    /// 一个类别的名称、图标、颜色（categoryMeta）
    public static func meta(_ key: String, _ categories: [API.Category]) -> Meta {
        if let found = categories.first(where: { $0.key == key }) {
            return Meta(name: found.name, emoji: found.emoji, color: found.color)
        }
        return builtIn[key] ?? builtIn["other"] ?? Meta(name: "其他", emoji: "📌", color: "gray")
    }

    /// 顶级类别：子类别合在上级的卡片里
    public static func root(_ key: String, _ categories: [API.Category]) -> String {
        var current = key
        for _ in 0..<5 {
            guard let parent = categories.first(where: { $0.key == current })?.parent else { return current }
            current = parent
        }
        return current
    }

    // MARK: - 钱和数

    private static let moneyUnits = ["元", "块钱", "¥", "￥", "人民币", "rmb", "RMB"]
    private static let incomeNames = ["收入", "进账", "到账", "入账", "稿费", "工资", "薪水", "薪资", "奖金", "提成", "分红", "流水", "营业额"]
    private static let spendNames = ["花费", "花了", "花销", "消费", "支出", "开销", "人均", "费用", "价格", "价钱", "房租", "租金", "门票"]

    /// 这个数是不是钱（「块」是量词时不算）
    public static func isMoney(_ metric: API.Metric) -> Bool {
        let unit = metric.unit.trimmingCharacters(in: .whitespaces)
        if moneyUnits.contains(unit) { return true }
        guard unit == "块" else { return false }
        let name = metric.name
        return (incomeNames + spendNames + ["金额", "钱", "价", "账"]).contains { name.contains($0) } || name.hasSuffix("费")
    }

    /// 一个数怎么写：钱「菜 ¥860」，别的「5 公里」
    public static func metric(_ metric: API.Metric) -> String {
        if isMoney(metric) { return "\(metric.item.map { "\($0) " } ?? "")\(yuan(metric.value))" }
        return "\(amount(metric.value)) \(metric.unit)".trimmingCharacters(in: .whitespaces)
    }

    /// 几个数：不是钱的有两个以上时写上名字
    public static func metrics(_ list: [API.Metric]) -> [String] {
        let named = list.filter { !isMoney($0) }.count > 1
        return list.map { named && !isMoney($0) ? "\($0.name) \(metric($0))" : metric($0) }
    }

    /// 能报销、借出去的现在怎么样了
    static func flagNote(_ flag: String?, settled: Bool?) -> String? {
        switch flag {
        case "reimburse": settled == true ? "已报销" : "等报销"
        case "lend": settled == true ? "已还" : "借出去"
        default: nil
        }
    }

    /// 钱后面跟的几个字：「等报销」「给儿子」「每个月 1 日扣」「退了 ¥299」（名称里说了的不重复）
    public static func moneyNotes(_ list: [API.Metric], label: String, day: String? = nil) -> [String] {
        var out: [String] = []
        func add(_ note: String) { if !out.contains(note) { out.append(note) } }
        for item in list where isMoney(item) {
            if item.monthly == true, let day { add("每个月 \(Int(day.suffix(2)) ?? 1) 日扣") }
            let said =
                (item.flag == "lend" && label.contains("借")) || (item.flag == "reimburse" && label.contains("报销"))
            if let note = flagNote(item.flag, settled: item.settled), item.settled == true || !said { add(note) }
            if let who = item.forWhom?.trimmingCharacters(in: .whitespaces), !who.isEmpty, who != "自己", who != "一家人",
                !label.contains(who)
            {
                add("给\(who)")
            }
            if item.name == "收入", let from = item.from?.trimmingCharacters(in: .whitespaces), !from.isEmpty,
                !label.contains(from)
            {
                add("\(from)给的")
            }
            if let back = item.returned { add("\(back.why == "refund" ? "退了" : "AA 转回") \(yuan(back.amount))") }
        }
        return out
    }

    /// 「和谁」要写的人：名称里有的、钱后面写了「给某某」的不重复
    public static func peopleToShow(_ event: API.EventData) -> [String] {
        let notes = moneyNotes(event.metrics ?? [], label: event.label)
        let given = Set(notes.filter { $0.hasPrefix("给") }.map { String($0.dropFirst()) })
        return (event.people ?? []).filter { !event.label.contains($0) && !given.contains($0) }
    }

    /// 事件的次要信息：「8:00–9:00 · 60 分钟 · 8 公里 · 在公园 · 和小王」
    public static func eventMeta(_ event: API.EventData, day: String) -> String {
        var parts: [String] = []
        if let start = event.start, let end = event.end {
            parts.append("\(clock(start))–\(clock(end))")
        } else if let start = event.start {
            parts.append("\(clock(start)) 开始")
        } else if let end = event.end {
            parts.append("\(clock(end)) 结束")
        }
        if let duration = event.durationMin { parts.append(minutes(duration)) }
        parts += metrics(event.metrics ?? []) + moneyNotes(event.metrics ?? [], label: event.label, day: day)
        let places = (event.places ?? []).filter { !event.label.contains($0) }
        if !places.isEmpty { parts.append("在\(places.joined(separator: "、"))") }
        let people = peopleToShow(event)
        if !people.isEmpty { parts.append("和\(people.joined(separator: "、"))") }
        return parts.joined(separator: " · ")
    }

    /// 一行最多一个话题：和名称、类别、人、物、地方、数量名重复的不算（cleanTopics）
    public static func topic(_ event: API.EventData, category: String, _ categories: [API.Category]) -> String? {
        let squash = { (text: String) in
            text.replacingOccurrences(of: "#", with: "").replacingOccurrences(of: " ", with: "")
        }
        let names = [meta(category, categories).name, meta(root(category, categories), categories).name]
        let refs =
            ([event.label] + names + (event.people ?? []) + (event.things ?? []) + (event.places ?? [])
            + (event.metrics ?? []).map(\.name)).map(squash).filter { !$0.isEmpty }
        return (event.tags ?? []).map(squash).first { tag in !tag.isEmpty && !refs.contains { $0.contains(tag) } }
    }

    /// 一组事件花了多少、收入多少（回来的钱、收到的人情不算收入）
    public static func money(_ events: [API.EventData]) -> (spent: Double, earned: Double) {
        let back = ["报销", "退款", "退钱", "退回", "还钱", "还了", "还我", "AA", "aa", "平摊", "分摊"]
        var spent = 0.0
        var earned = 0.0
        for event in events {
            for item in event.metrics ?? [] where item.unit == "元" {
                if item.name == "花费" {
                    spent += max(0, item.value - (item.returned?.amount ?? 0))
                } else if item.name == "收入" {
                    let isBack =
                        ["repay", "reimbursed", "refund"].contains(item.flag ?? "")
                        || back.contains { "\(item.item ?? "")\(event.label)".contains($0) }
                    if !isBack && !(event.renqing != nil && item.flag == nil) { earned += item.value }
                }
            }
        }
        return ((spent * 100).rounded() / 100, (earned * 100).rounded() / 100)
    }

    /// 卡片标题旁的数字（groupHeadline）：时长、「N 次」、同单位加起来；后面接「花了 ¥160」「收入 ¥8,000」
    public static func headline(_ events: [API.EventData], measure: String) -> String? {
        let total = events.reduce(0) { $0 + ($1.durationMin ?? 0) }
        var parts: [String] = []
        if measure == "count" {
            if events.count >= 2 { parts.append("\(events.count) 次") }
        } else if measure != "duration" {
            let values = events.flatMap { ($0.metrics ?? []).filter { $0.unit == measure }.map(\.value) }
            if !values.isEmpty {
                parts.append("\(amount(values.reduce(0, +))) \(measure)")
            } else if total > 0 {
                parts.append(minutes(total))
            }
        } else if total > 0 {
            parts.append(minutes(total))
        }
        let (spent, earned) = money(events)
        if spent > 0 { parts.append("花了 \(yuan(spent))") }
        if earned > 0 { parts.append("收入 \(yuan(earned))") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - 心情

    public static let moodWords = ["很差", "不太好", "一般", "挺好", "很好"]
    public static let energyWords = ["很累", "有点累", "一般", "有精神", "精力充沛"]

    public static func moodWord(_ level: Double) -> String { moodWords[min(5, max(1, Int(level.rounded()))) - 1] }
    public static func energyWord(_ level: Double) -> String { energyWords[min(5, max(1, Int(level.rounded()))) - 1] }

    /// 一天几条心情：既有好的又有不好的是「有起有落」，否则是平均的那一级
    public static func dayMood(_ levels: [Double]) -> String? {
        guard !levels.isEmpty else { return nil }
        if levels.contains(where: { $0 >= 4 }) && levels.contains(where: { $0 <= 2 }) { return "有起有落" }
        return moodWord(levels.reduce(0, +) / Double(levels.count))
    }

    // MARK: - 卡片分组

    /// 卡片分组：事件按顶级类别，其余按种类
    public static func group(_ entry: API.Entry, _ categories: [API.Category]) -> String {
        entry.kind == "event" ? root(entry.category, categories) : entry.kind
    }

    /// 卡片顺序：还有没做完的待办时待办最前；其余按类别表的顺序，感悟、做完的待办、心情放最后
    public static func sortGroups(_ groups: [String], _ categories: [API.Category], openTodos: Bool) -> [String] {
        let tail = ["insight", "todo", "mood"]
        func rank(_ group: String) -> Int {
            if group == "todo" && openTodos { return -1 }
            if let index = tail.firstIndex(of: group) { return 1000 + index }
            return categories.firstIndex { $0.key == group } ?? 999
        }
        return groups.sorted { rank($0) < rank($1) }
    }
}
