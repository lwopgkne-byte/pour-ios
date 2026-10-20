import PourAPI
import PourDesign
import SwiftUI

/*
 * 「关于我」各页共用的几样（网页版 about/about-parts.tsx，docs/prd-about-me-2.md 8.3）：同一份数据全产品一种画法——
 * 比较两组用两根横条，有几天用圆点，随时间变用小曲线，每天一格用像素；颜色只表示意思
 */

enum MeStyle {
    /// 心情的深浅：和回顾的月历同一把尺子（很差最浅、很好最深）
    static let shades = [0.12, 0.26, 0.42, 0.64, 1.0]

    static func moodShade(_ level: Double) -> Color {
        Web.accent.opacity(shades[min(5, max(1, Int(level.rounded()))) - 1])
    }

    static let weekHead = ["一", "二", "三", "四", "五", "六", "日"]

    /// 「9月26日 周六」
    static func dayLabel(_ day: String) -> String { "\(Show.monthDay(day)) \(Show.weekday(day))" }

    /// 那些日子的心情：好一些绿、差一些黄、差不多或还太少灰
    static func tone(_ mood: String) -> Color {
        switch mood {
        case "better": Web.status("good")
        case "worse": Web.status("warn")
        default: Web.tag("gray").solid
        }
    }
}

/// 子页面的开头：「‹ 关于我」、标题（领域页前面一个领域色的点）、下面一句
struct MeHead<Sub: View>: View {
    let title: String
    var color: String?
    let back: () -> Void
    @ViewBuilder var sub: () -> Sub

    var body: some View {
        VStack(alignment: .leading, spacing: Web.space1) {
            Button("‹ 关于我", action: back).buttonStyle(.plain).font(Web.caption).foregroundStyle(Web.fgSecondary)
                .padding(.horizontal, Web.space1).frame(minHeight: Web.touch).contentShape(Rectangle())
                .padding(.leading, -Web.space1)
            HStack(spacing: Web.space2) {
                if let color {
                    Circle().fill(Web.tag(color).solid).frame(width: Web.space3, height: Web.space3)
                        .accessibilityHidden(true)
                }
                Text(title).font(Web.title).foregroundStyle(Web.fg)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            sub()
        }
    }
}

/// 灰色的小字（网页版 .me-note）
struct MeNote: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View { Text(Show.spaced(text)).font(Web.caption).foregroundStyle(Web.fgTertiary) }
}

/// 浅灰底的一块面板（大数字、日历、星图）
struct MePanel<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Web.space1) { content() }
            .padding(Web.space4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Web.radiusPanel).fill(Web.bgSubtle))
            .padding(.top, Web.space4)
    }
}

/// 一行能点开（那几天、那几刻）：原地展开，不叠面板
struct MeExpand<Summary: View, Body: View>: View {
    var label: String?
    @ViewBuilder let summary: () -> Summary
    @ViewBuilder let content: () -> Body
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(Web.fast) { open.toggle() }
            } label: {
                summary().frame(maxWidth: .infinity, minHeight: Web.touch, alignment: .leading).contentShape(
                    Rectangle())
            }
            .buttonStyle(WebPressStyle(radius: 0))
            .accessibilityElement(children: label == nil ? .combine : .ignore)
            .accessibilityLabel(label.map { Text($0) } ?? Text(""))
            .accessibilityValue(Text(open ? "展开了" : "收着"))
            if open { content().padding(.bottom, Web.space2) }
        }
    }
}

/// 那几天：新的在前，最多 12 天，点进那天的画布
struct DayLinks: View {
    @Environment(AppModel.self) private var model
    let days: [String]
    var text: ((String) -> String)?

    var body: some View {
        let shown = Array(days.sorted().reversed().prefix(12))
        VStack(alignment: .leading, spacing: 0) {
            MoneyList {
                ForEach(shown, id: \.self) { day in
                    MoneyLinkRow(minHeight: Web.touch) {
                        model.page = .canvas
                        model.show(day)
                    } label: {
                        HStack(spacing: Web.space2) {
                            Text(MeStyle.dayLabel(day)).font(Web.body).foregroundStyle(Web.fg)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if let text { Text(text(day)).font(Web.caption).foregroundStyle(Web.fgTertiary) }
                        }
                    }
                }
            }
            if days.count > shown.count { MeNote("还有 \(days.count - shown.count) 天更早的").padding(.top, Web.space1) }
        }
    }
}

/// 一段话里把几个词加粗（「你说得最多的是**工作**和**吃的**」）
func boldWords(_ text: String, _ words: [String]) -> AttributedString {
    var out = AttributedString(Show.spaced(text))
    for word in words where !word.isEmpty {
        var from = out.startIndex
        while let found = out[from...].range(of: word) {
            out[found].font = Web.bodySemibold
            from = found.upperBound
        }
    }
    return out
}

/// 你说过的话：原话里那一小段，带着日子；点开是那段原话
struct MeQuotes: View {
    @Environment(AppModel.self) private var model
    let quotes: [API.MeQuote]

    var body: some View {
        VStack(spacing: Web.space3) {
            ForEach(quotes, id: \.noteId) { quote in
                Button {
                    model.open("/library?note=\(quote.noteId)")
                } label: {
                    VStack(alignment: .leading, spacing: Web.space1) {
                        Text(Show.spaced("「\(quote.text)」")).font(Web.body).foregroundStyle(Web.fg)
                        MeNote(MeStyle.dayLabel(quote.day))
                    }
                    .padding(Web.space4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: Web.radiusPanel).fill(Web.bgSubtle))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// 发现（各页里的，不带「说中了」那排按钮）
struct MeFindings: View {
    @Environment(AppModel.self) private var model
    let findings: [API.FindingView]

    var body: some View {
        VStack(spacing: Web.space3) {
            ForEach(findings, id: \.key) { finding in
                FindingCard(
                    finding: finding,
                    openDay: { day in
                        model.page = .canvas
                        model.show(day)
                    })
            }
        }
    }
}

/// 横条（做什么、好时刻多在做什么）：名字、条、几个；点一行看那几天
struct CountBars: View {
    let items: [API.MeCount]
    var color: String?

    var body: some View {
        let most = Double(max(1, items.map(\.count).max() ?? 1))
        VStack(spacing: 0) {
            ForEach(items, id: \.name) { item in
                MeExpand {
                    MeBarRow(
                        name: Text(Show.spaced(item.name)), share: Double(item.count) / most,
                        color: color.map { Web.tag($0).solid } ?? Web.lineStrong, value: "\(item.count)")
                } content: {
                    DayLinks(days: item.days)
                }
            }
        }
    }
}

/// 一根横条一行：名字（最多占四成）、条、右边的数
struct MeBarRow: View {
    let name: Text
    let share: Double
    let color: Color
    let value: String

    var body: some View {
        HStack(spacing: Web.space3) {
            name.font(Web.body).foregroundStyle(Web.fg)
                .containerRelativeFrame(.horizontal, alignment: .leading) { width, _ in width * 0.4 }
                .fixedSize(horizontal: false, vertical: true)
            MeTrack(share: share, color: color)
            Text(value).font(Web.caption).foregroundStyle(Web.fgSecondary).monospacedDigit()
                .frame(minWidth: Web.space8, alignment: .trailing)
        }
    }
}

/// 一条浅灰的轨道，上面一段颜色
struct MeTrack: View {
    let share: Double
    var color: Color = Web.lineStrong

    var body: some View {
        Capsule().fill(Web.bgHover).frame(height: Web.space2)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule().fill(color).frame(width: max(Web.space1, proxy.size.width * min(1, max(0, share))))
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
}

/// 你没注意到的变化：一句话 + 小曲线（两头写着起点和终点）+ 一行说明；领域的点进那一页，人的点进「人」，感受的点进「心情」
struct MeChanges: View {
    let changes: [API.MeChange]
    let navigate: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(changes.enumerated()), id: \.element.key) { index, change in
                let target =
                    change.domain.map { "/about/domain/\($0)" }
                    ?? (change.person != nil ? "/about/people" : change.color == "mood" ? "/about/mood" : nil)
                let row = VStack(alignment: .leading, spacing: Web.space2) {
                    Text(Show.spaced(change.text)).font(Web.bodySemibold).foregroundStyle(Web.fg)
                    MeSpark(change: change)
                    MeNote(change.sub)
                }
                .padding(.vertical, Web.space3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) {
                    if index < changes.count - 1 { Rectangle().fill(Web.line).frame(height: 1) }
                }
                if let target {
                    Button {
                        navigate(target)
                    } label: {
                        row.contentShape(Rectangle())
                    }
                    .buttonStyle(WebPressStyle(radius: 0))
                    .accessibilityElement(children: .combine)
                } else {
                    row.accessibilityElement(children: .combine)
                }
            }
        }
    }
}

/// 小曲线：两头写着起点和终点
struct MeSpark: View {
    let change: API.MeChange

    var body: some View {
        let color =
            change.color == "mood" ? Web.accent : change.color == "gray" ? Web.fgTertiary : Web.tag(change.color).solid
        HStack(spacing: Web.space3) {
            Text(change.from)
            MeLine(points: change.points.map { $0 }, color: color).frame(height: Web.space8)
            Text(change.to)
        }
        .font(Web.caption).foregroundStyle(Web.fgTertiary).monospacedDigit()
    }
}

/// 一条小折线（没有数的地方断开）
struct MeLine: View {
    let points: [Double?]
    let color: Color

    var body: some View {
        Canvas { context, size in
            let values = points.compactMap { $0 }
            guard let low = values.min(), let high = values.max() else { return }
            let span = high - low == 0 ? 1 : high - low
            var path = Path()
            var drawing = false
            for (index, value) in points.enumerated() {
                guard let value else {
                    drawing = false
                    continue
                }
                let point = CGPoint(
                    x: size.width * CGFloat(index) / CGFloat(max(1, points.count - 1)),
                    y: size.height - Web.space1 / 2 - (size.height - Web.space1) * CGFloat((value - low) / span))
                if drawing { path.addLine(to: point) } else { path.move(to: point) }
                drawing = true
            }
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}

/// 页脚：说清楚是怎么来的
struct MeFoot: View {
    var body: some View {
        Text("全部由你说过的话算出来，只在你的电脑上").font(Web.caption).foregroundStyle(Web.fgTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Web.space4)
            .overlay(alignment: .top) { Rectangle().fill(Web.line).frame(height: 1) }
            .padding(.top, Web.space12)
    }
}
