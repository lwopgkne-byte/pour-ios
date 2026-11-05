public import SwiftUI

// 待办里的日程一行（待办 2.0：日历图标、一行标题、右边几点到几点或「全天」）、勾上时的触感。
// 待办行本身在 ThemeTodoTwo（按象限画的圈、TodoLine）；3.0 的大圆圈、时间胶囊、第二行（和谁、东西、地方）在待办 2.0 第 9 步删掉

/// 日历里的日程，穿插在今天里（只读；待办 2.0）：左边日历图标（和待办的圈同一列），一行标题（长了省略），
/// 右边「15:00–18:00」或「全天」。不再写「日历」小标签
public struct CalendarLine: View {
    let title: String
    let time: String

    public init(_ title: String, time: String) {
        self.title = title
        self.time = time
    }

    public var body: some View {
        TodoLine(title, done: false) {
            CalendarGlyph()
        } trailing: {
            Text(time).font(Theme.Typeface.subheadline).monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
                .lineLimit(1).fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("日历：\(title)，\(time)"))
    }
}

/// 日程前面的日历图标（和待办的圈同一列：点的范围那么宽、看得见的居中）
public struct CalendarGlyph: View {
    public init() {}

    public var body: some View {
        Image(systemName: "calendar").font(Theme.Typeface.body).foregroundStyle(Theme.Agenda.icon)
            .frame(width: Theme.Size.touch, height: Theme.Size.check)
            .accessibilityHidden(true)
    }
}

extension View {
    /// 勾上时成功的触感（取消打勾不震）
    func todoDoneFeedback(_ done: Bool) -> some View {
        #if os(iOS)
            sensoryFeedback(Theme.Haptics.done, trigger: done) { _, now in now }
        #else
            self
        #endif
    }
}

#Preview("日程一行") {
    VStack(alignment: .leading, spacing: 0) {
        CalendarLine("产品评审会", time: "14:00–15:30")
        Divider()
        CalendarLine("结婚纪念日", time: "全天")
    }
    .background(Theme.Palette.card)
    .padding()
    .background(Theme.Palette.background)
}
