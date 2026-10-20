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
    @State private var problem: String?
    @State private var known = KnownStore()

    var body: some View {
        Group {
            if let page {
                content(page)
            } else if let problem {
                WebErrorState(problem) { Task { await load() } }
            } else {
                ReviewSkeleton()
            }
        }
        .moneyPage()
        .task(id: "\(key)-\(model.dataVersion)") { await load() }
        .task(id: model.dataVersion) { await known.load(model.client) }
        .sheet(item: $known.opened) { KnownPeek(store: known, key: $0.id) }
    }

    @ViewBuilder private func content(_ page: API.MeDomainPage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MeHead(title: page.name, color: page.color) {
                navigate("/about")
            } sub: {
                EmptyView()
            }
            MePanel {
                MeNote(page.span)
                Text(Show.spaced(page.headline)).font(Web.title).foregroundStyle(Web.fg)
                MeNote(page.sub)
                MeCalendar(
                    weeks: page.calendar, kind: "domain", paint: { $0.state == "on" ? Web.tag(page.color).solid : nil },
                    open: { day in
                        model.page = .canvas
                        model.show(day)
                    }
                )
                .accessibilityElement(children: .contain)
                .accessibilityLabel(
                    Text("\(page.span)每一天：\(page.person.map { "和\($0)在一起" } ?? "说到\(page.name)")的那天是彩色的"))
            }
            if let when = page.when {
                ReviewSection(title: "什么时候") {
                    WhenGrid(cells: when.cells, color: page.color)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(Text("一周七天里，上午、下午、晚上各有几天"))
                    if !when.sentence.isEmpty {
                        Text(Show.spaced(when.sentence)).font(Web.caption).foregroundStyle(Web.fg)
                    }
                }
            }
            if !page.acts.isEmpty || !page.chips.isEmpty {
                ReviewSection(title: page.actsTitle) {
                    if !page.acts.isEmpty { CountBars(items: page.acts, color: page.color) }
                    if !page.chips.isEmpty { chips(page.chips) }
                }
            }
            if let mood = page.mood { ReviewSection(title: "那些日子的心情") { MoodScale(mood: mood, color: page.color) } }
            if !page.quotes.isEmpty { ReviewSection(title: "你说过的话") { MeQuotes(quotes: page.quotes) } }
            DomainTrend(domain: key)
            knownSection
            if !page.findings.isEmpty { ReviewSection(title: "发现") { MeFindings(findings: page.findings) } }
            if !page.changes.isEmpty {
                ReviewSection(title: "变化") { MeChanges(changes: page.changes, navigate: navigate) }
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
            ReviewSection(title: "Pour 认识的") {
                VStack(alignment: .leading, spacing: Web.space6) {
                    if key == "sleep" { KnownSleep(store: known) }
                    KnownHabits(store: known, domain: key)
                }
            }
        }
    }

    /// 和谁、在哪：小圆标签带天数；点开看那几天
    private func chips(_ chips: [API.MeCount]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(chips, id: \.name) { chip in
                MeExpand {
                    HStack(alignment: .firstTextBaseline, spacing: Web.space1) {
                        Text(Show.spaced(chip.name)).font(Web.body).foregroundStyle(Web.fg)
                        Text("\(chip.count)").font(Web.caption).foregroundStyle(Web.fgTertiary)
                    }
                    .padding(.horizontal, Web.space4).frame(minHeight: Web.touch)
                    .background(Capsule().fill(Web.bgSubtle))
                } content: {
                    DayLinks(days: chip.days)
                }
            }
        }
        .padding(.top, Web.space3)
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
        VStack(alignment: .leading, spacing: Web.space2) {
            Grid(horizontalSpacing: Web.space1, verticalSpacing: Web.space1) {
                GridRow {
                    Color.clear.frame(width: Web.space6, height: 1)
                    ForEach(MeStyle.weekHead, id: \.self) { PaintedText(text: $0) }
                }
                .accessibilityHidden(true)
                ForEach(Array(Self.parts.enumerated()), id: \.offset) { index, part in
                    GridRow {
                        Text(String(part.prefix(1))).font(Web.caption).foregroundStyle(Web.fgTertiary)
                        ForEach(cells.filter { $0.part == index }, id: \.weekday) { cell in self.cell(cell, part: part)
                        }
                    }
                }
            }
            if let open { DayLinks(days: open.days) }
        }
    }

    @ViewBuilder private func cell(_ cell: API.MeWhenCell, part: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: Web.radiusControl)
        if cell.days.isEmpty {
            shape.fill(Web.bgSubtle).frame(height: Web.space8).accessibilityHidden(true)
        } else {
            Button {
                withAnimation(Web.fast) { open = open == cell ? nil : cell }
            } label: {
                shape.fill(Web.tag(color).solid.opacity(Self.shades[min(5, max(0, Int(cell.level)))]))
                    .frame(height: Web.space8).frame(maxWidth: .infinity).contentShape(Rectangle())
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
        VStack(alignment: .leading, spacing: Web.space2) {
            Text(Show.spaced(mood.headline)).font(Web.captionMedium).foregroundStyle(Web.fg)
            // 线在中间；有它的日子：标记和字在上面，别的日子：字在下面
            GeometryReader { proxy in
                let width = proxy.size.width
                let line = Web.space8 + Web.space1
                let place = { (value: Double) in width * CGFloat((value - 1) / 4) }
                ZStack {
                    HStack(spacing: Web.space1 / 2) {
                        ForEach(1...5, id: \.self) { level in Capsule().fill(MeStyle.moodShade(Double(level))) }
                    }
                    .frame(width: width, height: Web.space2)
                    .position(x: width / 2, y: line)
                    Capsule().fill(Web.tag(color).solid).frame(width: Web.space1, height: Web.space6)
                        .position(x: place(mood.with), y: line)
                    Text(mood.withLabel).font(Web.caption).foregroundStyle(Web.fg).fixedSize()
                        .position(x: place(mood.with), y: line - Web.space6)
                    Capsule().fill(Web.fgSecondary).frame(width: Web.space1, height: Web.space6)
                        .position(x: place(mood.without), y: line)
                    Text(mood.withoutLabel).font(Web.caption).foregroundStyle(Web.fgSecondary).fixedSize()
                        .position(x: place(mood.without), y: line + Web.space6)
                }
            }
            .frame(height: Web.space16 + Web.space2)
            HStack {
                Text("很差")
                Spacer()
                Text("一般")
                Spacer()
                Text("很好")
            }
            .font(Web.caption).foregroundStyle(Web.fgTertiary)
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
                ReviewSection(title: metrics.count > 1 ? "这些数的变化" : "\(metrics[0].name)的变化") { content }
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
                HStack(spacing: Web.space2) {
                    ForEach(metrics, id: \.id) { metric in
                        WebChip(selected: metric.id == id) {
                            picked = metric.id
                        } label: {
                            Text(metric.emoji).accessibilityHidden(true)
                            Text(metric.name)
                        }
                    }
                }
                .padding(.vertical, (Web.touch - Web.control) / 2)
            }
            .scrollIndicators(.hidden)
            .padding(.vertical, -(Web.touch - Web.control) / 2)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("看哪个数"))
        }
        WebSegmented("维度", options: Self.dims, selected: dim) { dim = $0 }
        if let trend {
            let empty = trend.points.allSatisfy { ($0.value ?? 0) == 0 }
            if empty {
                Text("这段时间没有\(trend.metric.name)的记录，换个维度看看更长的时间。").font(Web.body).foregroundStyle(Web.fgTertiary)
            } else {
                Text(summary(trend)).font(Web.caption).foregroundStyle(Web.fgSecondary).monospacedDigit()
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
            WebSkeleton(height: Web.space16 * 2)
        }
    }

    private func summary(_ trend: API.BoardTrend) -> String {
        let value = trend.summary.value.map { ChartCard.value($0, unit: trend.metric.unit) } ?? "没有记录"
        let each = trend.metric.how == "avg" && dim != "day" ? "（每天）" : ""
        let year = trend.yoy.map { " · 比前一年\($0 >= 0 ? "多" : "少") \(Int((abs($0) * 100).rounded()))%" } ?? ""
        return "\(trend.summary.label) \(value)\(each)\(year)"
    }
}
