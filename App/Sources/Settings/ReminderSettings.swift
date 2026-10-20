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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsHeading(title: "推送渠道")
            channel(
                "serverchan", label: "Server酱（微信）", key: status.keys.serverchan, enabled: status.channels.serverchan)
            channel("bark", label: "Bark（iPhone）", key: status.keys.bark, enabled: status.channels.bark)
            FieldMessage(text: "推送密钥在电脑上用「Pour 设置」填写。")
            if status.keys.serverchan != nil || status.keys.bark != nil {
                VStack(alignment: .leading, spacing: Web.space2) {
                    WebButton("发一条测试推送", loading: testing) { testPush() }
                    if let testResult {
                        Text(Show.spaced(testResult)).font(Web.caption).foregroundStyle(Web.fgSecondary)
                    }
                }
                .padding(.vertical, Web.space2)
            }
            FieldMessage(text: "提醒只在电脑开着、Pour 运行时发出；推送末尾附上手机能打开的地址。所有提醒也会出现在对话里。")

            SettingsHeading(title: "提醒").padding(.top, Web.space2)
            timed("morning", label: "每日回顾", hint: "早上把昨天整理成一页回顾，连同今天的安排一起推送", status.morning)
            timed("evening", label: "晚上的倾倒提醒", hint: "今天还没记录时。好几天没记的时候会自己变少，一记就恢复", status.evening)
            timed("warning", label: "预警", hint: "目标落后、状态变差", status.warning)
            SettingRow(label: "目标入睡时间", hint: "连续 3 天晚于它会预警") {
                if let bedtime = status.bedtime {
                    TimeEdit(label: "目标入睡时间", value: bedtime) { save(["bedtime": .string($0)]) }
                    WebTextButton("不检查") { save(["bedtime": .null]) }
                } else {
                    // 空着显示灰色的「不检查」，点一下选时间
                    TimeEdit(label: "目标入睡时间", value: "00:00", display: "不检查", unset: true) {
                        save(["bedtime": .string($0)])
                    }
                }
            }
            report("weekly", label: "周报", hint: "每周一早上，总结上周", button: "看上周的", enabled: status.weekly.enabled)
            report("monthly", label: "月报", hint: "每月 1 号早上，总结上个月", button: "看上个月的", enabled: status.monthly.enabled)

            SettingsHeading(title: "免打扰").padding(.top, Web.space2)
            SettingRow(label: "免打扰时段") {
                if status.dnd.enabled {
                    TimeEdit(label: "免打扰开始", value: status.dnd.from) { save(["dnd": dnd(from: $0)]) }
                    Text("到").foregroundStyle(Web.fgTertiary)
                    TimeEdit(label: "免打扰结束", value: status.dnd.to) { save(["dnd": dnd(to: $0)]) }
                }
                WebSwitch("免打扰", isOn: status.dnd.enabled) { save(["dnd": dnd(enabled: $0)]) }
            }
            FieldMessage(text: "免打扰时段里不推送，提醒照常出现在对话里。")
        }
    }

    /// 推送渠道一行：打码的密钥；填过了能开关（填写只能在电脑上用「Pour 设置」）
    private func channel(_ name: String, label: String, key: String?, enabled: Bool) -> some View {
        SettingRow(label: label) {
            Text(key ?? "还没填写").foregroundStyle(key == nil ? Web.fgTertiary : Web.fgSecondary)
            if key != nil {
                WebSwitch("用\(label)推送", isOn: enabled) { value in
                    var channels = [
                        "serverchan": JSONValue.bool(status.channels.serverchan), "bark": .bool(status.channels.bark),
                    ]
                    channels[name] = .bool(value)
                    save(["channels": .object(channels)])
                }
            }
        }
    }

    /// 有时间的提醒：开着才显示时间；「试一下」马上发一条
    private func timed(_ kind: String, label: String, hint: String, _ setting: API.ReminderStatus.Timed) -> some View {
        SettingRow(label: label, hint: hint) {
            if setting.enabled {
                TimeEdit(label: "\(label)的时间", value: setting.time) { time in
                    save([kind: .object(["enabled": .bool(true), "time": .string(time)])])
                }
            }
            tryButton(kind, title: "试一下")
            WebSwitch(label, isOn: setting.enabled) { value in
                save([kind: .object(["enabled": .bool(value), "time": .string(setting.time)])])
            }
        }
    }

    private func report(_ kind: String, label: String, hint: String, button: String, enabled: Bool) -> some View {
        SettingRow(label: label, hint: hint) {
            tryButton(kind, title: button)
            WebSwitch(label, isOn: enabled) { save([kind: .object(["enabled": .bool($0)])]) }
        }
    }

    @ViewBuilder private func tryButton(_ kind: String, title: String) -> some View {
        if trying == kind {
            Dots(label: "\(title)，正在处理").foregroundStyle(Web.accent).frame(minHeight: Web.touch)
        } else {
            WebTextButton(title) { tryNow(kind) }
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
