public import SwiftUI

// 3.0 目标的组件（docs/3.0/01-需求文档.md 第 9 章、06 交互细节第 12 节、07 开发任务清单 7.8）：
// 14 天的格子、30 天的格子、七天 × 早中晚、在乎和投入的两条、单选回答卡。颜色只有正轨绿，不用红

// MARK: - 14 天的格子（坚持的一行）

/// 最近 14 天：做到实心、用了补假空心带点、没做到留白（不用红）；今天虚线；每周几次的只标做了的天
public struct DayCells: View {
    let marks: [String]
    let size: CGFloat

    public init(marks: [String], size: CGFloat = Theme.Size.dayCell) {
        self.marks = marks
        self.size = size
    }

    public var body: some View {
        HStack(spacing: Theme.Space.hairline) {
            ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in
                DayCell(mark: mark, size: size)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Self.spoken(marks)))
    }

    /// 「最近 14 天：11 天做到，2 天用了补假，1 天没做到」
    public static func spoken(_ marks: [String]) -> String {
        let count = { (mark: String) in marks.filter { $0 == mark }.count }
        var parts = ["\(count("done")) 天做到"]
        if count("rest") > 0 { parts.append("\(count("rest")) 天用了补假") }
        if count("miss") > 0 { parts.append("\(count("miss")) 天没做到") }
        return "最近 \(marks.count) 天：" + parts.joined(separator: "，")
    }
}

/// 一格：做到 · 补假 · 没做到 · 今天 · 暂停 · 还没开始
public struct DayCell: View {
    let mark: String
    let size: CGFloat
    let number: String?

    public init(mark: String, size: CGFloat = Theme.Size.dayCell, number: String? = nil) {
        self.mark = mark
        self.size = size
        self.number = number
    }

    private var radius: CGFloat { size > Theme.Size.dayCell * 2 ? Theme.Corner.chip : Theme.Corner.bar }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            switch mark {
            case "done": shape.fill(Theme.Palette.good)
            case "rest":
                shape.strokeBorder(Theme.Palette.good, lineWidth: 1.5)
                if number == nil {
                    Circle().fill(Theme.Palette.good).frame(width: size / 3.5, height: size / 3.5)
                }
            case "today":
                shape.strokeBorder(Theme.Palette.tertiaryLabel, style: StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
            case "before", "paused": shape.fill(Theme.Palette.fill.opacity(0.5))
            default: shape.strokeBorder(Theme.Palette.separator, lineWidth: 1.5)
            }
            if let number {
                VStack(spacing: Theme.Space.hairline / 2) {
                    Text(number).font(Theme.Typeface.footnoteSemibold).monospacedDigit()
                        .foregroundStyle(mark == "done" ? Theme.Palette.onAccent : Theme.Palette.secondaryLabel)
                    if mark == "rest" {
                        Circle().fill(Theme.Palette.good).frame(width: Theme.Space.tight, height: Theme.Space.tight)
                    }
                }
            }
        }
        .frame(width: number == nil ? size : nil, height: size)
        .frame(maxWidth: number == nil ? nil : .infinity)
    }
}

/// 图例一行：■ 做到 ▣ 补假 □ 没做到
public struct DayCellLegend: View {
    public init() {}

    public var body: some View {
        HStack(spacing: Theme.Space.medium) {
            item("done", "做到")
            item("rest", "补假")
            item("miss", "没做到")
        }
        .accessibilityElement(children: .combine)
    }

    private func item(_ mark: String, _ text: String) -> some View {
        HStack(spacing: Theme.Space.tight) {
            DayCell(mark: mark, size: Theme.Size.dayCell - 2)
            Text(text).font(Theme.Typeface.tick).foregroundStyle(Theme.Palette.secondaryLabel)
        }
    }
}

// MARK: - 30 天的格子（像月历）

/// 每天达到的最近 30 天：一二三四五六日，每格写几号；做到绿底白字、补假绿框带点、没做到空的、今天虚线
public struct MonthCells: View {
    public struct Cell: Hashable, Sendable {
        public var day: String
        public var mark: String
        public var weekday: Int

        public init(day: String, mark: String, weekday: Int) {
            self.day = day
            self.mark = mark
            self.weekday = weekday
        }
    }

    let cells: [Cell]

    public init(cells: [Cell]) {
        self.cells = cells
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.Space.snug), count: 7)

    public var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.Space.snug) {
            ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { name in
                Text(name).font(Theme.Typeface.tick).foregroundStyle(Theme.Palette.secondaryLabel)
            }
            ForEach(0..<(cells.first?.weekday ?? 0), id: \.self) { _ in Color.clear.frame(height: Theme.Size.monthCell)
            }
            ForEach(cells, id: \.day) { cell in
                DayCell(mark: cell.mark, size: Theme.Size.monthCell, number: String(Int(cell.day.suffix(2)) ?? 0))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("\(Int(cell.day.suffix(2)) ?? 0) 号，\(Self.markName(cell.mark))"))
            }
        }
    }

    public static func markName(_ mark: String) -> String {
        ["done": "做到", "rest": "用了补假", "miss": "没做到", "today": "今天还没完", "paused": "暂停", "before": "还没开始"][mark] ?? ""
    }
}

// MARK: - 什么时候最容易做到（七天 × 早中晚）

/// 七天 × 早中晚：格子里写几次，越多越深
public struct WhenGrid: View {
    let grid: [[Int]]

    public init(grid: [[Int]]) {
        self.grid = grid
    }

    private static let parts = ["早上", "下午", "晚上"]
    private static let days = ["一", "二", "三", "四", "五", "六", "日"]

    public var body: some View {
        let most = max(1, grid.flatMap { $0 }.max() ?? 1)
        Grid(horizontalSpacing: Theme.Space.tight, verticalSpacing: Theme.Space.tight) {
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                ForEach(Self.days, id: \.self) { day in
                    Text(day).font(Theme.Typeface.tick).foregroundStyle(Theme.Palette.secondaryLabel)
                }
            }
            ForEach(0..<3, id: \.self) { part in
                GridRow {
                    Text(Self.parts[part]).font(Theme.Typeface.tick).foregroundStyle(Theme.Palette.secondaryLabel)
                        .fixedSize()
                    ForEach(0..<7, id: \.self) { day in
                        let count = grid.indices.contains(day) && grid[day].indices.contains(part) ? grid[day][part] : 0
                        let strong = Double(count) / Double(most) > 0.5
                        RoundedRectangle(cornerRadius: Theme.Corner.chip, style: .continuous)
                            .fill(
                                count > 0
                                    ? Theme.Palette.good.opacity(0.18 + Double(count) / Double(most) * 0.72)
                                    : Theme.Palette.fill
                            )
                            .frame(height: Theme.Size.whenCell)
                            .overlay {
                                if count > 0 {
                                    Text("\(count)").font(Theme.Typeface.footnoteSemibold).monospacedDigit()
                                        .foregroundStyle(strong ? Theme.Palette.onAccent : Theme.Palette.label)
                                }
                            }
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spoken))
    }

    private var spoken: String {
        var out: [String] = []
        for day in grid.indices {
            for part in grid[day].indices where grid[day][part] > 0 {
                out.append("周\(Self.days[day])\(Self.parts[part]) \(grid[day][part]) 次")
            }
        }
        return out.isEmpty ? "还没有记录" : out.joined(separator: "，")
    }
}

// MARK: - 在乎和投入

/// 一块一行、两根条：打的分（蓝，1–10）、最近 30 天花的时间（灰）；这一块加粗，别的条淡一点（字不淡：要看得清）
public struct InvestRow: View {
    let name: String
    let score: Int?
    let value: String
    let time: Double
    let mine: Bool

    /// time：0–1（和花得最多的那块比）
    public init(name: String, score: Int?, value: String, time: Double, mine: Bool) {
        self.name = name
        self.score = score
        self.value = value
        self.time = time
        self.mine = mine
    }

    public var body: some View {
        HStack(alignment: .center, spacing: Theme.Space.medium) {
            Text(name).font(mine ? Theme.Typeface.bodySemibold : Theme.Typeface.body)
                .foregroundStyle(mine ? Theme.Palette.label : Theme.Palette.secondaryLabel)
                .frame(minWidth: Theme.Size.touch, alignment: .leading)
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                bar(Double(score ?? 0) / 10, color: Theme.Palette.accent, text: score.map { "\($0) 分" } ?? "没打分")
                bar(time, color: Theme.Palette.tertiaryLabel, text: value)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(name)：\(score.map { "打了 \($0) 分" } ?? "没打分")，\(value)"))
    }

    private func bar(_ share: Double, color: Color, text: String) -> some View {
        HStack(spacing: Theme.Space.small) {
            GeometryReader { geo in
                Capsule().fill(Theme.Palette.fill)
                    .overlay(alignment: .leading) {
                        Capsule().fill(color).opacity(mine ? 1 : 0.5)
                            .frame(width: max(Theme.Size.bar, geo.size.width * min(1, max(0, share))))
                    }
            }
            .frame(height: Theme.Size.bar)
            Text(text).font(Theme.Typeface.tick).monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
                .fixedSize()
        }
    }
}

// MARK: - 单选回答卡（WOOP、GROW 里的现成回答）

/// 一个现成的回答（宋体）：左边单选圆；下面「从哪句话来 ›」点了展开那句原话和日子，或者「怎么想到的 ›」
public struct ChoiceCard: View {
    let text: String
    let selected: Bool
    let source: (text: String, when: String)?
    let how: String?
    let identifier: String
    let pick: () -> Void
    @State private var open = false

    public init(
        text: String, selected: Bool, source: (text: String, when: String)?, how: String?, identifier: String,
        pick: @escaping () -> Void
    ) {
        self.text = text
        self.selected = selected
        self.source = source
        self.how = how
        self.identifier = identifier
        self.pick = pick
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Button(action: pick) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.medium) {
                    Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                        .font(Theme.Typeface.bodyMedium)
                        .foregroundStyle(selected ? Theme.Palette.accent : Theme.Palette.tertiaryLabel)
                    Text(text).font(Theme.Typeface.quote).foregroundStyle(Theme.Palette.label)
                        .lineSpacing(Theme.Leading.quote / 2).multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier(identifier)
            if source != nil || how != nil {
                Button {
                    withAnimation(Theme.Motion.standard) { open.toggle() }
                } label: {
                    HStack(spacing: Theme.Space.tight) {
                        Text(source != nil ? "从哪句话来" : "怎么想到的")
                        Image(systemName: open ? "chevron.down" : "chevron.right")
                    }
                    .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.accent)
                    .frame(minHeight: Theme.Size.touch, alignment: .leading).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, Theme.Space.xLarge + Theme.Space.tight)
                .accessibilityIdentifier("\(identifier).why")
                if open {
                    Group {
                        if let source {
                            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                                Text(source.text).font(Theme.Typeface.quote).foregroundStyle(Theme.Palette.label)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("\(source.when) 你说的").font(Theme.Typeface.footnote).foregroundStyle(
                                    Theme.Palette.secondaryLabel)
                            }
                        } else if let how {
                            Text(how).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.leading, Theme.Space.xLarge + Theme.Space.tight)
                    .transition(.opacity)
                }
            }
        }
        .padding(Theme.Space.inset)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Corner.smallCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Corner.smallCard, style: .continuous)
                .strokeBorder(selected ? Theme.Palette.accent : Color.clear, lineWidth: 2)
        }
    }
}

// MARK: - 预览

private let previewMarks: [Int: String] = [13: "rest", 14: "rest", 15: "miss", 30: "today"]
private let previewMonth: [MonthCells.Cell] = (0..<31).map { index in
    MonthCells.Cell(day: String(format: "2026-10-%02d", index + 1), mark: previewMarks[index] ?? "done", weekday: 3)
}

#Preview("坚持的格子") {
    VStack(alignment: .leading, spacing: Theme.Space.large) {
        DayCells(marks: [
            "rest", "rest", "miss", "done", "done", "done", "done", "done", "done", "done", "done", "done", "rest",
            "today",
        ])
        DayCellLegend()
        MonthCells(cells: previewMonth)
        WhenGrid(grid: [[0, 0, 0], [0, 0, 1], [0, 0, 2], [0, 0, 1], [0, 0, 0], [2, 0, 0], [3, 0, 0]])
        InvestRow(name: "关系", score: 9, value: "10 小时 10 分", time: 0.45, mine: true)
        ChoiceCard(
            text: "体检那几项回到正常", selected: true, source: ("体检报告出来了 血压有点高", "10月1日"), how: nil, identifier: "preview"
        ) {}
    }
    .padding()
    .background(Theme.Palette.background)
}

extension Theme {
    /// 「我在乎的」各块的颜色（照原型 CARE：健康绿、钱琥珀、成长青、关系粉；自己加的星星金色）：小环里的图标、
    /// 每一组小标题前面的图标（服务器给的图标名 → 颜色）
    public static func careColor(_ icon: String) -> Color {
        switch icon {
        case "heart": Tokens.one(0x2E9A6B).color
        case "yen": Tile.amber
        case "book": Tokens.one(0x3E8E7E).color
        case "people": Tokens.one(0xCF5786).color
        case "star": Tile.gold
        default: Palette.secondaryLabel
        }
    }
}
