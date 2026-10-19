import PourCore
import PourData
import PourDesign
import SwiftUI

/// 一条记录的详情（规范 12「原话追溯」）：它现在的样子、来自哪句原话（对应的那一段荧光标出）、改动历史。
/// 拿不准的一点就确认；不对的话直接再说一句怎么改（「刚才那个是 38 不是 28」）；删了能撤销
struct EntryDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let entryId: String

    @State private var entry: Entry?
    @State private var note: Note?
    @State private var history: [EntryChange] = []
    @State private var categories: [LifeCategory] = []

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    if let entry {
                        content(entry).padding(.horizontal, PourSpace.page(forWidth: proxy.size.width))
                            .padding(.bottom, PourSpace.pageEnd)
                    }
                }
            }
            .background(PourColor.canvas.color)
            .navigationTitle(entry.map { PourFormat.dayTitle($0.day, today: model.today) } ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
        .tint(PourColor.action.color)
        .task { load() }
        .onChange(of: model.day) { _, _ in load() }
    }

    private func load() {
        entry = try? model.store.entry(entryId)
        note = entry.flatMap { try? model.store.note($0.noteId) }
        history = (try? model.store.history(of: entryId)) ?? []
        categories = model.day.categories
    }

    @ViewBuilder private func content(_ entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            RecordCard(card(entry), state: entry.needsConfirmation ? .needsConfirmation : .normal)
                .padding(.top, PourSpace.element)
            if let question = entry.question {
                VStack(alignment: .leading, spacing: PourSpace.related) {
                    QuestionBar(prompt: QuestionPrompt(question, options: ["对"])) { _ in model.confirm(entryId) }
                    Text("不对的话，直接再说一句怎么改").pourText(.caption).foregroundStyle(PourColor.inkSecondary.color)
                }
                .padding(.top, PourSpace.element)
            }
            if let note {
                PourSectionHeader("原话")
                QuoteBlock(
                    source: "\(PourFormat.monthDay(note.day, today: model.today)) \(PourFormat.clock(note.localTime))",
                    quote: note.text,
                    highlight: note.text.contains(entry.span) && !entry.span.isEmpty ? entry.span : nil)
            }
            if !history.isEmpty {
                PourSectionHeader("改动")
                VStack(alignment: .leading, spacing: PourSpace.related) {
                    ForEach(Array(history.enumerated()), id: \.offset) { _, change in historyLine(change) }
                }
            }
            Button(role: .destructive) {
                model.delete(entryId)
            } label: {
                PourDestructiveLabel("删除这条")
            }
            .buttonStyle(PourButtonStyle(.text))
            .padding(.top, PourSpace.section)
            .accessibilityIdentifier("detail.delete")
        }
    }

    private func historyLine(_ change: EntryChange) -> some View {
        let when = PourFormat.clock(PourDate.localDateTime(change.changedAt, in: .current))
        let said = change.span.isEmpty ? (change.noteId == nil ? " · 你在这里点的" : "") : " ·「\(change.span)」"
        return HStack(alignment: .firstTextBaseline, spacing: PourSpace.element) {
            Text(when).pourText(.caption).monospacedDigit().foregroundStyle(PourColor.inkSecondary.color)
            Text(change.kind.word + said).pourText(.callout).foregroundStyle(PourColor.ink.color)
        }
        .accessibilityElement(children: .combine)
    }

    /// 记录卡上的样子
    private func card(_ entry: Entry) -> RecordContent {
        let line = RecordLine(
            entry.data, categories: categories, said: note?.localTime ?? entry.day, today: model.today)
        switch entry.data {
        case .event(let event):
            let money = event.metrics.filter(\.isMoney)
            if !money.isEmpty {
                return .money(
                    title: line.title + (line.person.map { " · 和\($0)" } ?? ""),
                    amount: money.map(\.display).joined(separator: " "), detail: timeText(event, day: entry.day),
                    tag: nil, worthQuote: nil)
            }
            return .event(
                domain: PourDomain(line.color), title: line.title, value: line.value,
                detail: timeText(event, day: entry.day), person: line.person)
        case .mood(let mood):
            return .mood(level: mood.level, saying: line.title, feeling: line.detail, moment: mood.moment)
        case .insight(let insight):
            return .insight(title: insight.title, quote: insight.quote)
        case .todo(let todo):
            return .todo(title: todo.content, due: line.detail, done: todo.done)
        }
    }

    /// 「07:10–07:42」「07:10」；说不出几点的写哪天
    private func timeText(_ event: RecordData.Event, day: DayString) -> String {
        let clock = [event.start, event.end].compactMap { $0.map(PourFormat.clock) }.joined(separator: "–")
        let date = PourFormat.dayTitle(day, today: model.today)
        let places = event.places.isEmpty ? "" : " · \(event.places.joined(separator: "、"))"
        return (clock.isEmpty ? date : "\(date) \(clock)") + places
    }
}

extension PourDomain {
    /// 类别表里的颜色名 → 领域色：网页版的名字（gray、green……）也认；对不上是「石」
    init(_ name: String) {
        let web = [
            "gray": "stone", "brown": "clay", "orange": "apricot", "yellow": "straw", "green": "moss",
            "blue": "lake", "purple": "wisteria", "pink": "sakura", "red": "brick",
        ]
        self = PourDomain(rawValue: web[name] ?? name) ?? .stone
    }
}
