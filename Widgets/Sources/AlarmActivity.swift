import ActivityKit
import AlarmKit
import PourDesign
import PourPlatform
import SwiftUI
import WidgetKit

/// 响铃的待办点了「稍后提醒」（产品主人 2026-11-06）：锁屏、灵动岛上倒计时，到点再响。
/// AlarmKit 要一个实时活动来画倒计时；到点响的那一下是系统自己画的（和系统闹钟一样）
struct AlarmActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<PourAlarm>.self) { context in
            HStack(spacing: Theme.Space.medium) {
                Image(systemName: "alarm").font(.title2).foregroundStyle(context.attributes.tintColor)
                VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                    Text(Self.title(context.attributes)).font(.headline).lineLimit(1)
                    Text("稍后再叫你").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: Theme.Space.small)
                Self.clock(context.state).font(.title.monospacedDigit())
                    .foregroundStyle(context.attributes.tintColor)
            }
            .padding(Theme.Space.regular)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "alarm").foregroundStyle(context.attributes.tintColor)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Self.clock(context.state).monospacedDigit().foregroundStyle(context.attributes.tintColor)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(Self.title(context.attributes)).lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "alarm").foregroundStyle(context.attributes.tintColor)
            } compactTrailing: {
                Self.clock(context.state).monospacedDigit().frame(maxWidth: Theme.Size.touch)
            } minimal: {
                Image(systemName: "alarm").foregroundStyle(context.attributes.tintColor)
            }
        }
    }

    /// 这件事（排的时候写在倒计时的标题上）
    private static func title(_ attributes: AlarmAttributes<PourAlarm>) -> LocalizedStringResource {
        attributes.presentation.countdown?.title ?? attributes.presentation.alert.title
    }

    /// 还有多久再响（倒着走的钟）
    @ViewBuilder private static func clock(_ state: AlarmPresentationState) -> some View {
        switch state.mode {
        case .countdown(let countdown):
            Text(timerInterval: Date.now...max(Date.now, countdown.fireDate), countsDown: true)
        case .paused: Text("暂停了")
        case .alert: Text("到点了")
        @unknown default: EmptyView()
        }
    }
}
