import PourAPI
import PourCore
import PourDesign
import SwiftUI

// MARK: - 日历里的日程（docs/模块/产品优化.md R6）

/// 接上日历的小卡：只在看今天、还没接、没点掉时出现；一次只出一张（接上健康那张处理完了才出）
struct CalendarHint: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.shownDay == model.today, model.calendar.showHint, !model.health.showHint {
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

/// 待办卡最上面一行：全天的日程（节假日、生日）
struct AllDayLine: View {
    let items: [CalendarItem]

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.small) {
            AgendaIcon()
            TaggedLabel(tag: AgendaTag.text) {
                Text(Show.spaced("全天：\(items.map(\.title).joined(separator: " · "))")).font(Theme.Typeface.body)
                    .foregroundStyle(Theme.Palette.label)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Space.tight)
        .frame(minHeight: Theme.Size.touch)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("agenda.allDay")
    }
}

/// 待办卡里的一件日程：和待办的圆圈对齐的日历图标、名字、几点到几点、「日历」。只读，点了没反应（改在日历里）
struct AgendaEventRow: View {
    let item: CalendarItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.small) {
            AgendaIcon()
            TaggedLabel(tag: AgendaTag.text) {
                Text(Show.spaced(item.title)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
            }
            Spacer(minLength: 0)
            Text("\(Show.clock(item.start))–\(Show.clock(item.end))").font(Theme.Typeface.footnote)
                .foregroundStyle(Theme.Palette.secondaryLabel).monospacedDigit().fixedSize()
        }
        .padding(.vertical, Theme.Space.tight)
        .frame(minHeight: Theme.Size.touch)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("agenda.event")
    }
}

/// 日程前面的小日历：和待办的圆圈一样宽、对齐
private struct AgendaIcon: View {
    var body: some View {
        Image(systemName: "calendar").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            .frame(width: Theme.Size.check).accessibilityHidden(true)
    }
}

/// 日程的小标签
enum AgendaTag {
    static let text = "日历"
}
