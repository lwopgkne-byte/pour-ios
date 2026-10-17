public import SwiftUI

// 图表（docs/ios/设计规范/09-数据可视化.md）。一句结论在上（页面写），图是证据；
// 最多两种颜色加灰；直接标在图上不用图例；减少动态效果时直接出现。

// MARK: - 方块图（2.1，你的生活由什么组成）

public struct TreemapItem: Identifiable, Sendable {
    /// 用名字认，不用颜色：几个类别可以共用一种领域色（购物和家务都是陶），用颜色当编号会让 SwiftUI 把它们当成同一块，
    /// 列表里「睡眠」出现三次、「娱乐」「冥想」不见了（M1 自验收在最大字号的截图里发现的，和钱的月历丢日子是同一类）
    public var id: String { label }
    public let domain: PourDomain
    public let label: String
    public let count: Int

    public init(domain: PourDomain, label: String, count: Int) {
        self.domain = domain
        self.label = label
        self.count = count
    }
}

/// 面积 = 说到它的段数。前两块占第一行，其余排第二行；第二行放不下（每块至少 88 点宽，写得下四个字）的，
/// 并进最下面一行「还在攒的」（规范 09 第 2.1 节）
public struct PourTreemap: View {
    let items: [TreemapItem]
    static let minTileWidth: CGFloat = 88
    static let gap: CGFloat = 4

    public init(_ items: [TreemapItem]) {
        // 编号重复时 SwiftUI 显示的结果不确定（会少块、多块）：开发和测试时直接拦下
        assert(Set(items.map(\.id)).count == items.count, "方块图里有重复的名字：\(items.map(\.label))")
        self.items = items.sorted { $0.count > $1.count }
    }

    /// 第二行放得下几块：按面积比例分宽度，最窄的一块也要 ≥ 最小宽度
    static func secondRowCount(_ rest: [TreemapItem], width: CGFloat) -> Int {
        var count = rest.count
        while count > 0 {
            let row = rest.prefix(count)
            let sum = CGFloat(max(row.map(\.count).reduce(0, +), 1))
            let usable = width - CGFloat(count - 1) * gap
            if let smallest = row.last, usable * CGFloat(smallest.count) / sum >= minTileWidth { return count }
            count -= 1
        }
        return 0
    }

    @State private var width: CGFloat = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public var body: some View {
        if dynamicTypeSize.isAccessibilitySize { list } else { tiles }
    }

    /// 大字号：一个领域一行（块里放不下大字；规范 11「两列变一列」）
    private var list: some View {
        let total = max(items.map(\.count).reduce(0, +), 1)
        return VStack(alignment: .leading, spacing: PourSpace.related) {
            ForEach(items) { item in
                HStack(alignment: .firstTextBaseline, spacing: PourSpace.related) {
                    PourDomainDot(item.domain)
                    Text(item.label).pourText(.body).foregroundStyle(PourColor.ink.color)
                    Spacer(minLength: PourSpace.related)
                    Text(verbatim: "\(Int((Double(item.count) / Double(total) * 100).rounded()))%")
                        .pourText(.body).monospacedDigit().foregroundStyle(PourColor.inkSecondary.color)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder private var tiles: some View {
        let total = max(items.map(\.count).reduce(0, +), 1)
        let first = Array(items.prefix(2))
        let rest = Array(items.dropFirst(2))
        let fit = width > 0 ? Self.secondRowCount(rest, width: width) : 0
        let tail = rest.dropFirst(fit)
        // 宽度量出来再排（不用固定高度的 GeometryReader：「还在攒的」那行要能换行、整块跟着长高）
        VStack(alignment: .leading, spacing: Self.gap) {
            // 最小高度，不是固定高度：字调大时块跟着长高，名字不会被截
            row(first, total: total, width: width).frame(minHeight: 110)
            if fit > 0 { row(Array(rest.prefix(fit)), total: total, width: width).frame(minHeight: 72) }
            if !tail.isEmpty {
                Text("还在攒的：\(tail.map(\.label).joined(separator: " · "))")
                    .pourText(.caption).foregroundStyle(PourColor.inkSecondary.color)
                    .padding(.top, PourSpace.tight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: {
            width = $0
        }
    }

    private func row(_ items: [TreemapItem], total: Int, width: CGFloat) -> some View {
        let sum = CGFloat(max(items.map(\.count).reduce(0, +), 1))
        let usable = width - CGFloat(items.count - 1) * Self.gap
        return HStack(spacing: Self.gap) {
            ForEach(items) { item in
                let share = Double(item.count) / Double(total)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.label).pourText(.callout).fontWeight(.semibold)
                    Text(verbatim: "\(Int((share * 100).rounded()))%").pourText(.caption).monospacedDigit()
                }
                .foregroundStyle(item.domain.text.color)
                .padding(PourSpace.related)
                .frame(width: usable * CGFloat(item.count) / sum, alignment: .topLeading)
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
                .background(RoundedRectangle.pour(PourRadius.md).fill(item.domain.soft.color))
                .accessibilityElement(children: .combine)
            }
        }
    }
}

// MARK: - 时间去向（2.2）

public struct TimeShareItem: Sendable {
    public let domain: PourDomain
    public let label: String
    public let minutes: Int

    public init(domain: PourDomain, label: String, minutes: Int) {
        self.domain = domain
        self.label = label
        self.minutes = minutes
    }
}

public struct PourTimeShare: View {
    let items: [TimeShareItem]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// 百分比那一列的宽度（几行对齐用）：跟着字号一起变，不是死的点数
    @ScaledMetric(relativeTo: .subheadline) private var shareWidth: CGFloat = 44

    public init(_ items: [TimeShareItem]) { self.items = items }

    public var body: some View {
        let total = max(items.map(\.minutes).reduce(0, +), 1)
        VStack(alignment: .leading, spacing: PourSpace.element) {
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    ForEach(items.indices, id: \.self) { index in
                        Rectangle().fill(items[index].domain.solid.color)
                            .frame(width: max(2, proxy.size.width * CGFloat(items[index].minutes) / CGFloat(total)))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 12)
            .accessibilityHidden(true)
            ForEach(items.indices, id: \.self) { index in
                timeRow(items[index], total: total)
            }
            Text("只算说了时长的事").pourText(.caption).foregroundStyle(PourColor.inkSecondary.color)
        }
    }

    /// 一个领域一行：「名字 … 时长 百分比」。大字号时时长和百分比换到名字下面（不挤成一个字一行——M1 自验收）
    @ViewBuilder private func timeRow(_ item: TimeShareItem, total: Int) -> some View {
        let share = Text(verbatim: "\(Int((Double(item.minutes) / Double(total) * 100).rounded()))%")
            .pourText(.meta).monospacedDigit().foregroundStyle(PourColor.inkSecondary.color)
        let duration = Text(Self.duration(item.minutes)).pourText(.body).monospacedDigit()
            .foregroundStyle(PourColor.ink.color)
        let name = HStack(spacing: PourSpace.related) {
            PourDomainDot(item.domain)
            Text(item.label).pourText(.body).foregroundStyle(PourColor.ink.color)
        }
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PourSpace.tight) {
                    name
                    // 时长按自己的宽度占一行，百分比放不下就换到下一行（不把「48 小时 20 分」折开）
                    PourFlowLayout {
                        duration
                        share
                    }
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: PourSpace.related) {
                    name
                    Spacer(minLength: PourSpace.related)
                    duration
                    share.frame(minWidth: shareWidth, alignment: .trailing)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// 「45 分钟」「1 小时 20 分」（规范 02 第 4 节；M2 起由 PourCore 的格式化函数统一产出）
    static func duration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest) 分钟" }
        return rest == 0 ? "\(hours) 小时" : "\(hours) 小时 \(rest) 分"
    }
}

// MARK: - 迷你曲线（2.3）

public struct PourSparkline: View {
    let values: [Double]
    let showEnds: Bool

    public init(_ values: [Double], showEnds: Bool = true) {
        self.values = values
        self.showEnds = showEnds
    }

    public var body: some View {
        GeometryReader { proxy in
            let low = values.min() ?? 0
            let high = values.max() ?? 1
            let span = max(high - low, 0.0001)
            let step = proxy.size.width / CGFloat(max(values.count - 1, 1))
            let point = { (index: Int) -> CGPoint in
                CGPoint(
                    x: CGFloat(index) * step,
                    y: proxy.size.height - CGFloat((values[index] - low) / span) * (proxy.size.height - 4) - 2)
            }
            Path { path in
                guard !values.isEmpty else { return }
                path.move(to: point(0))
                for index in values.indices.dropFirst() { path.addLine(to: point(index)) }
            }
            .stroke(PourColor.chartPrimary.color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .accessibilityElement()
        .accessibilityLabel(Text("趋势"))
        .accessibilityValue(
            Text("从 \(values.first.map { "\(Int($0))" } ?? "") 到 \(values.last.map { "\(Int($0))" } ?? "")"))
    }
}

// MARK: - 心情像素墙（2.7）

/// 每天一格、一列一周；有心情填五档色、没记画虚线空格
public struct PourMoodWall: View {
    /// 按日子顺序，nil 是没记
    let levels: [Int?]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    public init(_ levels: [Int?]) { self.levels = levels }

    public var body: some View {
        let weeks = stride(from: 0, to: levels.count, by: 7).map { Array(levels[$0..<min($0 + 7, levels.count)]) }
        HStack(alignment: .top, spacing: PourSize.moodPixelGap) {
            ForEach(weeks.indices, id: \.self) { week in
                VStack(spacing: PourSize.moodPixelGap) {
                    ForEach(weeks[week].indices, id: \.self) { day in
                        PourMoodCell(level: weeks[week][day])
                            .opacity(shown || reduceMotion ? 1 : 0)
                            .animation(
                                reduceMotion
                                    ? nil : .easeOut(duration: PourMotion.fast).delay(Double(week * 7 + day) * 0.008),
                                value: shown)
                    }
                }
            }
        }
        .onAppear { shown = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("心情像素墙，\(levels.compactMap { $0 }.count) 天有心情"))
    }
}
