import PourAPI
import PourDesign
import SwiftUI

/// 日历：一行一周（周一到周日），左边一列写月份；每一格的颜色由 paint 定，能点的点进那天
struct MeCalendar: View {
    @Environment(AppModel.self) private var model
    let weeks: [API.MeCalWeek]
    /// mood：没说心情的是灰格；domain：没有的是白格
    let kind: String
    let paint: (API.MeCalDay) -> Color?
    let open: (String) -> Void

    var body: some View {
        Grid(horizontalSpacing: Theme.Space.tight, verticalSpacing: Theme.Space.tight) {
            GridRow {
                Color.clear.frame(width: Theme.Space.section, height: 1)
                ForEach(MeStyle.weekHead, id: \.self) { PaintedText(text: $0) }
            }
            .accessibilityHidden(true)
            ForEach(weeks, id: \.self) { week in
                GridRow {
                    Text(week.label).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                        .fixedSize()
                        .gridColumnAlignment(.leading)
                    ForEach(week.days, id: \.day) { day in cell(day) }
                }
            }
        }
        .padding(.top, Theme.Space.regular)
    }

    @ViewBuilder private func cell(_ day: API.MeCalDay) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Corner.tile)
        switch day.state {
        case "future": Color.clear.frame(height: Theme.Space.xLarge).accessibilityHidden(true)
        case "none":
            shape.strokeBorder(
                Theme.Palette.separator,
                style: StrokeStyle(lineWidth: 1, dash: [Theme.Space.tight / 2, Theme.Space.tight / 2])
            )
            .frame(height: Theme.Space.xLarge)
            .accessibilityLabel(Text("\(MeStyle.dayLabel(day.day))：没说话"))
        default:
            Button {
                open(day.day)
            } label: {
                Group {
                    if let fill = paint(day) {
                        shape.fill(fill)
                    } else if kind == "mood" {
                        shape.fill(Theme.tag("gray").tint)
                    } else {
                        shape.fill(Theme.Palette.card).overlay(
                            shape.strokeBorder(Theme.Palette.separator, lineWidth: 1))
                    }
                }
                .frame(height: Theme.Space.xLarge)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(MeStyle.dayLabel(day.day)))
        }
    }
}

/// 画出来的一个小字（日历上头的「一 二 三」）：一个字一个元素时，审计量对比度不准（笔画太细）；这一排对读屏也没有用
struct PaintedText: View {
    let text: String

    var body: some View {
        Canvas { context, size in
            context.draw(
                Text(text).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel),
                at: CGPoint(x: size.width / 2, y: size.height / 2))
        }
        .frame(height: Theme.Space.regular + Theme.Space.tight)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}
