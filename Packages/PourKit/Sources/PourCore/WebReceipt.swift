public import Foundation

/// 对话里的收据：一行说完这段话做了什么——
/// 「已记录：🏃 跑步 5 公里 · 💼 开会；已删除：💼 被老板骂」
public enum WebReceipt {
    /// 一个类别的名称、图标、颜色
    public struct Meta: Hashable, Sendable {
        public let name: String
        public let emoji: String
        public let color: String
    }

    /// 感悟、待办、心情各自就是一个类别
    public static let kindMeta: [String: Meta] = [
        "insight": Meta(name: "感悟", emoji: "💡", color: "yellow"),
        "todo": Meta(name: "待办", emoji: "📝", color: "gray"),
        "mood": Meta(name: "心情", emoji: "💭", color: "pink"),
    ]

    /// 一个类别的名称、图标、颜色：类别表里找，感悟待办心情用固定的，都没有就是「其他」
    public static func meta(_ key: String, categories: [LifeCategory]) -> Meta {
        if let category = categories.first(where: { $0.key == key }) {
            return Meta(name: category.name, emoji: category.emoji, color: category.color)
        }
        return kindMeta[key] ?? Meta(name: "其他", emoji: "📌", color: "gray")
    }

    /// 一条记录的简短描述（不含动作）
    public static func describe(_ data: RecordData, day: DayString, categories: [LifeCategory]) -> String {
        switch data {
        case .event(let event):
            return describe(event, categories: categories)
        case .insight(let insight):
            return "💡 感悟：\(insight.title)"
        case .todo(let todo):
            let remind = todo.remindAt.flatMap { time in
                todo.done ? nil : "（⏰ \(remindAt(time, day: day)) 提醒）"
            }
            return "\(todo.done ? "✅" : "📝") \(todo.done ? "完成" : "待办")：\(todo.content)\(remind ?? "")"
        case .mood(let mood):
            var parts = [PourFormat.moodWord(mood.level)]
            if !mood.emotions.isEmpty { parts.append(mood.emotions.joined(separator: "、")) }
            if let energy = mood.energy { parts.append(PourFormat.energyWord(energy)) }
            return "💭 心情：\(parts.joined(separator: " · "))（AI 推测）"
        }
    }

    /// 提醒的时刻：「7:00」；不在 day 那天的写上是哪天（「9月25日 7:00」）
    public static func remindAt(_ time: LocalDateTime, day: DayString) -> String {
        if time.hasPrefix(day) { return WebText.clock(time) }
        let month = Int(time.dropFirst(5).prefix(2)) ?? 0
        let date = Int(time.dropFirst(8).prefix(2)) ?? 0
        return "\(month)月\(date)日 \(WebText.clock(time))"
    }

    /// 事件：「🏃 跑步 60 分钟 5 公里 · 和小王」；睡眠写「😴 23:30 → 7:00」
    static func describe(_ event: RecordData.Event, categories: [LifeCategory]) -> String {
        let emoji = meta(event.category, categories: categories).emoji
        if event.category == "sleep", let start = event.start, let end = event.end {
            return "\(emoji) \(WebText.clock(start)) → \(WebText.clock(end))"
        }
        var parts = [event.label]
        if let duration = event.durationMin { parts.append(WebText.minutes(duration)) }
        let metrics = WebText.metrics(event.metrics)
        if !metrics.isEmpty { parts.append(metrics.joined(separator: "、")) }
        for note in WebText.moneyNotes(event.metrics, label: event.label) { parts.append("· \(note)") }
        let places = event.places.filter { !event.label.contains($0) }
        if !places.isEmpty { parts.append("· 在\(places.joined(separator: "、"))") }
        let people = WebText.peopleToShow(event)
        if !people.isEmpty { parts.append("· 和\(people.joined(separator: "、"))") }
        return "\(emoji) \(parts.joined(separator: " "))"
    }

    /// 收据里的一项
    public struct Item: Hashable, Sendable {
        public var action: NoteAction.Kind
        public var isInsight: Bool
        public var text: String
        public var pending: Bool

        public init(action: NoteAction.Kind, isInsight: Bool, text: String, pending: Bool) {
            self.action = action
            self.isInsight = isInsight
            self.text = text
            self.pending = pending
        }
    }

    /// 这一项怎么写：「之前已记过」带在后面；收据按动作分组，组里不再写动作
    public static func item(_ action: NoteAction.Kind, entry: Entry, categories: [LifeCategory]) -> Item {
        let base = describe(entry.data, day: entry.day, categories: categories)
        let text = action == .duplicate ? "\(base)（之前已记过）" : base
        let insightTitle: String? = if case .insight(let insight) = entry.data { insight.title } else { nil }
        return Item(
            action: action, isInsight: insightTitle != nil,
            text: action == .completed ? text.replacingOccurrences(of: "完成：", with: "") : text,
            pending: entry.question != nil)
    }

    private static let groups: [(label: String, actions: [NoteAction.Kind])] = [
        ("已记录", [.created, .duplicate]),
        ("已修改", [.updated]),
        ("已完成", [.completed]),
        ("已确认", [.confirmed]),
        ("已删除", [.deleted]),
    ]

    /// 整行收据；什么都没做是 nil。多条新感悟合并成「💡 N 条感悟」
    public static func line(_ items: [Item]) -> String? {
        guard !items.isEmpty else { return nil }
        var out: [String] = []
        for group in groups {
            let inGroup = items.filter { group.actions.contains($0.action) }
            guard !inGroup.isEmpty else { continue }
            let insights = inGroup.filter { $0.action == .created && $0.isInsight && !$0.pending }
            var parts = inGroup.filter { !insights.contains($0) }.map { $0.pending ? "\($0.text)（待确认）" : $0.text }
            if insights.count == 1, let only = insights.first { parts.append(only.text) }
            if insights.count > 1 { parts.append("💡 \(insights.count) 条感悟") }
            out.append("\(group.label)：\(parts.joined(separator: " · "))")
        }
        return out.joined(separator: "；")
    }

    /// 原话下面那个状态说的是实际做了什么：已记录、已删除、已修改、等你回答……
    public static func doneLabel(_ note: Note) -> String {
        if note.undoneAt != nil { return "已撤销" }
        if !note.questions.isEmpty || !note.awaitingDelete.isEmpty { return "等你回答" }
        let kinds = Set(note.actions.map(\.kind))
        if kinds.contains(.created) { return "已记录" }
        if kinds.count == 1, let only = kinds.first {
            switch only {
            case .deleted: return "已删除"
            case .updated: return "已修改"
            case .completed: return "已完成"
            case .confirmed: return "已确认"
            default: return "之前已记过"
            }
        }
        return kinds.isEmpty ? "已收到" : "已更新"
    }
}
