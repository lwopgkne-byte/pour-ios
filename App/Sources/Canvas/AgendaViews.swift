import PourAPI
import PourCore
import PourDesign
import SwiftUI

// MARK: - 日历里的日程（docs/模块/产品优化.md R6）

/// 接上日历的小卡：只在看今天、还没接、没点掉时出现；一次只出一张（接上健康那张处理完了才出）
struct CalendarHint: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.shownDay == model.today, model.calendar.showHint, !model.showHealthHint {
            ConnectHint(
                key: "calendar", symbol: "calendar", color: "red", title: "接上日历：今天的日程出现在待办里",
                text: "只读，不改日历。日程只在这台手机上，不送到电脑上的 Pour；和你说的待办是同一件的只显示一次。",
                connect: model.connectCalendar
            ) {
                model.calendar.closeHint()
                model.toast("以后在「设置 → 日历」里也能接上")
            }
        }
    }
}

/// 待办卡里的一件日程（照原型 TodoRow 的 cal 行）：和待办的圆圈同一列、正中一根日历颜色的竖条，名字和待办的字对齐；
/// 右边几点到几点，全天的（节假日、生日，排在最上面）是「全天 · 日历」小胶囊。只读，点了没反应（改在日历里）
struct AgendaEventRow: View {
    let item: CalendarItem

    var body: some View {
        HStack(spacing: Theme.Space.tight) {
            // 和待办的圆圈一样：44 宽的一列，往左挪同样多
            CalendarBar(color: Theme.calendarColor(item.color, calendar: item.calendar))
                .frame(width: Theme.Size.touch)
                .padding(.leading, -Theme.Space.medium + Theme.Space.hairline)
            Text(Show.spaced(item.title)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                .lineLimit(2)
            Spacer(minLength: Theme.Space.small)
            CalendarTime(TodayItem.time(item), allDay: item.allDay)
        }
        .padding(.vertical, Theme.Space.tight)
        .frame(minHeight: Theme.Size.touch)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("日历：\(item.title)，\(TodayItem.time(item))"))
        .accessibilityIdentifier(item.allDay ? "agenda.allDay" : "agenda.event")
    }
}
