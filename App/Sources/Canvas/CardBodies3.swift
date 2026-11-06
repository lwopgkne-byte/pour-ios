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
            // 只有一条（待办 2.0 第 9 步）：大字说法后面跟五个点、右边几点记的，下面那一行不再写一遍「一般」
            if moods.count == 1, case .mood(let mood) = moods[0].data {
                HStack(alignment: .center, spacing: Theme.Space.medium) {
                    Text(Show.moodWords[MoodRow.level(mood) - 1]).font(Theme.Typeface.metric)
                        .foregroundStyle(Theme.Palette.label)
                    MoodDots(level: MoodRow.level(mood))
                    Spacer(minLength: 0)
                    if let time = times[0] {
                        Text("\(time) 记的").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                            .monospacedDigit()
                    }
                }
                .accessibilityElement(children: .combine)
                CardRow(entry: moods[0]) { MoodRow(mood: mood, quotes: quotes, time: nil, single: true) }
            } else {
                if let word = Show.dayMood(levels) {
                    Text(word).font(Theme.Typeface.metric).foregroundStyle(Theme.Palette.label)
                }
                let points = Self.points(moods)
                if points.count > 1 { LevelCurve(points: points, color: Theme.tag("pink").solid) }
                ForEach(Array(moods.enumerated()), id: \.element.id) { index, entry in
                    if case .mood(let mood) = entry.data {
                        CardRow(entry: entry) {
                            MoodRow(mood: mood, quotes: quotes, time: showTimes ? times[index] : nil)
                        }
                    }
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
    /// 这一天只有这一条：说法、点已经在上面大字里了，这一行只写情绪词、精力
    var single = false

    static func level(_ mood: API.MoodData) -> Int { min(5, max(1, Int(mood.mood.rounded()))) }

    var body: some View {
        let level = Self.level(mood)
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.small) {
                if let time {
                    Text(time).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                        .monospacedDigit()
                }
                if !single {
                    MoodDots(level: level)
                    // 读屏：「挺好，五级里的第 4 级」（圆点不单独念，免得「挺好」念两遍）
                    Text(Show.moodWords[level - 1]).font(Theme.Typeface.bodySemibold)
                        .foregroundStyle(Theme.Palette.label)
                        .accessibilityLabel(Text("\(Show.moodWords[level - 1])，五级里的第 \(level) 级"))
                }
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

/// 待办卡（待办 2.0 第 9 步，docs/todo-2.0 design/after-01-home）：和待办页同一套行（按象限画的圈、一行标题、右边时间或状态），
/// 最多 4 行——过点的在前 → 马上做 → 其余按时间（日程穿插，同一个钟点开始的几场面试合成一行）；多了「还有 N 件 ›」进待办页。
/// 勾掉的划线留在原地（这张卡出来以后见过没做完的）；早就做完的不占位置。点了打开编辑，按住出菜单（和待办页一样）；
/// 拿不准的下面照旧追问
struct TodoBody: View {
    @Environment(AppModel.self) private var model
    let entries: [API.Entry]
    /// 日历里这一天的日程（没接日历是空的）：和你说的待办是同一件的只显示待办
    var events: [CalendarItem] = []
    /// 这张卡出来以后见过的、当时还没做完的（勾掉了留在原地）
    @State private var seen: Set<Int> = []

    var body: some View {
        let now = PourDate.localDateTime(Date(), in: .current)
        let all = entries.compactMap { API.TodoRow(entry: $0, today: model.today) }
        let open = all.filter { !$0.done || seen.contains($0.id) }
        // 全做完了：把今天做完的划线列出来（卡里只剩一个标题像坏了，2026-11-06 打磨）
        let rows = open.contains { !$0.done } ? open : all
        let plan = CanvasTodoPlan.make(rows: rows, events: AgendaPlan.visible(events, todos: entries), now: now)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(plan.shown.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Divider().overlay(Theme.Palette.separator).padding(.leading, Self.titleInset)
                }
                switch item {
                case .todo(let row):
                    TodoRowView(row: row, today: model.today, now: now, compact: true).todoPress(row)
                        .padding(.horizontal, -Theme.Space.regular)
                    if let entry = entries.first(where: { $0.id == row.id }), entry.pending {
                        ConfirmBox(entry: entry).padding(.bottom, Theme.Space.small)
                    }
                case .event(let line):
                    CalendarLine(line.title, time: line.time)
                        .padding(.horizontal, -Theme.Space.regular)
                        .accessibilityIdentifier(line.time == "全天" ? "agenda.allDay" : "agenda.event")
                }
            }
            if plan.more > 0 {
                Divider().overlay(Theme.Palette.separator)
                Button {
                    model.openLink("/todos")
                } label: {
                    HStack(spacing: Theme.Space.tight) {
                        // 「其余」：右上角已经写着「还有 17 件」，底下再写「还有 13 件」两个数看混（2026-11-06）
                        Text("其余 \(plan.more) 件")
                        Image(systemName: "chevron.right").font(Theme.Typeface.footnoteSemibold)
                    }
                    .font(Theme.Typeface.subheadline.weight(.semibold)).foregroundStyle(Theme.Palette.accent)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("canvas.todos.more")
            }
        }
        .onAppear(perform: remember)
        .onChange(of: entries) { remember() }
    }

    /// 分割线从标题开始（和待办页一样）：行往外挪了 16，圈的点按区 44，圈到标题 14
    private static let titleInset =
        Theme.Size.touch - (Theme.Size.touch - Theme.Size.check) + Theme.Space.medium + Theme.Space.hairline
        - (Theme.Size.touch - Theme.Size.check) / 2

    private func remember() {
        seen.formUnion(
            entries.compactMap { entry in
                if case .todo(let todo) = entry.data, !todo.done { entry.id } else { nil }
            })
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

/// 五个小圆点（心情的五级，填到第几个）
private struct MoodDots: View {
    let level: Int

    var body: some View {
        HStack(spacing: Theme.Space.tight) {
            ForEach(1...5, id: \.self) { dot in
                Circle().fill(dot <= level ? Theme.tag("pink").solid : Theme.Palette.fill)
                    .frame(width: Theme.Size.dot, height: Theme.Size.dot)
            }
        }
        .accessibilityHidden(true)
    }
}
