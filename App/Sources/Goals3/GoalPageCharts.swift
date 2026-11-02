import PourAPI
import PourDesign
import SwiftUI

/// 一个目标页上的图（按住左右拖看每一天、每一周）、30 天的格子和最近每一天、什么时候最容易做到、每个月

/// 日子的算法（「2026-10-18」+ 3 天、星期几）
enum GoalDays {
    private static let formatter: DateFormatter = {
        let out = DateFormatter()
        out.calendar = Calendar(identifier: .gregorian)
        out.locale = Locale(identifier: "en_US_POSIX")
        out.dateFormat = "yyyy-MM-dd"
        return out
    }()

    static func add(_ day: String, _ days: Int) -> String {
        guard let date = formatter.date(from: day),
            let next = Calendar(identifier: .gregorian).date(byAdding: .day, value: days, to: date)
        else { return day }
        return formatter.string(from: next)
    }

    /// 0 是周一
    static func weekday(_ day: String) -> Int {
        guard let date = formatter.date(from: day) else { return 0 }
        return (Calendar(identifier: .gregorian).component(.weekday, from: date) + 5) % 7
    }

    static func weekdayName(_ day: String) -> String { ["周一", "周二", "周三", "周四", "周五", "周六", "周日"][weekday(day)] }
}

/// 图：到一个数是应达和实际 + 预测带；平均、几次、不超过是按周的柱子；往下的是小曲线；每天的是 30 天的格子
struct GoalChartBlock: View {
    let page: API.GoalPage

    var body: some View {
        if let chart = page.chart {
            GoalSection(title: page.chartTitle ?? "", meta: page.chartMeta)
            VStack(alignment: .leading, spacing: Theme.Space.small) {
                switch chart.kind {
                case "line": line(chart)
                case "weeks": weeks(chart)
                case "curve": curve(chart)
                default: days(chart)
                }
            }
            .themeCard()
            if chart.kind == "line" {
                Text("预测带：最近 28 天里，慢的 14 天和快的 14 天各照着走到期末。应达只算到昨天，实际包含今天。")
                    .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel).fixedSize(
                        horizontal: false, vertical: true)
            }
            if let rows = page.days { lastDays(rows) }
        }
    }

    private func line(_ chart: API.GoalChart) -> some View {
        let actual = chart.actual ?? []
        let expected = chart.expected ?? []
        let today = chart.today ?? max(0, actual.count - 1)
        let unit = chart.unit ?? ""
        let from = chart.from ?? ""
        return GoalLineChart(
            actual: actual, expected: expected, today: today, slow: chart.slow, fast: chart.fast,
            target: chart.target ?? 1,
            behind: page.card.state == "behind", ticks: (chart.ticks ?? []).map { ($0.at, $0.text) }
        ) { picked in
            let index = picked ?? today
            let day = GoalDays.add(from, index)
            let should = expected.indices.contains(index) ? Show.fmtNum(expected[index].rounded()) : ""
            if index < today, actual.indices.contains(index) {
                let real = String(format: "%.1f", actual[index])
                return "\(Show.monthDay(day)) \(GoalDays.weekdayName(day))：实际 \(real) · 应达 \(should) \(unit)"
            }
            if index == today {
                let yesterday =
                    today > 0 && expected.indices.contains(today - 1) ? Show.fmtNum(expected[today - 1].rounded()) : "0"
                return "今天：实际 \(Show.fmtNum(actual.last ?? 0)) · 到昨天应达 \(yesterday) \(unit)"
            }
            guard let slow = chart.slow, let fast = chart.fast else {
                return "\(Show.monthDay(day))：应达 \(should) \(unit)"
            }
            let now = actual.last ?? 0
            let low = Int((now + slow * Double(index - today)).rounded())
            let high = Int((now + fast * Double(index - today)).rounded())
            return "\(Show.monthDay(day))：照最近的速度 \(low)–\(high) · 应达 \(should) \(unit)"
        }
    }

    private func weeks(_ chart: API.GoalChart) -> some View {
        let rows = chart.rows ?? []
        let format = { (value: Double) in Self.format(value, chart.format ?? "num", unit: chart.unit ?? "") }
        return WeekBarsChart(
            bars: rows.map {
                WeekBarsChart.Bar(
                    label: $0.label.replacingOccurrences(of: "月", with: "/").replacingOccurrences(of: "日", with: ""),
                    value: $0.value, current: $0.current)
            },
            line: chart.line, tint: chart.money == true ? Theme.Palette.warn : Theme.Palette.good
        ) { index in
            guard rows.indices.contains(index) else { return "" }
            let row = rows[index]
            let line = chart.line.map { " · \(chart.lineLabel ?? "目标") \(format($0))" } ?? ""
            let note = row.note.map { " · \($0)" } ?? ""
            return "\(row.label)\(row.note == nil ? " 那周" : "")：\(format(row.value))\(line)\(note)"
        }
    }

    /// 「7:24」「¥63」「4 次」「1.2 公里」
    static func format(_ value: Double, _ format: String, unit: String) -> String {
        switch format {
        case "hm":
            let minutes = Int((value * 60).rounded())
            return "\(minutes / 60):\(String(format: "%02d", minutes % 60))"
        case "yuan": return "¥\(Show.fmtNum(value))"
        case "count": return "\(Show.fmtNum(value)) 次"
        default: return "\(Show.fmtNum(value)) \(unit)".trimmingCharacters(in: .whitespaces)
        }
    }

    @ViewBuilder private func curve(_ chart: API.GoalChart) -> some View {
        if let title = chart.title { Text(title).font(Theme.Typeface.body).monospacedDigit() }
        SmallCurve(
            points: (chart.points ?? []).map { ($0.label, $0.value) },
            tint: page.card.state == "behind" ? Theme.Palette.warn : Theme.Palette.good)
        if let sub = chart.sub {
            Text(sub).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel).fixedSize(
                horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private func days(_ chart: API.GoalChart) -> some View {
        let cells = chart.cells ?? []
        MonthCells(
            cells: cells.map {
                MonthCells.Cell(day: $0.day, mark: $0.mark, weekday: GoalDays.weekday(cells.first?.day ?? $0.day))
            })
        Text("实心 = 做到 · 空心带点 = 用了补假 · 留白 = 没做到 · 虚线 = 今天").font(Theme.Typeface.footnote)
            .foregroundStyle(Theme.Palette.secondaryLabel).fixedSize(horizontal: false, vertical: true)
    }

    /// 最近每一天（来自健康 App 的写「来自健康 App，不用说」）：步数 + 做到 / 用了补假 / 没做到 / 今天还没完
    @ViewBuilder private func lastDays(_ rows: [API.GoalPage.DayRow]) -> some View {
        GoalSection(title: "最近每一天", meta: page.daysNote)
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 { Divider() }
                HStack {
                    Text(row.label).font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(
                        Theme.Palette.secondaryLabel
                    )
                    .frame(minWidth: Theme.Size.goalCard / 2, alignment: .leading)
                    Text(row.value).font(Theme.Typeface.body).monospacedDigit()
                    Spacer()
                    Text(MonthCells.markName(row.mark)).font(Theme.Typeface.caption)
                        .foregroundStyle(row.mark == "done" ? Theme.Palette.good : Theme.Palette.secondaryLabel)
                        .padding(.horizontal, Theme.Space.small).padding(.vertical, Theme.Space.hairline)
                        .background(row.mark == "done" ? Theme.Palette.goodFill : Theme.Palette.fill, in: Capsule())
                }
                .frame(minHeight: Theme.Size.touch)
            }
        }
        .padding(.horizontal, Theme.Space.inset)
        .themeCard(padding: 0)
    }
}

/// 什么时候最容易做到：七天 × 早中晚的格子 + 一句 +「把提醒放在周六 08:00」（马上改提醒，能撤销）
struct GoalBestBlock: View {
    @Environment(AppModel.self) private var model
    let goalId: Int
    let best: API.BestTimes

    var body: some View {
        GoalSection(title: "什么时候最容易做到", meta: "一周七天 × 早中晚")
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            WhenGrid(grid: best.grid)
            Text(best.text).font(Theme.Typeface.body).fixedSize(horizontal: false, vertical: true)
            if let suggest = best.suggest {
                Button {
                    model.goalSet(goalId, GoalChange(remind: .some(suggest.remind)))
                } label: {
                    Label(suggest.label, systemImage: "bell").font(Theme.Typeface.subheadline)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("goal.best.remind")
            } else if let already = best.already {
                Text(already).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            }
        }
        .themeCard()
        Text("格子里的数是那个时段做了几次，从你说的话里的时间算；没说时间的按记下的时间。")
            .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel).fixedSize(
                horizontal: false, vertical: true)
    }
}

/// 每个月（年目标拆到月）：点数字原地改（数字键盘，回车或点别处），改过的「已调整 · 恢复自动」；过去的月份不能改；
/// 这个月能展开看每一周
struct GoalMonthsBlock: View {
    @Environment(AppModel.self) private var model
    let goalId: Int
    let months: [API.SubPeriod]
    let unit: String
    @State private var editing: String?
    @State private var draft = ""
    @State private var open = false
    @FocusState private var focused: Bool

    var body: some View {
        GoalSection(title: "每个月", meta: "点数字改")
        VStack(spacing: 0) {
            ForEach(Array(months.enumerated()), id: \.element.id) { index, month in
                if index > 0 { Divider() }
                row(month)
                if month.current && open, let weeks = month.weeks {
                    VStack(spacing: Theme.Space.tight) {
                        ForEach(weeks) { week in
                            HStack {
                                Text(week.label).font(Theme.Typeface.footnote)
                                Spacer()
                                Text("实际 \(Show.fmtNum(week.progress.actual))").font(Theme.Typeface.footnote)
                                    .monospacedDigit()
                                Text("\(Show.fmtNum(week.target.rounded())) \(unit)").font(
                                    Theme.Typeface.footnoteSemibold
                                ).monospacedDigit()
                                    .frame(minWidth: Theme.Size.touch * 1.5, alignment: .trailing)
                            }
                            .foregroundStyle(Theme.Palette.secondaryLabel)
                        }
                    }
                    .padding(Theme.Space.small)
                    .background(
                        Theme.Palette.fill, in: RoundedRectangle(cornerRadius: Theme.Corner.chip, style: .continuous)
                    )
                    .padding(.bottom, Theme.Space.small)
                }
            }
        }
        .padding(.horizontal, Theme.Space.inset)
        .themeCard(padding: 0)
        Text("点数字改某个月；没改过的月份自动重新分。点这个月看每一周。").font(Theme.Typeface.footnote)
            .foregroundStyle(Theme.Palette.secondaryLabel)
    }

    private func row(_ month: API.SubPeriod) -> some View {
        HStack(spacing: Theme.Space.medium) {
            Button {
                if month.current { withAnimation(Theme.Motion.standard) { open.toggle() } }
            } label: {
                HStack(spacing: Theme.Space.tight) {
                    Text(month.label).font(Theme.Typeface.body)
                    if month.current {
                        Image(systemName: open ? "chevron.down" : "chevron.right").font(Theme.Typeface.footnote)
                    }
                }
                .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                Text(
                    month.progress.ended || month.current
                        ? "实际 \(Show.fmtNum(month.progress.actual)) \(unit)\(month.current ? "（到今天）" : "")" : "还没到"
                )
                .font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
                if month.locked {
                    LinkButton("已调整 · 恢复自动", identifier: "goal.month.auto.\(month.key)") {
                        model.adjustMonth(goalId, month: month.key, target: nil)
                    }
                }
            }
            Spacer()
            if editing == month.key {
                TextField("", text: $draft).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .font(Theme.Typeface.rowNumber).focused($focused).frame(maxWidth: Theme.Size.touch * 2)
                    .onSubmit { save(month) }
                    .onChange(of: focused) { _, now in if !now { save(month) } }
                    .accessibilityIdentifier("goal.month.field")
            } else {
                Button("\(Show.fmtNum(month.target.rounded())) \(unit)") {
                    guard !month.progress.ended else {
                        model.toast("\(month.label)已经过去了，不能改")
                        return
                    }
                    draft = Show.fmtNum(month.target.rounded())
                    editing = month.key
                    focused = true
                }
                .font(Theme.Typeface.rowNumber).monospacedDigit().buttonStyle(.bordered)
                .tint(month.locked ? Theme.Palette.accent : Theme.Palette.secondaryLabel)
                .accessibilityIdentifier("goal.month.\(month.key)")
            }
        }
        .frame(minHeight: Theme.Size.touch + Theme.Space.small)
    }

    private func save(_ month: API.SubPeriod) {
        guard editing == month.key else { return }
        editing = nil
        guard let value = Double(draft), value >= 0, value.rounded() != month.target.rounded() else { return }
        model.adjustMonth(goalId, month: month.key, target: value)
    }
}
