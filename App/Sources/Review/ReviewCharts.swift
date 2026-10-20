import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 一周的样子（网页版 WeekStrip）：七行，每行从前一晚 9 点画到半夜（最左边是那一觉），和画布同一种色块；
/// 共用一条刻度；点一行打开那天的回顾
struct WeekStrip: View {
    @Environment(AppModel.self) private var model
    let days: [API.PeriodDay]
    let entries: [API.Entry]
    let open: (String) -> Void

    /// 前一晚 9 点到半夜：27 个小时
    private static let span = 27 * 60
    private static let ticks = [0, 6, 12, 18, 24]

    var body: some View {
        VStack(alignment: .leading, spacing: Web.space3) {
            VStack(spacing: 0) {
                row(label: "", mood: "") { tickTrack }.frame(minHeight: Web.space6).accessibilityHidden(true)
                ForEach(days, id: \.day) { day in
                    if day.recorded {
                        Button {
                            open(day.day)
                        } label: {
                            row(label: Show.weekRowLabel(day.day), mood: day.mood ?? "") { blocks(day.day) }
                        }
                        .buttonStyle(WebPressStyle(radius: Web.radiusControl))
                        .padding(.horizontal, -Web.space2)
                        .accessibilityLabel(Text(spoken(day)))
                    } else {
                        row(label: Show.weekRowLabel(day.day), mood: "—", empty: true) { track }
                            .padding(.horizontal, -Web.space2)
                    }
                }
            }
            legend
            Text("每一行是一天，从前一晚 9 点画到半夜，最左边是那一觉；没说几点的事不画。点一行打开那天的回顾。")
                .font(Web.caption).foregroundStyle(Web.fgTertiary)
        }
    }

    /// 读屏念的：「10月12日 周一，一般：打开那天的回顾」
    private func spoken(_ day: API.PeriodDay) -> String {
        "\(Show.dayTitle(day.day, today: model.today))\(day.mood.map { "，\($0)" } ?? "")：打开那天的回顾"
    }

    private func row<Track: View>(label: String, mood: String, empty: Bool = false, @ViewBuilder track: () -> Track)
        -> some View
    {
        HStack(spacing: Web.space3) {
            // 两边的字不截：字号调大了就占宽一点，中间的轴让出来
            Text(label).font(Web.caption).foregroundStyle(empty ? Web.fgTertiary : Web.fgSecondary).fixedSize()
                .frame(minWidth: Web.space12 + Web.space2, alignment: .leading)
            track().frame(height: Web.space6)
            Text(mood).font(Web.caption).foregroundStyle(Web.fgTertiary).fixedSize()
                .frame(minWidth: Web.space16, alignment: .trailing)
        }
        .padding(.horizontal, Web.space2)
        .frame(minHeight: Web.touch)
        .contentShape(Rectangle())
    }

    private var track: some View {
        Rectangle().fill(Web.line).frame(height: 1).frame(maxWidth: .infinity)
    }

    private var tickTrack: some View {
        GeometryReader { proxy in
            ForEach(Self.ticks, id: \.self) { hour in
                let place = Double(hour + 3) / 27
                Text("\(hour)").font(Web.caption).foregroundStyle(Web.fgTertiary).monospacedDigit().fixedSize()
                    .alignmentGuide(.leading) { size in
                        place < 0.05
                            ? -place * proxy.size.width
                            : place > 0.95
                                ? size.width - place * proxy.size.width : size.width / 2 - place * proxy.size.width
                    }
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
                        .frame(width: max(block.width * width, width * 0.008), height: Web.space2)
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
            guard entry.day == day, case .event(let event) = entry.data, let from = event.start ?? event.end,
                let until = event.end ?? event.start
            else { return nil }
            let begin = PourDate.minutesBetween(start, from)
            let end = PourDate.minutesBetween(start, until)
            guard end >= 0, begin <= Self.span else { return nil }
            let left = Double(max(0, begin)) / Double(Self.span)
            let right = Double(min(Self.span, end)) / Double(Self.span)
            return Block(id: entry.id, left: left, width: right - left, color: color(entry))
        }
    }

    private func color(_ entry: API.Entry) -> Color { Web.tag(Show.meta(entry.category, model.categories).color).solid }

    /// 图例：这一周画到的事是哪些领域
    @ViewBuilder private var legend: some View {
        let items = legendItems
        if !items.isEmpty {
            PourFlowLayout(spacing: Web.space4, lineSpacing: Web.space1) {
                ForEach(items, id: \.name) { item in
                    HStack(spacing: Web.space1) {
                        Circle().fill(item.color).frame(width: Web.space2, height: Web.space2).padding(
                            .trailing, Web.space1)
                        Text(item.name)
                    }
                }
            }
            .font(Web.caption).foregroundStyle(Web.fgTertiary)
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

/// 一个月的样子（网页版 MonthGrid）：一张月历，每天一格按心情上色；点一格打开那天的回顾；下面一行打开每一周的周报
struct MonthGrid: View {
    @Environment(AppModel.self) private var model
    let days: [API.PeriodDay]
    let weeklyReports: [String]
    let navigate: (String) -> Void

    /// 很差最浅、很好最深（强调色的深浅）
    private static let shades = [0.12, 0.26, 0.42, 0.64, 1.0]

    var body: some View {
        VStack(alignment: .leading, spacing: Web.space3) {
            let columns = Array(repeating: GridItem(.flexible(), spacing: Web.space1), count: 7)
            LazyVGrid(columns: columns, spacing: Web.space1) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) {
                    Text($0).font(Web.caption).foregroundStyle(Web.fgTertiary).accessibilityHidden(true)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    if let cell { self.cell(cell) } else { Color.clear.frame(height: Web.space12) }
                }
            }
            legend
            if !weeklyReports.isEmpty {
                PourFlowLayout(spacing: Web.space2, lineSpacing: 0) {
                    Text("每一周的周报：").foregroundStyle(Web.fgTertiary).frame(minHeight: Web.touch)
                    ForEach(weeklyReports.sorted(), id: \.self) { monday in
                        WebTextButton("\(GoalChart.monthDay(monday))那周", font: Web.captionMedium) {
                            navigate(Show.reportPath("weekly", from: monday))
                        }
                        .frame(minHeight: Web.touch)
                    }
                }
                .font(Web.caption)
            }
        }
    }

    /// 前面空出这个月 1 号之前的格子，后面补满一行
    private var cells: [API.PeriodDay?] {
        guard let first = days.first?.day else { return [] }
        var out: [API.PeriodDay?] = Array(repeating: nil, count: PourDate.weekdayMon0(first)) + days
        while out.count % 7 != 0 { out.append(nil) }
        return out
    }

    @ViewBuilder private func cell(_ day: API.PeriodDay) -> some View {
        let number = Int(day.day.suffix(2)) ?? 0
        if !day.recorded {
            box(number, fill: .clear, text: Web.fgTertiary)
                .overlay(RoundedRectangle(cornerRadius: Web.radiusControl).strokeBorder(Web.line, lineWidth: 1))
                .accessibilityLabel(Text("\(Show.dayTitle(day.day, today: model.today))，没有记录"))
        } else {
            let shade = day.level.map { Self.shades[min(5, max(1, Int($0.rounded()))) - 1] }
            Button {
                navigate("/review/\(day.day)")
            } label: {
                box(
                    number, fill: shade.map { Web.accent.opacity($0) } ?? Web.tag("gray").bg,
                    text: shade == 1 ? Web.bg : Web.fg)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                Text("\(Show.dayTitle(day.day, today: model.today))，\(day.mood ?? "没说心情")：打开那天的回顾"))
        }
    }

    private func box(_ number: Int, fill: Color, text: Color) -> some View {
        Text("\(number)").font(Web.caption).foregroundStyle(text).monospacedDigit()
            .padding(.vertical, Web.space1).padding(.horizontal, Web.space2)
            .frame(maxWidth: .infinity, minHeight: Web.space12, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: Web.radiusControl).fill(fill))
    }

    private var legend: some View {
        PourFlowLayout(spacing: Web.space4, lineSpacing: Web.space1) {
            HStack(spacing: Web.space1) {
                Text("很差")
                ForEach(Self.shades, id: \.self) { shade in swatch(Web.accent.opacity(shade)) }
                Text("很好")
            }
            HStack(spacing: Web.space1) {
                swatch(Web.tag("gray").bg)
                Text("记了，没说心情")
            }
        }
        .font(Web.caption).foregroundStyle(Web.fgTertiary)
        .accessibilityElement(children: .combine)
    }

    private func swatch(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: Web.radiusControl).fill(color).frame(width: Web.space3, height: Web.space3)
    }
}
