import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 详情里能改的字段（网页版 EntryPeek 的 Detail）：点哪一行改哪一行，改完交给网页版服务器（字段名照网页版）
struct PeekFields: View {
    let entry: API.Entry

    var body: some View {
        switch entry.data {
        case .event(let event): EventFields(entry: entry, event: event)
        case .todo(let todo): TodoFields(entry: entry, todo: todo)
        case .insight(let insight): InsightFields(entry: entry, insight: insight)
        case .mood(let mood): MoodFields(entry: entry, mood: mood)
        }
    }
}

/// 不像钟点：说一句怎么写（网页版 isClock）
func notClock(_ text: String) -> String? {
    text.trimmingCharacters(in: .whitespaces).wholeMatch(of: /\d{1,2}:\d{2}/) == nil ? "时间写成 08:30 这样" : nil
}

/// 不像日期：说一句怎么写
func notDay(_ text: String) -> String? {
    PourDate.isValid(text.trimmingCharacters(in: .whitespaces)) ? nil : "日期写成 2026-10-20 这样"
}

/// 不是一个数：说一句（网页版 isNumber）
func notNumber(_ text: String) -> String? {
    Double(text.trimmingCharacters(in: .whitespaces)).map { $0 >= 0 } == true ? nil : "需要是一个数字"
}

/// 「儿子、老公 朋友」→ ["儿子", "老公", "朋友"]
func splitWords(_ text: String) -> [JSONValue] {
    var seen: [String] = []
    for word in text.split(whereSeparator: { "、，, ".contains($0) || $0.isNewline }) {
        let item = word.trimmingCharacters(in: .whitespaces)
        if !item.isEmpty && !seen.contains(item) { seen.append(item) }
    }
    return seen.map(JSONValue.string)
}

extension API.Metric {
    /// 改一笔钱、一个数时整笔发回去（网页版 { ...m, value }）
    func json(value newValue: Double) -> JSONValue {
        var fields: [String: JSONValue] = ["name": .string(name), "value": .number(newValue), "unit": .string(unit)]
        if let item { fields["item"] = .string(item) }
        if let forWhom { fields["for"] = .string(forWhom) }
        if let flag { fields["flag"] = .string(flag) }
        if let from { fields["from"] = .string(from) }
        if settled == true { fields["settled"] = .bool(true) }
        if monthly == true { fields["monthly"] = .bool(true) }
        return .object(fields)
    }

    /// 名目已经写在这一行的名称里了：值里不再写一遍
    var withoutItem: API.Metric {
        var plain = self
        plain.item = nil
        return plain
    }
}

private struct EventFields: View {
    @Environment(AppModel.self) private var model
    let entry: API.Entry
    let event: API.EventData

    var body: some View {
        VStack(spacing: 0) {
            PeekRow(label: "名称") {
                InlineEdit(label: "名称", value: event.label) {
                    save(["label": .string($0.trimmingCharacters(in: .whitespaces))])
                }
            }
            PeekRow(label: "开始") {
                InlineEdit(
                    label: "开始时间", value: event.start.map { String($0.suffix(5)) } ?? "", placeholder: "没说",
                    keyboard: .numbersAndPunctuation, validate: notClock
                ) { save(["start": .string($0)]) }
            }
            PeekRow(label: "结束") {
                InlineEdit(
                    label: "结束时间", value: event.end.map { String($0.suffix(5)) } ?? "", placeholder: "没说",
                    keyboard: .numbersAndPunctuation, validate: notClock
                ) { save(["end": .string($0)]) }
            }
            PeekRow(label: "时长") {
                InlineEdit(
                    label: "时长（分钟）", value: event.durationMin.map(String.init) ?? "",
                    display: event.durationMin.map(Show.minutes), placeholder: "没说", keyboard: .numberPad,
                    validate: notNumber
                ) { text in if let minutes = Double(text) { save(["duration_min": .number(minutes)]) } }
            }
            ForEach(Array((event.metrics ?? []).enumerated()), id: \.offset) { _, metric in
                let label = metric.item.map { "\(metric.name)（\($0)）" } ?? metric.name
                PeekRow(label: label) {
                    InlineEdit(
                        label: label, value: Show.amount(metric.value), display: Show.metric(metric.withoutItem),
                        keyboard: .decimalPad, validate: notNumber
                    ) { text in
                        if let value = Double(text) { save(["metrics": .array([metric.json(value: value)])]) }
                    }
                }
            }
            MentionRows(
                values: [
                    .people: event.people ?? [], .things: event.things ?? [], .places: event.places ?? [],
                    .tags: event.tags ?? [],
                ]
            ) { field, text in save([field.key: .array(splitWords(text))]) }
            PeekRow(label: "备注") {
                InlineEdit(label: "备注", value: event.note ?? "") {
                    save(["note": .string($0.trimmingCharacters(in: .whitespaces))])
                }
            }
        }
    }

    private func save(_ fields: [String: JSONValue]) { model.update(entry.id, fields) }
}

/// 人、物、地方（事件还有话题）：有内容的一行一项；空着的收成一行「添加：和谁 · 东西 · 地方 · 话题」，点哪个就直接打开它的输入框
struct MentionRows: View {
    enum Field: CaseIterable {
        case people, things, places, tags

        var label: String {
            switch self {
            case .people: "和谁"
            case .things: "东西"
            case .places: "地方"
            case .tags: "话题"
            }
        }

        /// 网页版的字段名
        var key: String {
            switch self {
            case .people: "people"
            case .things: "things"
            case .places: "places"
            case .tags: "tags"
            }
        }
    }

    /// 有哪几项（待办没有话题）
    let values: [Field: [String]]
    let save: (Field, String) -> Void
    @State private var adding: Field?

    var body: some View {
        let fields = Field.allCases.filter { values[$0] != nil }
        let empty = fields.filter { (values[$0] ?? []).isEmpty && $0 != adding }
        ForEach(fields.filter { !(values[$0] ?? []).isEmpty || $0 == adding }, id: \.self) { field in
            PeekRow(label: field.label) {
                InlineEdit(
                    label: field.label, value: (values[field] ?? []).joined(separator: "、"), placeholder: "没有",
                    startEditing: field == adding
                ) { text in
                    adding = nil
                    save(field, text)
                }
            }
        }
        if !empty.isEmpty {
            PeekRow(label: "添加") {
                HStack(spacing: Web.space2) {
                    ForEach(Array(empty.enumerated()), id: \.element) { index, field in
                        if index > 0 { Text("·").foregroundStyle(Web.fgTertiary).accessibilityHidden(true) }
                        Button(field.label) { adding = field }
                            .buttonStyle(.plain).foregroundStyle(Web.fgSecondary)
                            .frame(minHeight: Web.touch)
                            .accessibilityLabel(Text("添加\(field.label)"))
                    }
                }
            }
        }
    }
}

private struct TodoFields: View {
    @Environment(AppModel.self) private var model
    let entry: API.Entry
    let todo: API.TodoData

    var body: some View {
        VStack(spacing: 0) {
            PeekRow(label: "内容") {
                InlineEdit(label: "内容", value: todo.content) {
                    save(["content": .string($0.trimmingCharacters(in: .whitespaces))])
                }
            }
            PeekRow(label: "期限") {
                InlineEdit(
                    label: "期限", value: todo.due ?? "", display: todo.due.map { Show.dayTitle($0, today: model.today) },
                    placeholder: "没说", keyboard: .numbersAndPunctuation,
                    validate: notDay
                ) { save(["due": .string($0.trimmingCharacters(in: .whitespaces))]) }
            }
            PeekRow(label: "提醒") {
                InlineEdit(
                    label: "提醒时间", value: todo.remindAt.map { String($0.suffix(5)) } ?? "",
                    display: todo.remindAt.map(remindText),
                    placeholder: "不提醒", keyboard: .numbersAndPunctuation, validate: notClock
                ) { save(["remind_at": .string($0)]) }
            }
            let mentions: [MentionRows.Field: [String]] = [
                .people: todo.people ?? [], .things: todo.things ?? [], .places: todo.places ?? [],
            ]
            MentionRows(values: mentions) { field, text in save([field.key: .array(splitWords(text))]) }
            PeekRow(label: "状态") {
                Button(todo.done ? "已完成 · 改为未完成" : "未完成 · 标记为完成") { model.setDone(entry.id, !todo.done) }
                    .font(Web.bodyMedium).foregroundStyle(Web.accent).buttonStyle(.plain)
            }
        }
    }

    private func save(_ fields: [String: JSONValue]) { model.update(entry.id, fields) }

    /// 「10 月 20 日 周二 08:00 · 已提醒」
    private func remindText(_ time: String) -> String {
        let day = Show.dayTitle(String(time.prefix(10)), today: model.today)
        return "\(day) \(time.suffix(5))\(todo.reminded == true ? " · 已提醒" : "")"
    }
}

private struct InsightFields: View {
    @Environment(AppModel.self) private var model
    let entry: API.Entry
    let insight: API.InsightData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuoteText(text: insight.quote).padding(.bottom, Web.space4)
            PeekRow(label: "标题") {
                InlineEdit(label: "标题", value: insight.title) {
                    model.update(entry.id, ["title": .string($0.trimmingCharacters(in: .whitespaces))])
                }
            }
            PeekRow(label: "标签") {
                InlineEdit(label: "标签（用逗号分开）", value: insight.tags.joined(separator: "，")) {
                    model.update(entry.id, ["tags": .array(splitWords($0))])
                }
            }
        }
    }
}
