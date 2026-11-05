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

/// 待办卡里的一件日程（待办 2.0）：日历图标和待办的圈同一列，一行标题（长了省略），右边几点到几点或「全天」。
/// 只读，点了没反应（改在日历里）
struct AgendaEventRow: View {
    let item: CalendarItem

    var body: some View {
        CalendarLine(event: item)
            .padding(.leading, -Theme.Space.regular)
            .padding(.trailing, -Theme.Space.regular)
            .accessibilityIdentifier(item.allDay ? "agenda.allDay" : "agenda.event")
    }
}
