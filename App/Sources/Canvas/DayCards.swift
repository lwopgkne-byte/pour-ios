import PourCore
import PourDesign
import SwiftUI

/// 类别卡片（网页版 DayCards 1 比 1）：当天出现过的每个类别一张卡片，没有记录的类别不显示。
/// 点一行看详情；长按出现「修改 / 查看来源 / 删除」
struct DayCards: View {
    let entries: [Entry]
    let categories: [LifeCategory]
    let notes: [Note]

    var body: some View {
        let openTodos = entries.contains { if case .todo(let todo) = $0.data { !todo.done } else { false } }
        let keys = entries.map { WebText.group(of: $0, categories: categories) }
        let groups = WebText.sortGroups(Array(Set(keys)), categories: categories, openTodos: openTodos)
        if !groups.isEmpty {
            VStack(spacing: Web.space3) {
                ForEach(groups, id: \.self) { group in
                    GroupCard(
                        group: group,
                        items: entries.filter { WebText.group(of: $0, categories: categories) == group },
                        categories: categories, notes: notes,
                        quotes: entries.compactMap {
                            if case .insight(let insight) = $0.data { insight.quote } else { nil }
                        })
                }
            }
            .padding(.top, Web.space8)
        }
    }
}

/// 一张卡片：标题行（图标、名称、标题旁的数字），下面一行一条
private struct GroupCard: View {
    let group: String
    let items: [Entry]
    let categories: [LifeCategory]
    let notes: [Note]
    let quotes: [String]

    var body: some View {
        let meta = WebReceipt.meta(group, categories: categories)
        let pending = items.contains(where: \.needsConfirmation)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Web.space2) {
                Text(meta.emoji).accessibilityHidden(true)
                Text(meta.name).font(Web.bodySemibold).foregroundStyle(Web.fg)
                if let head { Text(head).foregroundStyle(Web.fgSecondary) }
                // 心情是 AI 从话里听出来的：只在卡片右上角标一次
                if group == "mood" {
                    Spacer(minLength: 0)
                    Text("AI 推测").font(Web.caption).foregroundStyle(Web.fgTertiary)
                }
            }
            .font(Web.body)
            .padding(.horizontal, Web.space2)
            .padding(.bottom, Web.space1)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            switch group {
            case "sleep": SleepRows(items: items, categories: categories)
            case "diet": DietRows(items: items, categories: categories)
            case "insight": InsightRows(items: items)
            case "todo": TodoRows(items: items)
            case "mood": MoodRows(items: items, notes: notes, quotes: quotes)
            default: EventRows(items: items)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Web.space3)
        .background(RoundedRectangle(cornerRadius: Web.radiusCard).fill(Web.bg))
        .overlay(
            RoundedRectangle(cornerRadius: Web.radiusCard).strokeBorder(
                pending ? Web.lineStrong : Web.line,
                style: StrokeStyle(lineWidth: 1, dash: pending ? [Web.space1, Web.space1 / 2] : [])))
    }

    /// 标题旁的数字：待办写还有几件，几条心情写这一天的样子，几条感悟写条数，别的按计量方式加起来
    private var head: String? {
        switch group {
        case "todo":
            let left = items.filter { if case .todo(let todo) = $0.data { !todo.done } else { false } }.count
            return left > 0 ? "还有 \(left) 件" : "都做完了"
        case "mood":
            let levels = items.compactMap { if case .mood(let mood) = $0.data { mood.level } else { nil } }
            return levels.count > 1 ? WebText.dayMood(levels) : nil
        case "insight":
            return items.count > 1 ? "\(items.count) 条" : nil
        case "sleep":
            return nil
        default:
            let measure = group == "diet" ? "duration" : (categories.first { $0.key == group }?.measure ?? "duration")
            let events = items.compactMap { if case .event(let event) = $0.data { event } else { nil } }
            return WebText.headline(events, measure: measure)
        }
    }
}

/// 一行记录：点一下看详情，长按出现操作菜单；待确认的显示追问和「确认」。
/// quiet：追问和上一行一样，问的话不再写一遍，「确认」放在这一行末尾
struct DayRow<Content: View>: View {
    @Environment(AppModel.self) private var model
    let entry: Entry
    var quiet = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Web.space2) {
                content().frame(maxWidth: .infinity, alignment: .leading)
                if let question = entry.question, quiet {
                    confirm.accessibilityHint(Text(question))
                }
            }
            .padding(.horizontal, Web.space2)
            .padding(.vertical, Web.space1)
            .frame(minHeight: Web.touch)
            .contentShape(RoundedRectangle(cornerRadius: Web.radiusControl))
            .onTapGesture { model.detail = .init(id: entry.id) }
            .contextMenu {
                Button("修改") { model.detail = .init(id: entry.id) }
                Button("查看来源") { model.detail = .init(id: entry.id) }
                Button("删除", role: .destructive) { model.delete(entry.id) }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            if let question = entry.question, !quiet {
                HStack(spacing: Web.space2) {
                    Text(question).font(Web.caption).foregroundStyle(Web.fgSecondary)
                    confirm
                }
                .padding(.horizontal, Web.space2)
                .padding(.bottom, Web.space2)
            }
        }
    }

    private var confirm: some View {
        Button("确认") { model.confirm(entry.id) }
            .font(Web.bodyMedium).foregroundStyle(Web.accent).buttonStyle(.plain)
            .frame(minHeight: Web.touch)
    }
}

/// 这一行的追问和上一行完全一样吗：一样的话只在第一行写一次
private func repeatsQuestion(_ items: [Entry], _ index: Int) -> Bool {
    guard index > 0, let question = items[index].question else { return false }
    return items[index - 1].question == question
}

/// 名称 + 次要信息（「跑步  5 公里」）：放不下时一起换行
private func labelWithMeta(_ label: String, _ meta: String) -> Text {
    var text = AttributedString(label)
    text.foregroundColor = Web.fg
    if !meta.isEmpty {
        var tail = AttributedString("  \(meta)")
        tail.foregroundColor = Web.fgSecondary
        text += tail
    }
    return Text(text)
}

private struct EventRows: View {
    let items: [Entry]

    var body: some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, entry in
            if case .event(let event) = entry.data {
                DayRow(entry: entry, quiet: repeatsQuestion(items, index)) {
                    labelWithMeta(event.label, WebText.eventMeta(event)).font(Web.body)
                        .lineSpacing(Web.bodyLineSpacing / 2)
                }
            }
        }
    }
}

/// 一段时间在一条横向刻度上的位置（睡眠横条、进食窗口）
private struct SpanBar: View {
    let from: LocalDateTime
    let until: LocalDateTime
    let rangeStart: LocalDateTime
    let rangeMinutes: Int
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let left = max(0, Double(PourDate.minutesBetween(rangeStart, from)) / Double(rangeMinutes))
            let width = max(0.02, min(1 - left, Double(PourDate.minutesBetween(from, until)) / Double(rangeMinutes)))
            Capsule().fill(Web.bgHover)
                .overlay(alignment: .leading) {
                    Capsule().fill(color).frame(width: proxy.size.width * width).offset(x: proxy.size.width * left)
                }
                .clipShape(Capsule())
        }
        .frame(height: Web.space1)
        .padding(.top, Web.space2)
        .padding(.bottom, Web.space1)
        .accessibilityHidden(true)
    }
}

/// 睡眠：「23:30 → 7:00」和时长；夜里的睡眠画一条横条（前一天 20 点到这天 12 点）
private struct SleepRows: View {
    let items: [Entry]
    let categories: [LifeCategory]

    var body: some View {
        ForEach(items) { entry in
            if case .event(let event) = entry.data {
                DayRow(entry: entry) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(sleepTitle(event)).foregroundStyle(Web.fg)
                            Spacer(minLength: Web.space3)
                            if let duration = event.durationMin {
                                Text(WebText.minutes(duration)).foregroundStyle(Web.fgSecondary)
                            }
                        }
                        .font(Web.body)
                        if let start = event.start, let end = event.end, PourDate.minutesBetween(start, end) >= 180 {
                            SpanBar(
                                from: start, until: end,
                                rangeStart: PourDate.addMinutes("\(end.prefix(10))T00:00", -4 * 60),
                                rangeMinutes: 16 * 60,
                                color: Web.tag(categories.color(of: event.category)).solid)
                        }
                    }
                }
            }
        }
    }

    private func sleepTitle(_ event: RecordData.Event) -> String {
        guard let start = event.start, let end = event.end else { return event.label }
        return "\(WebText.clock(start)) → \(WebText.clock(end))"
    }
}

/// 饮食：有两个以上时间就画出进食窗口（最早到最晚），下面列出各餐
private struct DietRows: View {
    let items: [Entry]
    let categories: [LifeCategory]

    var body: some View {
        let times = items.flatMap { entry -> [LocalDateTime] in
            guard case .event(let event) = entry.data else { return [] }
            return [event.start, event.end].compactMap { $0 }
        }.sorted()
        if let first = times.first, let last = times.last, times.count >= 2, first != last {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("进食窗口 \(WebText.clock(first))–\(WebText.clock(last))")
                    Spacer()
                    Text(WebText.minutes(PourDate.minutesBetween(first, last)))
                }
                .font(Web.caption).foregroundStyle(Web.fgSecondary)
                SpanBar(
                    from: first, until: last, rangeStart: "\(first.prefix(10))T00:00", rangeMinutes: 24 * 60,
                    color: Web.tag(WebReceipt.meta("diet", categories: categories).color).solid)
            }
            .padding(.horizontal, Web.space2)
        }
        EventRows(items: items)
    }
}

/// 原话的摘录：左边一条细线表示「这是引用」，行高 1.8
struct QuoteText: View {
    let text: String

    var body: some View {
        Text(text).font(Web.body).foregroundStyle(Web.fg).lineSpacing(Web.quoteLineSpacing)
            .padding(.leading, Web.space3)
            .overlay(alignment: .leading) { Rectangle().fill(Web.lineStrong).frame(width: Web.space1 / 2) }
    }
}

/// 感悟：引用原话，下面是标签
private struct InsightRows: View {
    let items: [Entry]

    var body: some View {
        ForEach(items) { entry in
            if case .insight(let insight) = entry.data {
                DayRow(entry: entry) {
                    VStack(alignment: .leading, spacing: Web.space2) {
                        QuoteText(text: insight.quote)
                        if !insight.tags.isEmpty {
                            PourFlowLayout(spacing: Web.space2, lineSpacing: Web.space2) {
                                ForEach(insight.tags, id: \.self) { tag in
                                    Text(tag).font(Web.caption).foregroundStyle(Web.tag("yellow").fg)
                                        .padding(.horizontal, Web.space2)
                                        .background(Capsule().fill(Web.tag("yellow").bg))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// 待办：勾选框，做完了文字变淡划掉；没做完的在前（定了提醒时间的按时间先后），做完的放最后
private struct TodoRows: View {
    @Environment(AppModel.self) private var model
    let items: [Entry]

    var body: some View {
        let sorted = items.sorted { key($0) < key($1) }
        ForEach(Array(sorted.enumerated()), id: \.element.id) { index, entry in
            if case .todo(let todo) = entry.data {
                DayRow(entry: entry, quiet: repeatsQuestion(sorted, index)) {
                    HStack(spacing: Web.space3) {
                        Button {
                            model.setDone(entry.id, !todo.done)
                        } label: {
                            RoundedRectangle(cornerRadius: Web.radiusControl)
                                .fill(todo.done ? Web.accent : Web.bg)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Web.radiusControl).strokeBorder(
                                        todo.done ? Web.accent : Web.lineStrong, lineWidth: 1)
                                )
                                .overlay {
                                    if todo.done {
                                        Image(systemName: "checkmark").font(Web.captionMedium).foregroundStyle(
                                            Web.onAccent)
                                    }
                                }
                                .frame(width: Web.icon, height: Web.icon)
                                .frame(width: Web.touch, height: Web.touch)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, -Web.space3)
                        .accessibilityLabel(Text(todo.content))
                        .accessibilityValue(Text(todo.done ? "已完成" : "未完成"))
                        Text(todo.content).font(Web.body)
                            .foregroundStyle(todo.done ? Web.fgTertiary : Web.fg)
                            .strikethrough(todo.done, color: Web.fgTertiary)
                        if let remind = todo.remindAt, !todo.done {
                            Text("⏰ \(WebText.clock(remind))").font(Web.body).foregroundStyle(Web.fgSecondary)
                        }
                    }
                }
            }
        }
    }

    private func key(_ entry: Entry) -> String {
        guard case .todo(let todo) = entry.data else { return "9" }
        if todo.done { return "2" }
        return todo.remindAt.map { "0\($0)" } ?? "1"
    }
}
