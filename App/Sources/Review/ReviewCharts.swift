import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 一周的样子（周报整页）：七行，每行从前一晚 9 点画到半夜（最左边是那一觉），和画布同一种类别色；
/// 上面一排刻度（21 点、0 点、6 点、12 点、18 点、24 点）；点一行打开那天的回顾
struct WeekStrip: View {
    @Environment(AppModel.self) private var model
    let days: [API.PeriodDay]
    let entries: [API.Entry]
    let open: (String) -> Void

    /// 前一晚 9 点到半夜：27 个小时
    private static let span = 27.0 * 60
    private static let ticks = [0, 6, 12, 18, 24]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            row(label: "", mood: "") { tickTrack }.accessibilityHidden(true)
            ForEach(days, id: \.day) { day in
                if day.recorded {
                    Button {
                        open(day.day)
                    } label: {
                        row(label: Show.weekRowLabel(day.day), mood: day.mood ?? "") { blocks(day.day) }
                    }
                    .buttonStyle(PressScale())
                    .accessibilityLabel(Text(spoken(day)))
                } else {
                    row(label: Show.weekRowLabel(day.day), mood: "—") { track }.opacity(0.6)
                }
            }
            legend.padding(.top, Theme.Space.small)
            Text("每一行是一天，从前一晚 9 点画到半夜，最左边是那一觉；没说几点的事不画。点一行打开那天的回顾。")
                .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 读屏念的：「10月12日 周一，一般：打开那天的回顾」
    private func spoken(_ day: API.PeriodDay) -> String {
        "\(Show.dayTitle(day.day, today: model.today))\(day.mood.map { "，\($0)" } ?? "")：打开那天的回顾"
    }

    private func row<Track: View>(label: String, mood: String, @ViewBuilder track: () -> Track) -> some View {
        HStack(spacing: Theme.Space.small) {
            Text(label).font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(Theme.Palette.label)
                .fixedSize().frame(minWidth: Theme.Size.touch + Theme.Space.small, alignment: .leading)
            track().frame(height: Theme.Size.tickRow)
            Text(mood).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel).fixedSize()
                .frame(minWidth: Theme.Size.touch + Theme.Space.medium, alignment: .trailing)
        }
        .frame(minHeight: Theme.Size.touch)
        .contentShape(Rectangle())
    }

    private var track: some View {
        Capsule().fill(Theme.Palette.fill).frame(height: Theme.Size.bar).frame(maxWidth: .infinity)
    }

    /// 刻度：每个数字摆在它那个小时的位置上（两头的不出界）
    private var tickTrack: some View {
        GeometryReader { proxy in
            ForEach(Self.ticks, id: \.self) { hour in
                let place = Double(hour + 3) / 27
                Text("\(hour)").font(Theme.Typeface.tick).foregroundStyle(Theme.Palette.secondaryLabel)
                    .monospacedDigit().fixedSize()
                    .position(
                        x: min(max(place * proxy.size.width, Theme.Space.tight), proxy.size.width - Theme.Space.tight),
                        y: proxy.size.height / 2)
            }
        }
    }

    /// 这一天的色块：从前一晚 9 点算起
    private func blocks(_ day: String) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                track
                ForEach(spans(day), id: \.id) { block in
                    Capsule().fill(block.color)
                        .frame(width: max(block.width * width, Theme.Size.bar / 2), height: Theme.Size.bar)
                        .offset(x: block.left * width)
                }
            }
            .frame(height: proxy.size.height)
        }
    }

    private struct Block {
        let id: Int
        let left: Double
        let width: Double
        let color: Color
    }

    private func spans(_ day: String) -> [Block] {
        let start = "\(PourDate.addDays(day, -1))T21:00"
        return entries.compactMap { entry in
            guard entry.day == day, case .event(let event) = entry.data, let from = event.start ?? event.end else {
                return nil
            }
            let until = event.end ?? from
            let begin = Double(PourDate.minutesBetween(start, from))
            let end = Double(PourDate.minutesBetween(start, until))
            guard end >= 0, begin <= Self.span else { return nil }
            let left = max(0, begin) / Self.span
            let right = min(Self.span, end) / Self.span
            return Block(id: entry.id, left: left, width: right - left, color: color(entry))
        }
    }

    private func color(_ entry: API.Entry) -> Color {
        Theme.tag(Show.meta(entry.category, model.categories).color).solid
    }

    /// 图例：这一周画到的事是哪些领域
    @ViewBuilder private var legend: some View {
        let items = legendItems
        if !items.isEmpty {
            PourFlowLayout(spacing: Theme.Space.regular, lineSpacing: Theme.Space.tight) {
                ForEach(items, id: \.name) { item in
                    HStack(spacing: Theme.Space.tight) {
                        Circle().fill(item.color).frame(width: Theme.Size.dot, height: Theme.Size.dot)
                        Text(item.name)
                    }
                }
            }
            .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            .accessibilityElement(children: .combine)
        }
    }

    private var legendItems: [(name: String, color: Color)] {
        let drawn = Set(days.flatMap { spans($0.day).map(\.id) })
        var out: [(name: String, color: Color)] = []
        for entry in entries where drawn.contains(entry.id) {
            let name = Show.meta(Show.group(entry, model.categories), model.categories).name
            if !out.contains(where: { $0.name == name }) { out.append((name, color(entry))) }
        }
        return out
    }
}

/// 一个月的样子（月报整页）：月历每格那天的表情（没说心情写日子、没记的淡一点）；点一格打开那天的回顾；
/// 下面一行打开每一周的周报
struct MonthGrid: View {
    @Environment(AppModel.self) private var model
    let days: [API.PeriodDay]
    let weeklyReports: [String]
    let navigate: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.Space.tight), count: 7)
            LazyVGrid(columns: columns, spacing: Theme.Space.small) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) {
                    Text($0).font(Theme.Typeface.caption).foregroundStyle(Theme.Palette.secondaryLabel)
                        .accessibilityHidden(true)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    if let cell { self.cell(cell) } else { Color.clear.frame(height: Theme.Size.touch) }
                }
            }
            if !weeklyReports.isEmpty {
                PourFlowLayout(spacing: Theme.Space.small, lineSpacing: Theme.Space.small) {
                    Text("每一周的周报").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                        .frame(minHeight: Theme.Size.touch)
                    ForEach(weeklyReports.sorted(), id: \.self) { monday in
                        FilterChip("\(Show.monthDay(monday))那周", selected: false) {
                            navigate(Show.reportPath("weekly", from: monday))
                        }
                    }
                }
            }
        }
    }

    /// 前面空出这个月 1 号之前的格子
    private var cells: [API.PeriodDay?] {
        guard let first = days.first?.day else { return [] }
        return Array(repeating: nil, count: PourDate.weekdayMon0(first)) + days
    }

    @ViewBuilder private func cell(_ day: API.PeriodDay) -> some View {
        let number = Int(day.day.suffix(2)) ?? 0
        let spoken = "\(Show.dayTitle(day.day, today: model.today))，\(day.mood ?? (day.recorded ? "没说心情" : "没有记录"))"
        if day.recorded {
            Button {
                navigate("/review/\(day.day)")
            } label: {
                Group {
                    if let level = day.level {
                        MoodBadge(level: Int(level.rounded()), size: Theme.Size.capsule)
                    } else {
                        Text("\(number)").font(Theme.Typeface.footnote).monospacedDigit()
                            .foregroundStyle(Theme.Palette.label)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScale())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(spoken)：打开那天的回顾"))
            .accessibilityAddTraits(.isButton)
        } else {
            Text("\(number)").font(Theme.Typeface.footnote).monospacedDigit()
                .foregroundStyle(Theme.Palette.tertiaryLabel)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
                .accessibilityLabel(Text(spoken))
        }
    }
}
