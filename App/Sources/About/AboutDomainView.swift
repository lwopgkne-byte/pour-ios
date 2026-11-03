import PourAPI
import PourDesign
import SwiftUI

/// 一个生活领域一页（docs/prd-about-me-2.md 5.3、8.4）：一个模板，有什么数据就长什么——
/// 大数字和日历 → 什么时候 → 做什么 → 和谁、在哪 → 那些日子的心情 → 你说过的话 → 这些数的变化 → 发现 → 变化
struct AboutDomainView: View {
    @Environment(AppModel.self) private var model
    let key: String
    let navigate: (String) -> Void
    @State private var page: API.MeDomainPage?
    /// 每一天只亮和谁 / 在哪的那几天（nil 是全部）
    @State private var with: String?
    @State private var problem: String?
    @State private var known = KnownStore()

    var body: some View {
        Group {
            if let page {
                content(page)
            } else if let problem {
                ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: Theme.Size.goalCard)
            }
        }
        .aboutPage()
        .navigationTitle(page?.name ?? "关于我")
        .task(id: "\(key)-\(model.dataVersion)") { await load() }
        .task(id: model.dataVersion) { await known.load(model.client) }
        .sheet(item: $known.opened) { KnownPeek(store: known, key: $0.id) }
    }

    @ViewBuilder private func content(_ page: API.MeDomainPage) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.cardGap) {
            MeHead(title: page.name, color: page.color) {
                navigate("/about")
            } sub: {
                EmptyView()
            }
            calendarPanel(page)
            if let when = page.when {
                AboutCardSection(title: "什么时候") {
                    WhenGrid(cells: when.cells, color: page.color)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(Text("一周七天里，上午、下午、晚上各有几天"))
                    if !when.sentence.isEmpty {
                        Text(Show.spaced(when.sentence)).font(Theme.Typeface.footnote).foregroundStyle(
                            Theme.Palette.label)
                    }
                }
            }
            if !page.acts.isEmpty || !page.chips.isEmpty {
                AboutCardSection(title: page.actsTitle) {
                    if !page.acts.isEmpty { CountBars(items: page.acts, color: page.color) }
                    if !page.chips.isEmpty { chips(page.chips) }
                }
            }
            if let mood = page.mood { AboutCardSection(title: "那些日子的心情") { MoodScale(mood: mood, color: page.color) } }
            if !page.quotes.isEmpty { AboutCardSection(title: "你说过的话") { MeQuotes(quotes: page.quotes) } }
            DomainTrend(domain: key)
            knownSection
            if !page.findings.isEmpty { AboutCardSection(title: "发现") { MeFindings(findings: page.findings) } }
            if !page.changes.isEmpty {
                AboutCardSection(title: "变化") { MeChanges(changes: page.changes, navigate: navigate) }
            }
            MeFoot()
        }
    }

    /// Pour 认识的：作息（睡眠那一页）、这个领域里常做的事；都没有就不出现
    @ViewBuilder private var knownSection: some View {
        let about = known.about
        let habits =
            about?.habits.contains { $0.domain == key } == true
            || about?.hidden.contains { $0.block == "habits" && $0.domain == key } == true
        let sleep = key == "sleep" && (about?.sleep != nil || about?.hidden.contains { $0.block == "sleep" } == true)
        if habits || sleep {
            AboutCardSection(title: "Pour 认识的") {
                VStack(alignment: .leading, spacing: Theme.Space.xLarge) {
                    if key == "sleep" { KnownSleep(store: known) }
                    KnownHabits(store: known, domain: key)
                }
            }
        }
    }

    /// 和谁、在哪：小圆标签带天数；点开看那几天
    /// 大数字和每一天（上面一排「全部 · 和儿子」只亮那几天）
    private func calendarPanel(_ page: API.MeDomainPage) -> some View {
        MePanel {
            MeNote(page.span)
            Text(Show.spaced(page.headline)).font(Theme.Typeface.largeTitle).foregroundStyle(Theme.Palette.label)
            MeNote(page.sub)
            if !page.chips.isEmpty { withChips(page.chips) }
            let lit = page.chips.first { $0.name == with }.map { Set($0.days) }
            MeCalendar(
                weeks: page.calendar, kind: "domain",
                paint: { day in
                    day.state == "on" && (lit?.contains(day.day) ?? true) ? Theme.tag(page.color).solid : nil
                },
                open: { day in
                    model.goHome()
                    model.show(day)
                }
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel(
                Text("\(page.span)每一天：\(page.person.map { "和\($0)在一起" } ?? "说到\(page.name)")的那天是彩色的"))
        }
    }

    /// 每一天上面一排：全部 · 和儿子 · 小区……点一个只亮那几天（06 交互细节 10.6）
    private func withChips(_ chips: [API.MeCount]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.small) {
                FilterChip("全部", selected: with == nil) { with = nil }
                ForEach(chips.prefix(4), id: \.name) { chip in
                    FilterChip(chip.name, selected: with == chip.name) { with = with == chip.name ? nil : chip.name }
                }
            }
        }
        .accessibilityIdentifier("domain.with")
    }

    private func chips(_ chips: [API.MeCount]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(chips, id: \.name) { chip in
                MeExpand {
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Space.tight) {
                        Text(Show.spaced(chip.name)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                        Text("\(chip.count)").font(Theme.Typeface.footnote).foregroundStyle(
                            Theme.Palette.secondaryLabel)
                    }
                    .padding(.horizontal, Theme.Space.regular).frame(minHeight: Theme.Size.touch)
                    .background(Capsule().fill(Theme.Palette.fill))
                } content: {
                    DayLinks(days: chip.days)
                }
            }
        }
        .padding(.top, Theme.Space.medium)
    }

    private func load() async {
        do {
            page = try await model.client.meDomain(key)
            problem = nil
        } catch {
            problem = error.readable
        }
    }
}

/// 什么时候：一周 7 天 × 上午、下午、晚上，越深越常；点一格看那几天
private struct WhenGrid: View {
    let cells: [API.MeWhenCell]
    let color: String
    @State private var open: API.MeWhenCell?

    private static let parts = ["上午", "下午", "晚上"]
    /// 领域色的几成（和产品里的月历同一把尺子）
    private static let shades = [0, 0.12, 0.26, 0.42, 0.64, 1.0]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Grid(horizontalSpacing: Theme.Space.tight, verticalSpacing: Theme.Space.tight) {
                GridRow {
                    Color.clear.frame(width: Theme.Space.xLarge, height: 1)
                    ForEach(MeStyle.weekHead, id: \.self) { PaintedText(text: $0) }
                }
                .accessibilityHidden(true)
                ForEach(Array(Self.parts.enumerated()), id: \.offset) { index, part in
                    GridRow {
                        Text(String(part.prefix(1))).font(Theme.Typeface.footnote).foregroundStyle(
                            Theme.Palette.secondaryLabel)
                        ForEach(cells.filter { $0.part == index }, id: \.weekday) { cell in self.cell(cell, part: part)
                        }
                    }
                }
            }
            if let open { DayLinks(days: open.days) }
        }
    }

    @ViewBuilder private func cell(_ cell: API.MeWhenCell, part: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Corner.tile)
        if cell.days.isEmpty {
            shape.fill(Theme.Palette.fill).frame(height: Theme.Space.section).accessibilityHidden(true)
        } else {
            Button {
                withAnimation(Theme.Motion.standard) { open = open == cell ? nil : cell }
            } label: {
                shape.fill(Theme.tag(color).solid.opacity(Self.shades[min(5, max(0, Int(cell.level)))]))
                    .frame(height: Theme.Space.section).frame(maxWidth: .infinity).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("周\(MeStyle.weekHead[cell.weekday])\(part)：\(cell.count) 天"))
            .accessibilityAddTraits(open == cell ? .isSelected : [])
        }
    }
}

/// 那些日子的心情：一条从很差到很好的线（五档），两个标记：有它的日子、别的日子。只写说法，不写分数
private struct MoodScale: View {
    let mood: API.MeMoodView
    let color: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text(Show.spaced(mood.headline)).font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.label)
            // 线在中间；有它的日子：标记和字在上面，别的日子：字在下面
            GeometryReader { proxy in
                let width = proxy.size.width
                let line = Theme.Space.section + Theme.Space.tight
                let place = { (value: Double) in width * CGFloat((value - 1) / 4) }
                ZStack {
                    HStack(spacing: Theme.Space.tight / 2) {
                        ForEach(1...5, id: \.self) { level in Capsule().fill(MeStyle.moodShade(Double(level))) }
                    }
                    .frame(width: width, height: Theme.Space.small)
                    .position(x: width / 2, y: line)
                    Capsule().fill(Theme.tag(color).solid).frame(width: Theme.Space.tight, height: Theme.Space.xLarge)
                        .position(x: place(mood.with), y: line)
                    Text(mood.withLabel).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.label).fixedSize()
                        .position(x: place(mood.with), y: line - Theme.Space.xLarge)
                    Capsule().fill(Theme.Palette.secondaryLabel).frame(
                        width: Theme.Space.tight, height: Theme.Space.xLarge
                    )
                    .position(x: place(mood.without), y: line)
                    Text(mood.withoutLabel).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                        .fixedSize()
                        .position(x: place(mood.without), y: line + Theme.Space.xLarge)
                }
            }
            .frame(height: (Theme.Space.section * 2) + Theme.Space.small)
            HStack {
                Text("很差")
                Spacer()
                Text("一般")
                Spacer()
                Text("很好")
            }
            .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            MeNote("\(mood.text) · 只是同时出现")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(mood.headline)。\(mood.text)。只是同时出现"))
    }
}

/// 这个领域有数的指标（睡眠有三个：时长、入睡、起床）的变化；一个都没有时整块不出现（看板并进来）
private struct DomainTrend: View {
    @Environment(AppModel.self) private var model
    let domain: String
    @State private var metrics: [API.BoardMetric] = []
    @State private var picked: String?
    @State private var dim = "week"
    @State private var trend: API.BoardTrend?

    /// 「时长」「次数」「距离」：在这一块里不用再写领域的名字
    static func shortName(_ metric: API.BoardMetric) -> String {
        switch metric.id.split(separator: ":").last {
        case "duration": "时长"
        case "count": "次数"
        case "distance": "距离"
        default: metric.name
        }
    }

    private static let dims = [
        (key: "day", label: "日"), (key: "week", label: "周"), (key: "month", label: "月"), (key: "year", label: "年"),
    ]
    private static let spans = ["day": "7 天", "week": "4 周", "month": "3 个月", "year": ""]

    private var id: String? { picked ?? metrics.first?.id }

    var body: some View {
        // 先放一个看不见的：数据还没回来时这一块是空的，空的不会开始加载
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 0)
            if !metrics.isEmpty {
                AboutCardSection(title: metrics.count > 1 ? "这些数的变化" : "\(metrics[0].name)的变化") { content }
            }
        }
        .task(id: model.dataVersion) {
            metrics = ((try? await model.client.boardMetrics()) ?? []).filter { $0.category == domain }
        }
        .task(id: "\(id ?? "")-\(dim)-\(model.dataVersion)") {
            guard let id else { return }
            trend = try? await model.client.trend(id, dim: dim)
        }
    }

    @ViewBuilder private var content: some View {
        if metrics.count > 1 {
            ScrollView(.horizontal) {
                HStack(spacing: Theme.Space.small) {
                    ForEach(metrics, id: \.id) { metric in
                        FilterChip(Self.shortName(metric), selected: metric.id == id) { picked = metric.id }
                    }
                }
                .padding(.vertical, (Theme.Size.touch - Theme.Size.capsule) / 2)
            }
            .scrollIndicators(.hidden)
            .padding(.vertical, -(Theme.Size.touch - Theme.Size.capsule) / 2)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("看哪个数"))
        }
        Picker("维度", selection: $dim) {
            ForEach(Self.dims, id: \.key) { option in Text(option.label).tag(option.key) }
        }
        .pickerStyle(.segmented)
        if let trend {
            let empty = trend.points.allSatisfy { ($0.value ?? 0) == 0 }
            if empty {
                Text("这段时间没有\(trend.metric.name)的记录，换个维度看看更长的时间。").font(Theme.Typeface.body).foregroundStyle(
                    Theme.Palette.secondaryLabel)
            } else {
                Text(summary(trend)).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    .monospacedDigit()
                ChartCard(
                    spec: .series(
                        .init(
                            type: trend.metric.how == "sum" ? "bar" : "line", title: trend.metric.name,
                            unit: trend.metric.unit,
                            points: trend.points, trend: trend.trend, target: trend.target)))
                let notes = [
                    trend.trend == nil ? nil : "虚线是\(Self.spans[dim] ?? "")移动平均",
                    trend.target.map { "横线是目标 \(ChartCard.value($0, unit: trend.metric.unit))" },
                ].compactMap { $0 }
                if !notes.isEmpty { MeNote(notes.joined(separator: "，")) }
            }
        } else {
            SkeletonBlock(height: (Theme.Space.section * 2) * 2)
        }
    }

    private func summary(_ trend: API.BoardTrend) -> String {
        let value = trend.summary.value.map { ChartCard.value($0, unit: trend.metric.unit) } ?? "没有记录"
        let each = trend.metric.how == "avg" && dim != "day" ? "（每天）" : ""
        let year = trend.yoy.map { " · 比前一年\($0 >= 0 ? "多" : "少") \(Int((abs($0) * 100).rounded()))%" } ?? ""
        return "\(trend.summary.label) \(value)\(each)\(year)"
    }
}
