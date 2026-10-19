public import Foundation

/// 网页版画布和对话里的那些写法（shared/src/format.ts、tidy.ts、receipt.ts、mood.ts、web 的 entry-display.ts 原样）：
/// 照网页版 1 比 1 做的界面用它，同一件事和网页版一字不差
public enum WebText {
    /// 「2026-09-24T07:30」→「7:30」（去掉前导零更口语）
    public static func clock(_ local: LocalDateTime) -> String {
        let time = local.dropFirst(11).prefix(5)
        return time.hasPrefix("0") ? String(time.dropFirst()) : String(time)
    }

    /// 60 →「60 分钟」，150 →「2 小时 30 分」，120 →「2 小时」
    public static func minutes(_ min: Int) -> String {
        if min < 120 { return "\(min) 分钟" }
        let hours = min / 60
        let rest = min % 60
        return rest == 0 ? "\(hours) 小时" : "\(hours) 小时 \(rest) 分"
    }

    /// 「10月19日 周一」；不是今年的带上年份
    public static func dayTitle(_ day: DayString, today: DayString) -> String {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return day }
        let weekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        let year = day.prefix(4) == today.prefix(4) ? "" : "\(parts[0])年"
        return "\(year)\(parts[1])月\(parts[2])日 \(weekdays[PourDate.weekdayMon0(day)])"
    }

    /// 相对于今天的称呼：只有「今天」「昨天」
    public static func relative(_ day: DayString, today: DayString) -> String? {
        switch PourDate.diffDays(day, today) {
        case 0: return "今天"
        case -1: return "昨天"
        default: return nil
        }
    }

    /// 对话里按天分隔：「今天」「昨天」或「9月22日 周二」
    public static func daySeparator(_ day: DayString, today: DayString) -> String {
        relative(day, today: today) ?? dayTitle(day, today: today)
    }

    /// ¥8,000 · ¥12.5（千位分隔，最多两位小数）
    public static func yuan(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return "¥\(formatter.string(from: NSNumber(value: value)) ?? String(value))"
    }

    static func amount(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String((value * 100).rounded() / 100)
    }

    static func isMoney(_ metric: Metric) -> Bool { metric.unit == "元" }

    /// 一个数怎么写：钱「菜 ¥860」，别的「5 公里」
    public static func metric(_ metric: Metric) -> String {
        if isMoney(metric) { return "\(metric.item.map { "\($0) " } ?? "")\(yuan(metric.value))" }
        return "\(amount(metric.value)) \(metric.unit)".trimmingCharacters(in: .whitespaces)
    }

    /// 几个数怎么写：不是钱的数有两个以上时写上名字（「卧推 80 公斤」），只有一个时不啰嗦
    public static func metrics(_ list: [Metric]) -> [String] {
        let named = list.filter { !isMoney($0) }.count > 1
        return list.map { named && !isMoney($0) ? "\($0.name) \(metric($0))" : metric($0) }
    }

    /// 钱后面跟的几个字：「给儿子」「妈妈给的」（名称里说了的不重复；给自己、一家人的不写）
    public static func moneyNotes(_ list: [Metric], label: String) -> [String] {
        var out: [String] = []
        for item in list where isMoney(item) {
            if let who = item.forWhom?.trimmingCharacters(in: .whitespaces), !who.isEmpty, who != "自己",
                who != "一家人", !label.contains(who), !out.contains("给\(who)")
            {
                out.append("给\(who)")
            }
            if item.name == "收入", let from = item.from?.trimmingCharacters(in: .whitespaces), !from.isEmpty,
                !label.contains(from), !out.contains("\(from)给的")
            {
                out.append("\(from)给的")
            }
        }
        return out
    }

    /// 「和谁」要写的人：名称里已经有的、钱后面已经写了「给某某」的不重复
    public static func peopleToShow(_ event: RecordData.Event) -> [String] {
        let given = Set(
            moneyNotes(event.metrics, label: event.label).filter { $0.hasPrefix("给") }.map { String($0.dropFirst()) })
        return event.people.filter { !event.label.contains($0) && !given.contains($0) }
    }

    /// 事件的次要信息：「8:00–9:00 · 60 分钟 · 8 公里 · 在公园 · 和小王」
    public static func eventMeta(_ event: RecordData.Event) -> String {
        var parts: [String] = []
        if let start = event.start, let end = event.end {
            parts.append("\(clock(start))–\(clock(end))")
        } else if let start = event.start {
            parts.append("\(clock(start)) 开始")
        } else if let end = event.end {
            parts.append("\(clock(end)) 结束")
        }
        if let duration = event.durationMin { parts.append(minutes(Int(duration))) }
        parts += metrics(event.metrics) + moneyNotes(event.metrics, label: event.label)
        let places = event.places.filter { !event.label.contains($0) }
        if !places.isEmpty { parts.append("在\(places.joined(separator: "、"))") }
        let people = peopleToShow(event)
        if !people.isEmpty { parts.append("和\(people.joined(separator: "、"))") }
        return parts.joined(separator: " · ")
    }

    /// 一天几条心情的说法：既有好的又有不好的是「有起有落」，否则是平均的那一级
    public static func dayMood(_ levels: [Int]) -> String? {
        guard !levels.isEmpty else { return nil }
        if levels.contains(where: { $0 >= 4 }) && levels.contains(where: { $0 <= 2 }) { return "有起有落" }
        let average = Double(levels.reduce(0, +)) / Double(levels.count)
        return PourFormat.moodWord(Int(average.rounded()))
    }
}

extension WebText {
    /// 卡片分组：事件按顶级类别（子类别合在上级的卡片里），其余按种类
    public static func group(of entry: Entry, categories: [LifeCategory]) -> String {
        switch entry.data {
        case .event(let event): return categories.root(of: event.category)
        case .insight: return "insight"
        case .todo: return "todo"
        case .mood: return "mood"
        }
    }

    /// 卡片的顺序：还有没做完的待办时待办放最前面；其余按类别表的顺序，感悟、做完的待办、心情放最后
    public static func sortGroups(_ groups: [String], categories: [LifeCategory], openTodos: Bool) -> [String] {
        let tail = ["insight", "todo", "mood"]
        let ordered = categories.sorted { $0.order < $1.order }.map(\.key)
        func rank(_ group: String) -> Int {
            if group == "todo" && openTodos { return -1 }
            if let index = tail.firstIndex(of: group) { return 1000 + index }
            return ordered.firstIndex(of: group) ?? 999
        }
        return groups.sorted { rank($0) < rank($1) }
    }

    /// 卡片标题旁的数字（按顶级类别的计量）：时长写总时长；次数两条以上写「N 次」；
    /// 别的单位把同单位的数加起来，加不出来退回总时长；后面接「花了 ¥160」「收入 ¥8,000」
    public static func headline(_ events: [RecordData.Event], measure: String) -> String? {
        let minutes = events.reduce(0) { $0 + ($1.durationMin ?? 0) }
        var parts: [String] = []
        if measure == "count" {
            if events.count >= 2 { parts.append("\(events.count) 次") }
        } else if measure != "duration" {
            let values = events.flatMap { $0.metrics.filter { $0.unit == measure }.map(\.value) }
            if !values.isEmpty {
                parts.append("\(amount(values.reduce(0, +))) \(measure)")
            } else if minutes > 0 {
                parts.append(self.minutes(minutes))
            }
        } else if minutes > 0 {
            parts.append(self.minutes(minutes))
        }
        let money = events.flatMap(\.metrics).filter { $0.unit == "元" }
        let spent = money.filter { $0.name == "花费" }.reduce(0) { $0 + $1.value }
        let earned = money.filter { $0.name == "收入" }.reduce(0) { $0 + $1.value }
        if spent > 0 { parts.append("花了 \(yuan(spent))") }
        if earned > 0 { parts.append("收入 \(yuan(earned))") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
