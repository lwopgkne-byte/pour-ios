import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 睡眠：大字时长；几点到几点（断断续续的写几段）；夜里的横条（前一晚 8 点到这天中午 12 点）
struct SleepBody: View {
    let entries: [API.Entry]
    let day: String
    let size: CanvasPlan.Size

    var body: some View {
        let events = entries.compactMap(CanvasPlan.event).sorted { ($0.start ?? "") < ($1.start ?? "") }
        let total = events.reduce(0) { $0 + CanvasPlan.minutes($1) }
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            FigureText(CanvasPlan.durationParts(total).map { ($0.number, $0.unit) })
            let spans = events.compactMap(night)
            if !spans.isEmpty { SpanTrack(spans: spans, color: Theme.tag("purple").solid) }
            if size == .full || entries.count > 1 || entries.contains(where: \.pending) {
                ShowFirst(items: entries) { entry, index in
                    CardRow(entry: entry, quiet: repeatsQuestion(entries, index)) {
                        SleepLine(event: CanvasPlan.event(entry))
                    }
                }
            } else if let only = entries.first {
                CardRow(entry: only) { SleepLine(event: CanvasPlan.event(only)) }
            }
        }
    }

    /// 在夜里刻度上的位置：前一晚 20:00 到这天 12:00，一共 16 小时（午睡也在这条上，靠右）
    private func night(_ event: API.EventData) -> SpanTrack.Span? {
        guard let start = event.start, let end = event.end else { return nil }
        let origin = "\(PourDate.addDays(day, -1))T20:00"
        let place = { (stamp: String) in Double(PourDate.minutesBetween(origin, stamp)) / (16 * 60) }
        return SpanTrack.Span(start: place(start), end: place(end))
    }
}

/// 睡眠的一行：「23:30 → 7:00」和时长；没说几点的写它的名字
private struct SleepLine: View {
    let event: API.EventData?

    var body: some View {
        if let event {
            HStack(alignment: .firstTextBaseline) {
                Text(Show.spaced(title(event))).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                    .monospacedDigit()
                Spacer(minLength: Theme.Space.small)
                let minutes = CanvasPlan.minutes(event)
                if minutes > 0 {
                    Text(Show.spaced(Show.minutes(minutes))).font(Theme.Typeface.footnote)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                }
            }
            .padding(.vertical, Theme.Space.tight)
        }
    }

    private func title(_ event: API.EventData) -> String {
        guard let start = event.start, let end = event.end else { return event.label }
        return "\(Show.clock(start)) → \(Show.clock(end))"
    }
}

/// 饮食：两顿以上说了时间的，大字写进食窗口（第一顿到最后一顿）、画一条横条；下面每一餐一行。
/// 只有一顿说了时间时不写窗口（一顿饭的「窗口」没有意义）
struct DietBody: View {
    let entries: [API.Entry]
    let day: String
    let size: CanvasPlan.Size

    var body: some View {
        let events = entries.compactMap(CanvasPlan.event)
        let timed = events.filter { $0.start != nil }
        let times = timed.flatMap { [$0.start, $0.end].compactMap(\.self) }.sorted()
        let spent = Show.money(events.map(CanvasPlan.withoutMonthly)).spent
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            if timed.count >= 2, let first = times.first, let last = times.last, first != last {
                FigureText(CanvasPlan.durationParts(PourDate.minutesBetween(first, last)).map { ($0.number, $0.unit) })
                Text("进食窗口 \(Show.clock(first))–\(Show.clock(last))\(spent > 0 ? " · \(Show.yuan(spent))" : "")")
                    .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel).monospacedDigit()
                SpanTrack(
                    spans: [
                        .init(start: DayFraction.fraction(first, day: day), end: DayFraction.fraction(last, day: day))
                    ],
                    color: Theme.tag("orange").solid)
            }
            EventRows(entries: entries, day: day, compact: size == .half)
        }
    }
}

/// 钱的汇总卡：今天日常花的（收入多的那天写收入）、按类别的分段条、等报销 / 借出去 / 每月固定；点了去「钱」的那一天
struct MoneyBody: View {
    @Environment(AppModel.self) private var model
    let entries: [API.Entry]
    let day: String

    var body: some View {
        let summary = MoneySummary(entries, model.categories)
        Button {
            model.open("/money/day/\(day)")
        } label: {
            VStack(alignment: .leading, spacing: Theme.Space.small) {
                let income = summary.earned > summary.spent
                FigureText(
                    [CanvasPlan.yuan(income ? summary.earned : summary.spent)].map { ($0.number, $0.unit) },
                    prefix: income ? "收入 ¥" : "¥")
                let other =
                    income
                    ? (summary.spent > 0 ? "花了 \(Show.yuan(summary.spent))" : nil)
                    : (summary.earned > 0 ? "收入 \(Show.yuan(summary.earned))" : nil)
                if let other {
                    Text(other).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                }
                if summary.segments.count > 1 { SegmentBar(summary.segments) }
                ForEach(summary.notes, id: \.self) { note in ThemeBadge(note, tone: .accent) }
                HStack(spacing: Theme.Space.tight) {
                    Text("看这一天的钱")
                    Image(systemName: "chevron.right")
                }
                .font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.accent)
                .frame(minHeight: Theme.Size.touch)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 一天的钱加起来：日常花的（每月固定扣的另算）、收入、按类别分段、等报销几笔、借出去几笔、每月固定多少
struct MoneySummary {
    let spent: Double
    let earned: Double
    let segments: [SegmentBar.Segment]
    let notes: [String]

    init(_ entries: [API.Entry], _ categories: [API.Category]) {
        // 每月固定扣的不算进今天日常花的；花了多少、收入多少照服务器的算法（Show.money）
        let daily = entries.compactMap { entry -> (String, API.EventData)? in
            guard let event = CanvasPlan.event(entry) else { return nil }
            return (Show.root(entry.category, categories), CanvasPlan.withoutMonthly(event))
        }
        (spent, earned) = Show.money(daily.map(\.1))
        var byCategory: [String: Double] = [:]
        for (category, event) in daily {
            let spend = Show.money([event]).spent
            if spend > 0 { byCategory[category, default: 0] += spend }
        }
        segments = byCategory.sorted { $0.value > $1.value }.map { key, value in
            SegmentBar.Segment(value: value, color: Theme.tag(Show.meta(key, categories).color).solid)
        }
        let metrics = entries.compactMap(CanvasPlan.event).flatMap { $0.metrics ?? [] }
        let reimburse = metrics.filter { $0.flag == "reimburse" && $0.settled != true }.count
        let lent = metrics.filter { $0.flag == "lend" && $0.settled != true }.count
        let fixed = metrics.filter { $0.monthly == true && Show.isMoney($0) }.reduce(0) { $0 + $1.value }
        notes = [
            reimburse > 0 ? "\(reimburse) 笔等报销" : nil, lent > 0 ? "\(lent) 笔借出去" : nil,
            fixed > 0 ? "每月固定 \(Show.yuan(fixed))" : nil,
        ].compactMap(\.self)
    }
}

/// 身体的数（血压、体重、血糖、心率、体温）：最后量的那次写大字，下面写几点量的；每一次一行
struct BodyBlock: View {
    let entries: [API.Entry]
    let day: String

    var body: some View {
        let sorted = entries.sorted { (CanvasPlan.event($0)?.start ?? "") < (CanvasPlan.event($1)?.start ?? "") }
        if let latest = sorted.last.flatMap(CanvasPlan.event),
            let highlight = CanvasPlan.bodyHighlight(latest, target: "")
        {
            VStack(alignment: .leading, spacing: Theme.Space.small) {
                FigureText(highlight.parts.map { ($0.number, $0.unit) })
                let unit = (latest.metrics ?? []).first(where: CanvasPlan.isBody)?.unit ?? ""
                let line = [highlight.label, unit, latest.start.map { "\(Show.clock($0)) 量的" } ?? ""]
                Text(Show.spaced(line.filter { !$0.isEmpty }.joined(separator: " · ")))
                    .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                ShowFirst(items: sorted) { entry, index in
                    CardRow(entry: entry, quiet: repeatsQuestion(sorted, index)) {
                        EventLine(entry: entry, day: day, compact: true)
                    }
                }
            }
        }
    }
}
