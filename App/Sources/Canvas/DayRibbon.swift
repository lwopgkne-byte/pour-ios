import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 一天的带子：说了时间的事按时间排成类别色的色块（够宽的写图标，大块下面写名字和时长），今天有一根线指着现在；
/// 同一时间重叠的分两层，很短的（15 分钟以内）是小圆点；没说时间的事在下面一行小胶囊，左右滑。
/// 范围照以前的规则：至少 6–23 点，有更早更晚的就扩
struct DayRibbon: View {
    @Environment(AppModel.self) private var model
    let day: String
    let entries: [API.Entry]

    var body: some View {
        let items = entries.compactMap(RibbonItem.init)
        let timed = items.filter { $0.event.start != nil || $0.event.end != nil }
        let untimed = items.filter { $0.event.start == nil && $0.event.end == nil }
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.small) {
                SectionHeader(title: "一天的时间", trailing: day == model.today ? "现在 \(RibbonTrack.clock(Date()))" : nil)
                VStack(alignment: .leading, spacing: Theme.Space.medium) {
                    if !timed.isEmpty { RibbonTrack(day: day, items: timed) }
                    if !untimed.isEmpty { UntimedRow(day: day, items: untimed) }
                }
                .themeCard(padding: Theme.Space.inset)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("一天的时间"))
        }
    }
}

/// 带子上的一件事
struct RibbonItem: Identifiable {
    let id: Int
    let event: API.EventData
    let category: String
    let pending: Bool

    init?(_ entry: API.Entry) {
        guard case .event(let event) = entry.data else { return nil }
        id = entry.id
        self.event = event
        category = entry.category
        pending = entry.pending
    }

    /// 从几点到几点：只说了开始和多久的，按多久算结束
    var span: (start: String, end: String)? {
        guard let start = event.start ?? event.end else { return nil }
        let end = event.end ?? event.durationMin.map { PourDate.addMinutes(start, $0) } ?? start
        return (start, max(start, end))
    }
}

/// 没说时间的：一行小胶囊，左右滑
private struct UntimedRow: View {
    @Environment(AppModel.self) private var model
    let day: String
    let items: [RibbonItem]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text("没说时间").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            // 滑到卡片两边：列表撑满卡片宽，内容两边留出卡片的内边距
            ScrollView(.horizontal) {
                HStack(spacing: Theme.Space.small) {
                    ForEach(items) { item in chip(item) }
                }
            }
            .contentMargins(.horizontal, Theme.Space.inset, for: .scrollContent)
            .scrollIndicators(.hidden)
            .padding(.horizontal, -Theme.Space.inset)
        }
    }

    private func chip(_ item: RibbonItem) -> some View {
        let meta = Show.meta(item.category, model.categories)
        return Button {
            model.openEntry(item.id, day: day)
        } label: {
            HStack(spacing: Theme.Space.snug) {
                Circle().fill(Theme.tag(meta.color).solid).frame(width: Theme.Size.dot, height: Theme.Size.dot)
                Text(Show.spaced(item.event.label)).font(Theme.Typeface.subheadline)
                    .foregroundStyle(Theme.Palette.label)
            }
            .padding(.horizontal, Theme.Space.medium).frame(minHeight: Theme.Size.capsule)
            .background(Theme.Palette.fill, in: Capsule())
            .overlay {
                if item.pending { Capsule().strokeBorder(Theme.Palette.accent.opacity(0.5), lineWidth: 1) }
            }
            .frame(minHeight: Theme.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Show.spaced("\(item.event.label) \(Show.eventMeta(item.event, day: day))")))
        .accessibilityAddTraits(.isButton)
    }
}

/// 带子本身：36 点高的浅底，上面是色块；下面一行大块的名字和时长、一行刻度（画出来的）。
/// 读屏把整条带子读成一句（按时间列出每件事）：重叠时一块只有十几点高，一块一块的不好点；每件事在下面的卡片里都能点开
struct RibbonTrack: View {
    @Environment(AppModel.self) private var model
    @ScaledMetric(relativeTo: .caption2) private var tickRow = Theme.Size.tickRow
    let day: String
    let items: [RibbonItem]

    var body: some View {
        let range = Self.range(day, items)
        let lanes = Self.lanes(items)
        let twoLanes = lanes.values.contains(1)
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    Theme.rounded(Theme.Corner.ribbon).fill(Theme.Palette.fill)
                    ForEach(items) { item in
                        RibbonBlock(
                            item: item, day: day,
                            rect: place(item, range, proxy.size, lane: lanes[item.id] ?? 0, twoLanes))
                    }
                    if day == model.today, let now = position(Self.nowStamp(), range), now > 0, now < 1 {
                        NowLine().offset(x: proxy.size.width * now - 1)
                    }
                }
            }
            .frame(height: Theme.Size.ribbon)
            if items.contains(where: { RibbonLabels.isBig($0, range) }) {
                RibbonLabels(items: items, range: range).frame(height: tickRow)
            }
            RibbonTicks(range: range).frame(height: tickRow)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Self.spoken(items)))
    }

    /// 读屏读的那一句：「0:10 到 7:10 睡觉；8:20 到 8:55 坐地铁；17:30 接儿子放学」
    static func spoken(_ items: [RibbonItem]) -> String {
        let timed = items.compactMap { item in item.span.map { (span: $0, label: item.event.label) } }
        return timed.sorted { $0.span.start < $1.span.start }.map { span, label in
            let from = Show.clock(span.start)
            let time = span.end > span.start ? "\(from) 到 \(Show.clock(span.end))" : from
            return Show.spaced("\(time) \(label)")
        }
        .joined(separator: "；")
    }

    /// 一件事在带子上的位置；两层时各占一半高
    private func place(
        _ item: RibbonItem, _ range: (start: String, minutes: Int), _ size: CGSize, lane: Int, _ twoLanes: Bool
    ) -> CGRect {
        guard let span = item.span else { return .zero }
        let from = (position(span.start, range) ?? 0) * size.width
        let until = (position(span.end, range) ?? 0) * size.width
        let height = twoLanes ? (size.height - Theme.Space.hairline) / 2 : size.height
        let top = CGFloat(lane) * (height + Theme.Space.hairline)
        return CGRect(x: from, y: top, width: max(0, until - from), height: height)
    }

    private func position(_ time: String, _ range: (start: String, minutes: Int)) -> Double? {
        min(1, max(0, Double(PourDate.minutesBetween(range.start, time)) / Double(range.minutes)))
    }

    /// 重叠的放第二层（最多两层，再重叠也画在第二层）
    static func lanes(_ items: [RibbonItem]) -> [Int: Int] {
        var lanes: [Int: Int] = [:]
        var laneEnd = ["", ""]
        for item in items.sorted(by: { ($0.span?.start ?? "") < ($1.span?.start ?? "") }) {
            guard let span = item.span else { continue }
            let lane = span.start >= laneEnd[0] ? 0 : 1
            lanes[item.id] = lane
            laneEnd[lane] = max(laneEnd[lane], span.end)
        }
        return lanes
    }

    static func clock(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    static func nowStamp() -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
        return String(
            format: "%04d-%02d-%02dT%02d:%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0,
            parts.minute ?? 0)
    }

    /// 范围：至少 6 点到 23 点，有更早更晚的就往外扩（最多前一天 18 点到第二天 12 点），按整点取整
    static func range(_ day: String, _ items: [RibbonItem]) -> (start: String, minutes: Int) {
        var start = "\(day)T06:00"
        var end = "\(day)T23:00"
        for item in items {
            guard let span = item.span else { continue }
            if span.start < start { start = span.start }
            if span.end > end { end = span.end }
        }
        start = max(start, "\(PourDate.addDays(day, -1))T18:00")
        end = min(end, "\(PourDate.addDays(day, 1))T12:00")
        let floor = String(start.prefix(13)) + ":00"
        let endFloor = String(end.prefix(13)) + ":00"
        let ceil = end.hasSuffix(":00") ? end : PourDate.addMinutes(endFloor, 60)
        return (floor, max(60, PourDate.minutesBetween(floor, ceil)))
    }
}

/// 带子上的一块：类别色；够宽的写白色图标；很短的是一个小圆点。能点的范围撑到 44 宽
private struct RibbonBlock: View {
    @Environment(AppModel.self) private var model
    let item: RibbonItem
    let day: String
    let rect: CGRect

    var body: some View {
        let meta = Show.meta(item.category, model.categories)
        let color = Theme.tag(meta.color).solid.opacity(item.pending ? 0.5 : 0.92)
        let dot = rect.width < Theme.Size.bar
        let tap = max(rect.width, Theme.Size.touch)
        Button {
            model.openEntry(item.id, day: day)
        } label: {
            ZStack {
                if dot {
                    Circle().fill(color).frame(width: Theme.Size.bar, height: Theme.Size.bar)
                } else {
                    Theme.rounded(min(Theme.Corner.ribbon - 1, rect.height / 2)).fill(color)
                        .frame(width: rect.width, height: rect.height)
                        .overlay {
                            if rect.width >= Theme.Size.tile, rect.height >= Theme.Size.ribbon - 1,
                                let symbol = CategoryIcon.symbol(key: item.category, name: meta.name)
                            {
                                Image(systemName: symbol).font(Theme.Typeface.glyph)
                                    .foregroundStyle(Theme.Palette.onAccent)
                            }
                        }
                }
            }
            .frame(width: tap, height: rect.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: rect.minX + rect.width / 2 - tap / 2, y: rect.minY)
    }
}

/// 大块（占带子五分之一以上）下面写名字和时长；放不下就不写
private struct RibbonLabels: View {
    let items: [RibbonItem]
    let range: (start: String, minutes: Int)

    var body: some View {
        Canvas { context, size in
            for item in items where Self.isBig(item, range) {
                guard let span = item.span else { continue }
                let from = Double(PourDate.minutesBetween(range.start, span.start)) / Double(range.minutes)
                let until = Double(PourDate.minutesBetween(range.start, span.end)) / Double(range.minutes)
                let text = Text(Show.spaced("\(item.event.label) \(Show.minutes(CanvasPlan.minutes(item.event)))"))
                    .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                let resolved = context.resolve(text)
                let width = size.width * (until - from)
                guard resolved.measure(in: size).width <= width else { continue }
                context.draw(resolved, at: CGPoint(x: size.width * max(0, from), y: size.height / 2), anchor: .leading)
            }
        }
        .accessibilityHidden(true)
    }

    /// 占带子五分之一以上的才写名字
    static func isBig(_ item: RibbonItem, _ range: (start: String, minutes: Int)) -> Bool {
        guard let span = item.span else { return false }
        return Double(PourDate.minutesBetween(span.start, span.end)) / Double(range.minutes) > 0.2
    }
}

/// 刻度：每 3 小时一个（范围很长时每 6 小时），两头的靠边写
private struct RibbonTicks: View {
    let range: (start: String, minutes: Int)

    var body: some View {
        let step = range.minutes > 16 * 60 ? 6 : 3
        Canvas { context, size in
            for minute in stride(from: 0, through: range.minutes, by: 60) {
                let hour = Int(PourDate.addMinutes(range.start, minute).dropFirst(11).prefix(2)) ?? 0
                guard hour % step == 0 else { continue }
                let place = Double(minute) / Double(range.minutes)
                let anchor: UnitPoint = place < 0.05 ? .leading : (place > 0.95 ? .trailing : .center)
                let text = Text(verbatim: "\(hour)").font(Theme.Typeface.tick).foregroundStyle(
                    Theme.Palette.tertiaryLabel)
                context.draw(text, at: CGPoint(x: size.width * place, y: size.height / 2), anchor: anchor)
            }
        }
        .accessibilityHidden(true)
    }
}

/// 「现在」那根线：上面一个小圆点
private struct NowLine: View {
    var body: some View {
        VStack(spacing: 0) {
            Circle().fill(Theme.Palette.accent).frame(width: Theme.Size.bar, height: Theme.Size.bar)
            Capsule().fill(Theme.Palette.accent).frame(width: Theme.Space.hairline)
        }
        .frame(height: Theme.Size.ribbon + Theme.Size.bar)
        .offset(x: -Theme.Size.bar / 2 + 1, y: -Theme.Size.bar / 2)
        .accessibilityHidden(true)
    }
}
