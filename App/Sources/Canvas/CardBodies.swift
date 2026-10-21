import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 时长的卡（工作、学习、运动、兴趣、娱乐、家务、出行……）：大字总时长；整行时一条 24 小时的带子和每一段
struct DurationBody: View {
    @Environment(AppModel.self) private var model
    let entries: [API.Entry]
    let day: String
    let size: CanvasPlan.Size

    var body: some View {
        let events = entries.compactMap(CanvasPlan.event)
        let total = events.reduce(0) { $0 + CanvasPlan.minutes($1) }
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            FigureText(CanvasPlan.durationParts(total).map { ($0.number, $0.unit) })
            if size == .full {
                let spans = events.compactMap { DayFraction.span($0, day: day) }
                if !spans.isEmpty { SpanTrack(spans: spans, color: tint).padding(.vertical, Theme.Space.tight) }
            }
            EventRows(entries: entries, day: day, compact: size == .half)
        }
    }

    private var tint: Color {
        Theme.tag(Show.meta(entries.first?.category ?? "", model.categories).color).solid
    }
}

/// 次数的卡（育儿、宠物、健康、家人朋友、购物、办事……）：同一件事最多的那件写大字「7 次」+「喂奶 · 最近一次 21:10」，
/// 一条 24 小时的细线上一次一个小圆点；同名的合成一行「换尿布 6 次 · 最近 21:10」
struct CountBody: View {
    @Environment(AppModel.self) private var model
    let entries: [API.Entry]
    let day: String
    let size: CanvasPlan.Size

    var body: some View {
        let groups = CountGroups(entries)
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            if let top = groups.top, top.entries.count >= 2 {
                FigureText([("\(top.entries.count)", "次")])
                Text(Show.spaced("\(top.label)\(top.latest.map { " · 最近一次 \($0)" } ?? "")"))
                    .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            } else if entries.count >= 2 {
                FigureText([("\(entries.count)", "次")])
            }
            let points = groups.top.map { $0.entries.compactMap { DayFraction.point($0, day: day) } } ?? []
            let others = groups.rest.flatMap(\.entries).compactMap { DayFraction.point($0, day: day) }
            if points.count + others.count >= 2 { DotTrack(points: points, lighter: others, color: tint) }
            ShowFirst(items: groups.all) { group, _ in groupRow(group) }
        }
    }

    /// 一组：一次的照常一行（有要确认的也一条一行）；好几次的合成一行，点了打开最近的那次
    @ViewBuilder private func groupRow(_ group: CountGroups.Group) -> some View {
        if group.entries.count == 1 || group.entries.contains(where: \.pending) {
            ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                CardRow(entry: entry, quiet: repeatsQuestion(group.entries, index)) {
                    EventLine(entry: entry, day: day, compact: size == .half)
                }
            }
        } else if let last = group.entries.last {
            CardRow(entry: last) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Show.spaced(group.label)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                    Spacer(minLength: Theme.Space.small)
                    Text("\(group.entries.count) 次\(group.latest.map { " · 最近 \($0)" } ?? "")")
                        .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                }
                .padding(.vertical, Theme.Space.tight)
            }
        }
    }

    private var tint: Color {
        Theme.tag(Show.meta(entries.first?.category ?? "", model.categories).color).solid
    }
}

/// 同一件事分组：最多的那件在前
struct CountGroups {
    struct Group: Identifiable {
        let label: String
        let entries: [API.Entry]
        var id: String { label }
        /// 最近一次几点（说了时间的）
        var latest: String? {
            entries.compactMap { CanvasPlan.event($0)?.start }.max().map(Show.clock)
        }
    }

    let all: [Group]
    var top: Group? { all.first }
    var rest: [Group] { Array(all.dropFirst()) }

    init(_ entries: [API.Entry]) {
        var order: [String] = []
        for label in entries.compactMap({ CanvasPlan.event($0)?.label }) where !order.contains(label) {
            order.append(label)
        }
        all = order.map { label in Group(label: label, entries: entries.filter { CanvasPlan.event($0)?.label == label })
        }
        .sorted { $0.entries.count > $1.entries.count }
    }
}

/// 数量的卡（跑步按公里、读书按页……）：合计 + 单位；有这一类的目标时右边一个进度环
struct QuantityBody: View {
    @Environment(AppModel.self) private var model
    let card: CanvasPlan.Card
    let day: API.DayView
    let size: CanvasPlan.Size

    var body: some View {
        let measure = model.categories.first { $0.key == card.id }?.measure ?? ""
        let events = card.entries.compactMap(CanvasPlan.event)
        let total = events.flatMap { $0.metrics ?? [] }.filter { $0.unit == measure }.reduce(0) { $0 + $1.value }
        let goal = day.goals.first { goal in goal.category.map { Show.root($0, model.categories) } == card.id }
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            HStack(alignment: .center) {
                FigureText([(Show.amount(total), measure)])
                Spacer(minLength: Theme.Space.small)
                if let goal {
                    ProgressRing(progress: goal.pct, color: Theme.Palette.status(goal.tone), lineWidth: 4)
                        .frame(width: Theme.Size.smallRing, height: Theme.Size.smallRing)
                }
            }
            EventRows(entries: card.entries, day: day.day, compact: size == .half)
        }
    }
}

/// 一般的事（办事、购物、其他……）：一行一件
struct GeneralBody: View {
    let entries: [API.Entry]
    let day: String
    let size: CanvasPlan.Size

    var body: some View {
        EventRows(entries: entries, day: day, compact: size == .half)
    }
}

/// 一行事件：名称 + 次要信息（「8:00–9:00 · 60 分钟 · 8 公里 · 在公园 · 和小王」）+ 一个话题；
/// 半宽卡里名称下面只写时间和钱（「12:30 · ¥32」）和小标签（「等报销」）
struct EventLine: View {
    @Environment(AppModel.self) private var model
    let entry: API.Entry
    let day: String
    var compact = false

    var body: some View {
        if let event = CanvasPlan.event(entry) {
            VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                Text(Show.spaced(event.label)).font(compact ? Theme.Typeface.bodyMedium : Theme.Typeface.body)
                    .foregroundStyle(Theme.Palette.label)
                if compact {
                    MoneyLine(event: event, day: day)
                } else {
                    let meta = Show.eventMeta(event, day: day)
                    let topic = Show.topic(event, category: entry.category, model.categories).map { "#\($0)" }
                    let line = [meta, topic ?? ""].filter { !$0.isEmpty }.joined(separator: "  ")
                    if !line.isEmpty {
                        Text(Show.spaced(line)).font(Theme.Typeface.footnote)
                            .foregroundStyle(Theme.Palette.secondaryLabel)
                            .accessibilityLabel(Text(Show.spoken(line)))
                    }
                }
            }
            .padding(.vertical, Theme.Space.tight)
        }
    }
}

/// 一串事件，先列 3 条
struct EventRows: View {
    let entries: [API.Entry]
    let day: String
    var compact = false

    var body: some View {
        ShowFirst(items: entries) { entry, index in
            CardRow(entry: entry, quiet: repeatsQuestion(entries, index)) {
                EventLine(entry: entry, day: day, compact: compact)
            }
        }
    }
}

/// 半宽卡的小字：几点到几点、多久、钱和几个小标签（「9:00–11:00 · 2 小时」「12:30 · ¥61 · 等报销」）
struct MoneyLine: View {
    let event: API.EventData
    let day: String

    var body: some View {
        let metrics = event.metrics ?? []
        let money = metrics.filter(Show.isMoney)
        let notes = Show.moneyNotes(metrics, label: event.label, day: day)
        let time = event.start.map { start in
            event.end.map { "\(Show.clock(start))–\(Show.clock($0))" } ?? Show.clock(start)
        }
        let minutes = CanvasPlan.minutes(event)
        let text = [time, minutes > 0 ? Show.minutes(minutes) : nil, money.first.map { Show.yuan($0.value) }]
            .compactMap(\.self).joined(separator: " · ")
        if !text.isEmpty || !notes.isEmpty {
            HStack(spacing: Theme.Space.small) {
                if !text.isEmpty {
                    Text(text).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                        .monospacedDigit().accessibilityLabel(Text(Show.spoken(text)))
                }
                ForEach(notes.prefix(2), id: \.self) { note in
                    ThemeBadge(Show.spaced(note), tone: ["等报销", "借出去"].contains(note) ? .accent : .neutral)
                }
            }
        }
    }
}

/// 一天里的位置（0–1）：小圆点、细带子用
enum DayFraction {
    /// 这件事几点（没说时间的是 nil）
    static func point(_ entry: API.Entry, day: String) -> Double? {
        guard let start = CanvasPlan.event(entry)?.start else { return nil }
        return fraction(start, day: day)
    }

    /// 这件事从几点到几点
    static func span(_ event: API.EventData, day: String) -> SpanTrack.Span? {
        guard let start = event.start else { return nil }
        let end = event.end ?? event.durationMin.map { PourDate.addMinutes(start, $0) } ?? start
        return SpanTrack.Span(start: fraction(start, day: day), end: fraction(end, day: day))
    }

    static func fraction(_ stamp: String, day: String) -> Double {
        min(1, max(0, Double(PourDate.minutesBetween("\(day)T00:00", stamp)) / 1440))
    }
}
