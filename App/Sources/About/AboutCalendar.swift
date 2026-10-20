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
        Grid(horizontalSpacing: Web.space1, verticalSpacing: Web.space1) {
            GridRow {
                Color.clear.frame(width: Web.space8, height: 1)
                ForEach(MeStyle.weekHead, id: \.self) { PaintedText(text: $0) }
            }
            .accessibilityHidden(true)
            ForEach(weeks, id: \.self) { week in
                GridRow {
                    Text(week.label).font(Web.caption).foregroundStyle(Web.fgTertiary).fixedSize()
                        .gridColumnAlignment(.leading)
                    ForEach(week.days, id: \.day) { day in cell(day) }
                }
            }
        }
        .padding(.top, Web.space4)
    }

    @ViewBuilder private func cell(_ day: API.MeCalDay) -> some View {
        let shape = RoundedRectangle(cornerRadius: Web.radiusControl)
        switch day.state {
        case "future": Color.clear.frame(height: Web.space6).accessibilityHidden(true)
        case "none":
            shape.strokeBorder(Web.line, style: StrokeStyle(lineWidth: 1, dash: [Web.space1 / 2, Web.space1 / 2]))
                .frame(height: Web.space6)
                .accessibilityLabel(Text("\(MeStyle.dayLabel(day.day))：没说话"))
        default:
            Button {
                open(day.day)
            } label: {
                Group {
                    if let fill = paint(day) {
                        shape.fill(fill)
                    } else if kind == "mood" {
                        shape.fill(Web.tag("gray").bg)
                    } else {
                        shape.fill(Web.bg).overlay(shape.strokeBorder(Web.line, lineWidth: 1))
                    }
                }
                .frame(height: Web.space6)
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
                Text(text).font(Web.caption).foregroundStyle(Web.fgTertiary),
                at: CGPoint(x: size.width / 2, y: size.height / 2))
        }
        .frame(height: Web.space4 + Web.space1)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}
