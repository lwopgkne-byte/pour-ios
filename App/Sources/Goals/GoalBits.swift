import PourAPI
import PourDesign
import SwiftUI

/// 目标的状态色小圆点；还谈不上状态的是空心圈
struct ToneDot: View {
    let tone: String

    var body: some View {
        Group {
            if tone == "idle" {
                Circle().strokeBorder(Web.fgTertiary, lineWidth: 1)
            } else {
                Circle().fill(Web.status(tone))
            }
        }
        .frame(width: Web.space2, height: Web.space2)
        .accessibilityHidden(true)
    }
}

/// 细进度条：4 点高的浅灰底，状态色填到进度那么长
struct GoalBar: View {
    let pct: Double
    let tone: String

    var body: some View {
        GeometryReader { proxy in
            Capsule().fill(Web.bgHover).overlay(alignment: .leading) {
                Capsule().fill(Web.status(tone)).frame(width: proxy.size.width * min(1, max(0, pct)))
            }
        }
        .frame(height: Web.space1)
        .accessibilityHidden(true)
    }
}

/// 年目标的一个月、月目标的一周：名称、进度条、「实际 / 目标」；有下一层的能展开
struct GoalSubRow: View {
    let row: API.SubPeriod
    let unit: String
    @State private var open: Bool

    init(row: API.SubPeriod, unit: String) {
        self.row = row
        self.unit = unit
        _open = State(initialValue: row.current)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Web.space3) {
                HStack(spacing: Web.space3) {
                    Text(row.label).frame(minWidth: Web.space16, alignment: .leading)
                    GoalBar(pct: row.progress.pct, tone: row.progress.tone)
                    Text(
                        "\(Show.fmtNum(row.progress.actual)) / \(Show.fmtNum(row.target)) \(unit)"
                            + (row.locked ? " · 已调整" : "")
                    )
                    .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                if let weeks = row.weeks, weeks.count > 1 {
                    GoalExpand(open: $open, label: "展开\(row.label)的每周")
                }
            }
            .font(row.current ? Web.captionMedium : Web.caption)
            .foregroundStyle(row.current ? Web.fg : Web.fgSecondary)
            .padding(.horizontal, Web.space2)
            .frame(minHeight: Web.control)
            if open, let weeks = row.weeks, weeks.count > 1 {
                GoalSubs { ForEach(weeks) { GoalSubRow(row: $0, unit: unit) } }
            }
        }
    }
}

/// 展开的月、周：往里缩一点，左边一条细线
struct GoalSubs<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.leading, Web.space2)
            .overlay(alignment: .leading) { Rectangle().fill(Web.line).frame(width: 1) }
            .padding(.leading, Web.space4)
    }
}

/// 展开、收起的小箭头（44 点能点）
struct GoalExpand: View {
    @Binding var open: Bool
    let label: String

    var body: some View {
        Button {
            withAnimation(Web.panel) { open.toggle() }
        } label: {
            Image(systemName: open ? "chevron.down" : "chevron.right").font(Web.caption)
                .foregroundStyle(Web.fgSecondary)
                .frame(width: Web.touch, height: Web.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(open ? "收起" : label))
    }
}
