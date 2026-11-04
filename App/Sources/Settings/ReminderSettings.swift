import PourAPI
import PourDesign
import SwiftUI

/// 设置页「提醒和推送」：推送渠道（密钥只显示打码、只能在电脑上用「Pour 设置」填）、
/// 测试推送、各种提醒的开关和时间、「试一下」、目标入睡时间、周报月报、免打扰
struct ReminderSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let client = model.client
        Loaded(
            load: { () async throws(APIError) in try await client.reminders() },
            content: { status, reload in
                ReminderRows(saved: status, reload: reload)
            })
    }
}

private struct ReminderRows: View {
    @Environment(AppModel.self) private var model
    let saved: API.ReminderStatus
    let reload: () -> Void

    /// 改完服务器回来的样子（比重新拿快一步显示出来）
    @State private var fresh: API.ReminderStatus?
    @State private var trying: String?
    @State private var testing = false
    @State private var testResult: String?

    private var status: API.ReminderStatus { fresh ?? saved }

    /// 照原型「提醒和通知」：提醒、目标的「如果就」、免打扰、推送渠道，一组一张白卡
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.large) {
            SettingsGroup(title: "提醒") {
                timed("morning", label: "每日回顾", hint: "早上把昨天整理成一页回顾，连同今天的安排一起推送", status.morning)
                timed("evening", label: "晚上的倾倒提醒", hint: "今天还没记录时。好几天没记的时候会自己变少，一记就恢复", status.evening)
                MoodEveningRow(evening: status.evening) { save($0) }
                timed("warning", label: "预警", hint: "目标落后、状态变差", status.warning)
                SettingRow(label: "目标入睡时间", hint: "连续 3 天晚于它会预警") {
                    if let bedtime = status.bedtime {
                        TimeEdit(label: "目标入睡时间", value: bedtime) { save(["bedtime": .string($0)]) }
                        ThemeTextButton("不检查", font: Theme.Typeface.bodyMedium) { save(["bedtime": .null]) }
                    } else {
                        // 空着显示灰色的「不检查」，点一下选时间
                        TimeEdit(label: "目标入睡时间", value: "00:00", display: "不检查", unset: true) {
                            save(["bedtime": .string($0)])
                        }
                    }
                }
                report("weekly", label: "周报", hint: "每周一早上，总结上周", button: "看上周的", enabled: status.weekly.enabled)
                report("monthly", label: "月报", hint: "每月 1 号早上，总结上个月", button: "看上个月的", enabled: status.monthly.enabled)
                if let review = status.review { GoalReviewRow(review: review) { save(["review": $0]) } }
            }
            GoalIfThenSettings()
            SettingsGroup(title: "免打扰", footer: "免打扰时段里不推送，提醒照常出现在对话里。") {
                SettingRow(label: "免打扰时段") {
                    if status.dnd.enabled {
                        TimeEdit(label: "免打扰开始", value: status.dnd.from) { save(["dnd": dnd(from: $0)]) }
                        Text("到").foregroundStyle(Theme.Palette.secondaryLabel)
                        TimeEdit(label: "免打扰结束", value: status.dnd.to) { save(["dnd": dnd(to: $0)]) }
                    }
                    ThemeSwitch("免打扰", isOn: status.dnd.enabled) { save(["dnd": dnd(enabled: $0)]) }
                }
            }
            SettingsGroup(
                title: "推送渠道",
                footer: "推送密钥在电脑上用「Pour 设置」填写。提醒只在电脑开着、Pour 运行时发出；推送末尾附上手机能打开的地址。所有提醒也会出现在对话里。"
            ) {
                channel(
                    "serverchan", label: "Server酱（微信）", key: status.keys.serverchan,
                    enabled: status.channels.serverchan)
                channel("bark", label: "Bark（iPhone）", key: status.keys.bark, enabled: status.channels.bark)
                if status.keys.serverchan != nil || status.keys.bark != nil {
                    VStack(alignment: .leading, spacing: Theme.Space.small) {
                        ThemeButton("发一条测试推送", loading: testing) { testPush() }
                        if let testResult {
                            Text(Show.spaced(testResult)).font(Theme.Typeface.footnote).foregroundStyle(
                                Theme.Palette.secondaryLabel)
                        }
                    }
                    .padding(.vertical, Theme.Space.small)
                }
            }
        }
    }

    /// 推送渠道一行：打码的密钥；填过了能开关（填写只能在电脑上用「Pour 设置」）
    private func channel(_ name: String, label: String, key: String?, enabled: Bool) -> some View {
        SettingRow(label: label) {
            Text(key ?? "还没填写").foregroundStyle(
                key == nil ? Theme.Palette.secondaryLabel : Theme.Palette.secondaryLabel)
            if key != nil {
                ThemeSwitch("用\(label)推送", isOn: enabled) { value in
                    var channels = [
                        "serverchan": JSONValue.bool(status.channels.serverchan), "bark": .bool(status.channels.bark),
                    ]
                    channels[name] = .bool(value)
                    save(["channels": .object(channels)])
                }
            }
        }
    }

    /// 有时间的提醒（照原型）：名字后面跟着时间「每日回顾 07:30」（开着才有，点了改），下面一句说明；
    /// 右边「试一下」（马上发一条）和开关，一行放下
    private func timed(_ kind: String, label: String, hint: String, _ setting: API.ReminderStatus.Timed) -> some View {
        HStack(spacing: Theme.Space.medium) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.snug) {
                    Text(Show.spaced(label)).foregroundStyle(Theme.Palette.label)
                    if setting.enabled {
                        TimeEdit(label: "\(label)的时间", value: setting.time, inline: true) { time in
                            save([kind: .object(["enabled": .bool(true), "time": .string(time)])])
                        }
                    }
                }
                .font(Theme.Typeface.body)
                Text(Show.spaced(hint)).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            tryButton(kind, title: "试一下")
            ThemeSwitch(label, isOn: setting.enabled) { value in
                save([kind: .object(["enabled": .bool(value), "time": .string(setting.time)])])
            }
        }
        .padding(.vertical, Theme.Space.small)
        .frame(minHeight: Theme.Size.touch)
        .accessibilityElement(children: .contain)
    }

    private func report(_ kind: String, label: String, hint: String, button: String, enabled: Bool) -> some View {
        SettingRow(label: label, hint: hint) {
            tryButton(kind, title: button)
            ThemeSwitch(label, isOn: enabled) { save([kind: .object(["enabled": .bool($0)])]) }
        }
    }

    @ViewBuilder private func tryButton(_ kind: String, title: String) -> some View {
        if trying == kind {
            Dots(label: "\(title)，正在处理").foregroundStyle(Theme.Palette.accent).frame(minHeight: Theme.Size.touch)
        } else {
            ThemeTextButton(title, font: Theme.Typeface.bodyMedium) { tryNow(kind) }
        }
    }

    private func dnd(enabled: Bool? = nil, from: String? = nil, to: String? = nil) -> JSONValue {
        .object([
            "enabled": .bool(enabled ?? status.dnd.enabled), "from": .string(from ?? status.dnd.from),
            "to": .string(to ?? status.dnd.to),
        ])
    }

    private func save(_ patch: [String: JSONValue]) {
        let client = model.client
        Task {
            do {
                fresh = try await client.saveReminders(patch)
                // 每周回顾的通知是手机排的：改了时间、开关马上重排
                if patch["review"] != nil { model.syncReminders() }
            } catch {
                model.toast(error.readable)
            }
        }
    }

    /// 试一下：发出了就在对话里；周报月报直接打开那一份；没发说为什么
    private func tryNow(_ kind: String) {
        trying = kind
        let client = model.client
        Task {
            defer { trying = nil }
            do {
                let result = try await client.tryReminder(kind)
                if let skipped = result.skipped {
                    model.toast(skipped)
                } else if let report = result.message?.report {
                    model.open(Show.reportPath(report.kind, from: report.period.from))
                } else {
                    model.toast("已经发出，在对话里可以看到", action: "打开对话") { model.chatOpen = true }
                }
            } catch {
                model.toast(error.readable)
            }
        }
    }

    private func testPush() {
        testing = true
        testResult = nil
        let client = model.client
        Task {
            defer { testing = false }
            do {
                let results = try await client.testPush()
                testResult =
                    results.map { item in
                        item.ok
                            ? "\(item.channel == "bark" ? "Bark" : "Server酱")：已发出，看看有没有收到"
                            : (item.message ?? "")
                    }
                    .joined(separator: "\n")
            } catch {
                testResult = error.readable
            }
        }
    }
}
