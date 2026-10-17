public import SwiftUI

// MARK: - 钱的月历（2.12）

/// 7 列日历；每格写当天花了多少；底色用墨的深浅（钱不是生活领域，不用彩色）
/// 月历里的一天（编号和 1 号前的空格不重复）
private struct CalendarDay: Identifiable {
    let index: Int
    var id: String { "day-\(index)" }
}

public struct PourMoneyCalendar: View {
    /// 格子底色用墨的深浅表示花了多少：6%–12%。规范原来写 20%，实测亮色 20% 的底上淡墨字只有 4.40:1，
    /// 不到 4.5；14% 算出来 5.07:1，但 11 点的小字在系统审计里实测还差一点，所以封顶 12%（M1 自验收）。
    /// PourColorTests 逐档实算
    public static let tintRange: ClosedRange<Double> = 0.06...0.12

    /// 这一天的底色深浅（花得越多越深）
    public static func tint(for amount: Double, top: Double) -> Double {
        tintRange.lowerBound + (tintRange.upperBound - tintRange.lowerBound) * min(max(amount / max(top, 1), 0), 1)
    }

    /// 旁白读的：还没到的日子说「还没到」，不说「没记」
    static func spokenLabel(day: Int, amount: Double?, future: Bool, hidden: Bool) -> String {
        if future { return "\(day) 日，还没到" }
        if hidden { return "\(day) 日" }
        return "\(day) 日，" + (amount.map { "花了 \(Int($0.rounded())) 元" } ?? "没记")
    }

    /// 这个月 1 号是星期几（0 = 周一）
    let firstWeekday: Int
    /// 每天花了多少（元），nil 是没记
    let amounts: [Double?]
    let today: Int?
    let hidden: Bool

    public init(firstWeekday: Int, amounts: [Double?], today: Int? = nil, hidden: Bool = false) {
        self.firstWeekday = firstWeekday
        self.amounts = amounts
        self.today = today
        self.hidden = hidden
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public var body: some View {
        if dynamicTypeSize.isAccessibilitySize { list } else { grid }
    }

    /// 大字号时：一天一行，只列记了的日子（7 列的格子放不下大字）
    private var list: some View {
        VStack(alignment: .leading, spacing: PourSpace.related) {
            ForEach(amounts.indices.filter { amounts[$0] != nil }, id: \.self) { index in
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: "\(index + 1) 日").pourText(.body).foregroundStyle(PourColor.inkSecondary.color)
                    Spacer(minLength: PourSpace.related)
                    Text(verbatim: hidden ? "•••" : "¥\(Int((amounts[index] ?? 0).rounded()))")
                        .pourText(.body).monospacedDigit().foregroundStyle(PourColor.ink.color)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder private var grid: some View {
        let top = max(amounts.compactMap { $0 }.max() ?? 1, 1)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { day in
                Text(day).pourText(.micro).foregroundStyle(PourColor.chartLabel.color)
            }
            // 1 号前面的空格和每一天要用不同的编号：都用 0、1、2…… 时 SwiftUI 会把它们当成同一个，
            // 1–3 号就不见了（M1 自验收在截图里发现的）
            ForEach(0..<firstWeekday, id: \.self) { blank in
                Color.clear.frame(height: PourSize.minTap).id("blank-\(blank)")
            }
            ForEach(amounts.indices.map { CalendarDay(index: $0) }) { cell in
                let index = cell.index
                let amount = amounts[index]
                let day = index + 1
                let future = today.map { day > $0 } ?? false
                ZStack {
                    RoundedRectangle.pour(PourRadius.sm)
                        .fill(PourColor.ink.color.opacity(amount.map { Self.tint(for: $0, top: top) } ?? 0))
                    if day == today {
                        RoundedRectangle.pour(PourRadius.sm).strokeBorder(PourColor.ink.color, lineWidth: 1.5)
                    }
                    VStack(spacing: 2) {
                        Text(verbatim: "\(day)").pourText(.micro)
                            .foregroundStyle(PourColor.inkSecondary.color)
                        Text(verbatim: hidden ? "•••" : amount.map { "\(Int($0.rounded()))" } ?? " ")
                            .pourText(.micro).monospacedDigit().foregroundStyle(PourColor.ink.color)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: PourSize.minTap)
                .contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(Self.spokenLabel(day: day, amount: amount, future: future, hidden: hidden)))
            }
        }
    }
}
