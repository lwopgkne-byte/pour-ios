import Charts
public import SwiftUI

// 3.0 钱的主页上的两样（06 交互细节 3.1、3.2）：每天累计的曲线（这个月实线、上个月同日虚线，按住拖动看每一天）、
// 月历（每一格直接写那天花了多少，背景深浅只做辅助）

/// 每天累计的曲线：第 i 个点是 1 号到 i+1 号一共多少。按住以后左右拖，上面写那一天这个月、上个月各是多少；
/// 松手回到最后一天。按住才拖（不挡页面上下滚）
public struct PaceChart: View {
    let current: [Double]
    let previous: [Double]?
    /// 一个月几天（横轴到几号）
    let days: Int
    /// 钱怎么写（遮住金额时是「¥•••」）
    let money: (Double) -> String
    /// 第几天叫什么（「10月20日」）
    let dayName: (Int) -> String
    @State private var picked: Int?

    public init(
        current: [Double], previous: [Double]?, days: Int, money: @escaping (Double) -> String,
        dayName: @escaping (Int) -> String
    ) {
        self.current = current
        self.previous = previous
        self.days = days
        self.money = money
        self.dayName = dayName
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Text(caption).font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
                .lineLimit(2).contentTransition(.numericText())
            chart
                .frame(height: Theme.Size.curve * 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("每天累计"))
        .accessibilityValue(Text(summary))
        .accessibilityAdjustableAction { direction in
            let last = max(0, current.count - 1)
            let now = picked ?? last
            switch direction {
            case .increment: picked = min(last, now + 1)
            case .decrement: picked = max(0, now - 1)
            @unknown default: break
            }
        }
    }

    private var chart: some View {
        Chart {
            if let previous {
                ForEach(Array(previous.enumerated()), id: \.offset) { index, value in
                    LineMark(x: .value("几号", index + 1), y: .value("钱", value), series: .value("月", "上个月"))
                        .foregroundStyle(Theme.Palette.tertiaryLabel)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }
            ForEach(Array(current.enumerated()), id: \.offset) { index, value in
                LineMark(x: .value("几号", index + 1), y: .value("钱", value), series: .value("月", "这个月"))
                    .foregroundStyle(Theme.Palette.accentFill)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
            if let index = shown, index < current.count {
                RuleMark(x: .value("几号", index + 1)).foregroundStyle(Theme.Palette.separator)
                PointMark(x: .value("几号", index + 1), y: .value("钱", current[index]))
                    .foregroundStyle(Theme.Palette.accentFill)
            }
        }
        .chartXScale(domain: 1...max(2, days))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        LongPressGesture(minimumDuration: 0.15)
                            .sequenced(before: DragGesture(minimumDistance: 0))
                            .onChanged { value in
                                guard case .second(true, let drag?) = value, let frame = proxy.plotFrame else { return }
                                let x = drag.location.x - geometry[frame].origin.x
                                if let day: Int = proxy.value(atX: x) {
                                    picked = min(max(0, day - 1), max(0, current.count - 1))
                                }
                            }
                            .onEnded { _ in picked = nil }
                    )
            }
        }
        .themeSelectionFeedback(trigger: picked)
    }

    /// 上面那一行：按住时写那一天，平时写最后一天和图例
    private var caption: String {
        // 图例：没有上个月的线（刚开始用、上个月没说到钱）就不写「上个月同日」
        let legend = previous == nil ? "━ 这个月每天累计" : "━ 这个月每天累计 · ┅ 上个月同日"
        guard let index = shown, index < current.count else { return legend }
        var text = "\(dayName(index)) \(money(current[index]))"
        if let previous, index < previous.count { text += " · 上个月同日 \(money(previous[index]))" }
        return picked == nil ? legend : text
    }

    private var shown: Int? { picked ?? (current.isEmpty ? nil : current.count - 1) }

    /// 读屏：到哪天一共多少、上个月同日多少
    private var summary: String {
        guard let index = shown, index < current.count else { return "还没说到钱" }
        var text = "\(dayName(index))累计 \(money(current[index]))"
        if let previous, index < previous.count { text += "，上个月同日 \(money(previous[index]))" }
        return text
    }
}

/// 月历（06 交互细节 3.2，产品主人点名要的）：每一格上面小字几号，下面那天日常花了多少（圆体数字、上万写「2万」）；
/// 没说到钱的那天只有日期，不写 0；背景深浅只做辅助；今天一圈蓝框，选中的一天蓝底白字
public struct MoneyCalendarGrid: View {
    public struct Day: Hashable, Sendable {
        /// 「2026-10-24」
        public let day: String
        public let number: Int
        /// 那天花了多少（写好了的：「1978」「2万」「•••」）；没说到钱是 nil
        public let amount: String?
        /// 花得多少（0–1）：背景深一点浅一点
        public let weight: Double
        /// 读屏念的（「10月24日，花了 ¥1,978」）
        public let spoken: String

        public init(day: String, number: Int, amount: String?, weight: Double, spoken: String) {
            self.day = day
            self.number = number
            self.amount = amount
            self.weight = weight
            self.spoken = spoken
        }
    }

    let blanks: Int
    let days: [Day]
    let today: String?
    let selected: String?
    let pick: (String) -> Void

    /// blanks：1 号前面空几格（一周从周一算）
    public init(blanks: Int, days: [Day], today: String?, selected: String?, pick: @escaping (String) -> Void) {
        self.blanks = blanks
        self.days = days
        self.today = today
        self.selected = selected
        self.pick = pick
    }

    private static let names = ["一", "二", "三", "四", "五", "六", "日"]

    public var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.Space.tight), count: 7)
        LazyVGrid(columns: columns, spacing: Theme.Space.tight) {
            ForEach(Self.names, id: \.self) { name in
                Text(name).font(Theme.Typeface.tick).foregroundStyle(Theme.Palette.secondaryLabel)
                    .accessibilityHidden(true)
            }
            ForEach(0..<blanks, id: \.self) { _ in Color.clear.frame(height: Theme.Size.touch) }
            ForEach(days, id: \.day) { cell($0) }
        }
    }

    private func cell(_ day: Day) -> some View {
        let isSelected = day.day == selected
        let isToday = day.day == today
        return Button {
            pick(day.day)
        } label: {
            VStack(spacing: 0) {
                Text("\(day.number)").font(Theme.Typeface.tick)
                    .foregroundStyle(isSelected ? Theme.Palette.onAccent : Theme.Palette.secondaryLabel)
                Text(day.amount ?? " ").font(Theme.Typeface.rowNumber).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .foregroundStyle(isSelected ? Theme.Palette.onAccent : Theme.Palette.label)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
            .background(background(day, selected: isSelected), in: Theme.rounded(Theme.Corner.tile))
            .overlay {
                if isToday && !isSelected {
                    Theme.rounded(Theme.Corner.tile).strokeBorder(Theme.Palette.accentFill, lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(day.spoken))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("money.day.\(day.day)")
    }

    /// 花得越多越深一点（最多到很浅的琥珀色：数字才是主角）
    private func background(_ day: Day, selected: Bool) -> Color {
        if selected { return Theme.Palette.accentFill }
        guard day.amount != nil else { return .clear }
        return Theme.Palette.warnFill.opacity(0.35 + 0.65 * min(1, max(0, day.weight)))
    }
}

/// 一样东西每次多少钱的台阶线（06 交互细节 10.2）：横着是买的那天到今天，竖着是每次多少钱；
/// 每说到用一次往下走一阶，每个点是说到用它的一天。左右两头写什么（「¥899 买的时候」「现在每次 ¥180」）由调用的地方写在图外面
public struct PerUseChart: View {
    /// 买的时候花了多少
    let total: Double
    /// 每次说到用它是买了以后第几天（从早到晚）
    let uses: [Int]
    /// 买的那天到今天一共几天
    let span: Int

    public init(total: Double, uses: [Int], span: Int) {
        self.total = total
        self.uses = uses
        self.span = span
    }

    public var body: some View {
        Chart {
            ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                LineMark(x: .value("第几天", step.day), y: .value("每次", step.value))
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(Theme.Palette.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineJoin: .round))
            }
            ForEach(Array(uses.enumerated()), id: \.offset) { index, day in
                PointMark(x: .value("第几天", day), y: .value("每次", total / Double(index + 1)))
                    .foregroundStyle(Theme.Palette.accent)
                    .symbolSize(36)
            }
        }
        .chartXScale(domain: 0...max(1, span))
        .chartYScale(domain: 0...max(1, total))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: Theme.Size.curve * 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("每次多少钱的台阶线"))
    }

    /// 买的那天是原价；说到用第 k 次，每次就是 原价 ÷ k；一直画到今天
    private var steps: [(day: Int, value: Double)] {
        var points = [(day: 0, value: total)]
        for (index, day) in uses.enumerated() { points.append((day, total / Double(index + 1))) }
        points.append((max(span, uses.last ?? 0), total / Double(max(1, uses.count))))
        return points
    }
}

#Preview("累计曲线、月历") {
    let current: [Double] = [28, 46, 744, 1074, 1074, 1290, 1600, 2400, 3100, 3300, 3600, 3800]
    let previous: [Double] = (1...31).map { Double($0) * 260 }
    let days = (1...31).map { number in
        let day = String(format: "2026-10-%02d", number)
        let amount: String? = number <= 12 && number % 3 != 0 ? "\(number * 37)" : nil
        return MoneyCalendarGrid.Day(
            day: day, number: number, amount: amount, weight: Double(number % 5) / 4, spoken: "10月\(number)日")
    }
    VStack(spacing: Theme.Space.regular) {
        PaceChart(
            current: current, previous: previous, days: 31, money: { "¥\(Int($0))" }, dayName: { "10月\($0 + 1)日" }
        )
        .themeCard()
        MoneyCalendarGrid(blanks: 3, days: days, today: "2026-10-12", selected: "2026-10-04") { _ in }
            .themeCard()
        PerUseChart(total: 899, uses: [2, 9, 13, 16, 30], span: 33).themeCard()
    }
    .padding()
    .background(Theme.Palette.background)
}
