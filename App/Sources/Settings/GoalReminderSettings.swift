import PourAPI
import PourDesign
import SwiftUI

/// 设置 → 提醒和通知里目标的那几项（docs/3.0/01-需求文档.md 9.10「提醒」、07 开发任务清单 7.6）：
/// 每周回顾周几几点、能关；每个目标的「如果就」提醒一个一个能关；「到家的时候」要用的家在哪（只存在手机上）。
/// 这些通知都是手机自己排的，到点不用连网
struct GoalReviewRow: View {
    let review: API.ReminderStatus.Review
    let save: (JSONValue) -> Void

    private static let days = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]

    var body: some View {
        SettingRow(label: "每周回顾", hint: "看这周的目标、调一调、定下周最重要的一件；手机到点提醒") {
            if review.enabled {
                Menu {
                    ForEach(Self.days.indices, id: \.self) { day in
                        Button(Self.days[day]) { save(value(weekday: day)) }
                    }
                } label: {
                    Text(Self.days.indices.contains(review.weekday) ? Self.days[review.weekday] : "周日")
                        .font(Web.bodyMedium).foregroundStyle(Web.accent).frame(minHeight: Web.touch)
                }
                .accessibilityLabel(Text("每周回顾在星期几"))
                .accessibilityIdentifier("settings.review.day")
                TimeEdit(label: "每周回顾的时间", value: review.time) { save(value(time: $0)) }
            }
            WebSwitch("每周回顾", isOn: review.enabled) { save(value(enabled: $0)) }
        }
    }

    private func value(enabled: Bool? = nil, weekday: Int? = nil, time: String? = nil) -> JSONValue {
        .object([
            "enabled": .bool(enabled ?? review.enabled), "weekday": .number(Double(weekday ?? review.weekday)),
            "time": .string(time ?? review.time),
        ])
    }
}

/// 目标的「如果就」：一个目标一行，开关；暂停的写「暂停中，不提醒」；家在哪
struct GoalIfThenSettings: View {
    @Environment(AppModel.self) private var model
    @State private var list: API.GoalReminderList?
    @State private var home = HomePlace.saved
    @State private var locating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsHeading(title: "目标的「如果就」").padding(.top, Web.space2)
            if let list {
                if list.ifthen.isEmpty {
                    FieldMessage(text: "还没有目标设了提醒：在一个目标的「花 1 分钟想清楚」第三屏里选。")
                }
                ForEach(list.ifthen) { item in row(item) }
                if list.ifthen.contains(where: { $0.remind.kind == "place" }) || home != nil { homeRow }
                FieldMessage(text: "这些提醒是手机自己排的，到点不用连网；暂停的目标不提醒。")
            } else {
                Dots(label: "正在拿目标的提醒").foregroundStyle(Web.accent).frame(minHeight: Web.touch)
            }
        }
        .task(id: model.dataVersion) { list = try? await model.client.goalReminders() }
    }

    private func row(_ item: API.GoalReminderList.IfThen) -> some View {
        SettingRow(label: item.title, hint: item.paused ? "\(item.remind.text) · 暂停中，不提醒" : item.line) {
            WebSwitch("「\(item.title)」的提醒", isOn: item.remind.off != true) { isOn in
                var remind = item.remind
                remind.off = isOn ? nil : true
                remind.line = nil
                model.goalSet(item.id, GoalChange(remind: .some(remind)))
            }
        }
    }

    /// 家在哪：「到家的时候」提醒要用；用现在的位置定一次
    private var homeRow: some View {
        SettingRow(label: "家在哪", hint: "「到家的时候」提醒要用；只存在这台手机上") {
            Text(home == nil ? "还没定" : "定好了").foregroundStyle(home == nil ? Web.fgTertiary : Web.fgSecondary)
            if locating {
                Dots(label: "正在定位").foregroundStyle(Web.accent).frame(minHeight: Web.touch)
            } else {
                WebTextButton(home == nil ? "用现在的位置" : "改成现在的位置") {
                    locating = true
                    Task {
                        if await model.setHomeHere() { home = HomePlace.saved }
                        locating = false
                    }
                }
            }
            if home != nil {
                WebTextButton("不用了") {
                    HomePlace.save(nil)
                    home = nil
                    model.syncReminders()
                }
            }
        }
    }
}
