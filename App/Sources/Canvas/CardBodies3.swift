import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 心情：这一天的说法写大字；一天里的小曲线（每条一个点，按说的时间）；每条一行（五点刻度、说法、情绪词、精力）+ 那一刻
struct MoodBody: View {
    let entries: [API.Entry]
    let quotes: [String]

    var body: some View {
        let moods = entries.sorted { (Self.said($0) ?? "", $0.id) < (Self.said($1) ?? "", $1.id) }
        let levels = moods.compactMap { if case .mood(let mood) = $0.data { mood.mood } else { nil } }
        let times = moods.map { Self.said($0).map(Self.clock) }
        let showTimes = Set(times.compactMap(\.self)).count > 1
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            if let word = Show.dayMood(levels) {
                Text(word).font(Theme.Typeface.metric).foregroundStyle(Theme.Palette.label)
            }
            let points = Self.points(moods)
            if points.count > 1 { LevelCurve(points: points, color: Theme.tag("pink").solid) }
            ForEach(Array(moods.enumerated()), id: \.element.id) { index, entry in
                if case .mood(let mood) = entry.data {
                    CardRow(entry: entry) { MoodRow(mood: mood, quotes: quotes, time: showTimes ? times[index] : nil) }
                }
            }
        }
    }

    /// 建这条心情的那段话是什么时候说的
    static func said(_ entry: API.Entry) -> String? {
        (entry.sources.first { $0.action == "created" } ?? entry.sources.first)?.createdAt
    }

    /// 「16:16」「9:05」：按这台手机的时区
    static func clock(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return "" }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    /// 曲线上的点：横轴是说的时间（0–24 点），竖轴是五级
    static func points(_ moods: [API.Entry]) -> [(x: Double, level: Double)] {
        moods.compactMap { entry in
            guard case .mood(let mood) = entry.data, let said = said(entry) else { return nil }
            let clock = clock(said).split(separator: ":").compactMap { Double($0) }
            guard clock.count == 2 else { return nil }
            return ((clock[0] * 60 + clock[1]) / 1440, mood.mood)
        }
    }
}

/// 一条心情：几点说的、五个小圆点、说法、情绪词、精力；下面是那一刻（宋体）——已经整句写在当天感悟里的不再写
private struct MoodRow: View {
    let mood: API.MoodData
    let quotes: [String]
    let time: String?

    var body: some View {
        let level = min(5, max(1, Int(mood.mood.rounded())))
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.small) {
                if let time {
                    Text(time).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                        .monospacedDigit()
                }
                HStack(spacing: Theme.Space.tight) {
                    ForEach(1...5, id: \.self) { dot in
                        Circle().fill(dot <= level ? Theme.tag("pink").solid : Theme.Palette.fill)
                            .frame(width: Theme.Size.dot, height: Theme.Size.dot)
                    }
                }
                .accessibilityHidden(true)
                // 读屏：「挺好，五级里的第 4 级」（圆点不单独念，免得「挺好」念两遍）
                Text(Show.moodWords[level - 1]).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                    .accessibilityLabel(Text("\(Show.moodWords[level - 1])，五级里的第 \(level) 级"))
                Text(details).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    .accessibilityLabel(Text(Show.spoken(details)))
            }
            if let moment {
                Text("「\(Show.spaced(moment))」").font(Theme.Typeface.quote).foregroundStyle(Theme.Palette.label)
                    .lineSpacing(Theme.Leading.quote)
            }
        }
        .padding(.vertical, Theme.Space.tight)
    }

    /// 情绪词、精力：「焦虑、累 · 精力有点累」
    private var details: String {
        let emotions = mood.emotions.joined(separator: "、")
        let energy = mood.energy.map { "精力\(Show.energyWord($0))" }
        return [emotions, energy ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// 那一刻：已经整句在当天某条感悟的摘录里的不再写一遍
    private var moment: String? {
        let squash = { (text: String) in text.filter { !$0.isWhitespace && !$0.isPunctuation } }
        return mood.moment.flatMap { moment in
            moment.isEmpty || quotes.contains { squash($0).contains(squash(moment)) } ? nil : moment
        }
    }
}

/// 感悟：原话用宋体大一点地引出来，下面标签；意思相近的旧笔记收成一行「以前也说过类似的 N 条」
struct InsightBody: View {
    let entries: [API.Entry]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                if case .insight(let insight) = entry.data {
                    if index > 0 { Divider().overlay(Theme.Palette.separator) }
                    CardRow(entry: entry) {
                        VStack(alignment: .leading, spacing: Theme.Space.small) {
                            Text("「\(Show.spaced(insight.quote))」")
                                .font(entries.count == 1 ? Theme.Typeface.quoteLarge : Theme.Typeface.quote)
                                .foregroundStyle(Theme.Palette.label).lineSpacing(Theme.Leading.quote)
                            if !insight.tags.isEmpty {
                                PourFlowLayout(spacing: Theme.Space.small, lineSpacing: Theme.Space.small) {
                                    ForEach(insight.tags, id: \.self) { ThemeBadge($0, tone: .warn) }
                                }
                            }
                        }
                        .padding(.vertical, Theme.Space.tight)
                    }
                    if let related = entry.related, !related.isEmpty { RelatedNotes(related: related) }
                }
            }
        }
    }
}

/// 待办和提醒：圆圈勾选（勾掉有动画和触感）、提醒时间、已提醒；有提醒的按时间在前，其余按说的先后。
/// 做完的变淡划掉，但留在原地（产品主人 2026-10-21：勾掉以后跑到下面去是毛病）
struct TodoBody: View {
    @Environment(AppModel.self) private var model
    let entries: [API.Entry]
    /// 日历里这一天的日程（docs/模块/产品优化.md R6；没接日历是空的）：全天的放最上面一行，别的和待办按时间排
    var events: [CalendarItem] = []

    var body: some View {
        let agenda = AgendaPlan.rows(todos: entries, events: events)
        let todos = agenda.rows.compactMap { row -> API.Entry? in
            if case .todo(let entry) = row { entry } else { nil }
        }
        VStack(alignment: .leading, spacing: 0) {
            if !agenda.allDay.isEmpty { AllDayLine(items: agenda.allDay) }
            ShowFirst(items: agenda.rows, first: 5) { row, _ in
                switch row {
                case .todo(let entry):
                    // 和待办页同一套（3.0 第 2 步，01 需求文档 4.6）：同样的圆圈和胶囊、按住同样的菜单、点了同一个详情
                    if let todo = API.TodoRow(entry: entry, today: model.today) {
                        HStack(alignment: .top, spacing: Theme.Space.tight) {
                            TodoCircle(done: todo.done, label: todo.content) { model.setDone(entry.id, !todo.done) }
                                .padding(.leading, -Theme.Space.medium + Theme.Space.hairline)
                            CardRow(
                                entry: entry, quiet: repeatsQuestion(todos, todos.firstIndex(of: entry) ?? 0),
                                todo: todo
                            ) {
                                TodoLabel(
                                    Show.spaced(todo.content), done: todo.done,
                                    capsule: TodoBoard.capsule(
                                        todo, today: model.today, now: PourDate.localDateTime(Date(), in: .current)))
                            }
                        }
                    }
                case .event(let item):
                    AgendaEventRow(item: item)
                }
            }
        }
    }
}

/// 以前也说过类似的：平时收成一行，点开看日期和摘要，点一条跳到那一天
private struct RelatedNotes: View {
    @Environment(AppModel.self) private var model
    let related: [API.Related]
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(Theme.Motion.standard) { open.toggle() }
            } label: {
                HStack(spacing: Theme.Space.tight) {
                    Text(Show.spaced("以前也说过类似的 \(related.count) 条"))
                    Image(systemName: "chevron.right").rotationEffect(.degrees(open ? 90 : 0))
                }
                .font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.accent)
                .frame(minHeight: Theme.Size.touch)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if open {
                ForEach(related, id: \.self) { item in
                    Button {
                        model.show(item.day)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.medium) {
                            Text(Show.spaced(Show.dayTitle(item.day, today: model.today)))
                                .foregroundStyle(Theme.Palette.secondaryLabel)
                            Text(Show.spaced(item.text)).foregroundStyle(Theme.Palette.label).lineLimit(2)
                        }
                        .font(Theme.Typeface.footnote)
                        .frame(minHeight: Theme.Size.touch, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
