import PourAPI
import PourDesign
import PourPlatform
import SwiftUI

/// 设置 →「提醒和推送」里的「晚上问问心情」（docs/3.0/01-需求文档.md 6.4，默认关，只记在这台手机上）：
/// 打开以后每天晚上问一句，按住通知直接选一档；和「晚上的倾倒提醒」合成一种——打开时电脑那边的倾倒提醒不再推，关了再恢复
struct MoodEveningRow: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoodEvening.key) private var asking = false
    @AppStorage(MoodEvening.timeKey) private var time = MoodEvening.defaultTime
    @AppStorage(MoodEvening.mergedKey) private var merged = false
    let evening: API.ReminderStatus.Timed
    let save: ([String: JSONValue]) -> Void
    @State private var scheduled = 0

    var body: some View {
        SettingRow(label: "晚上问问心情", hint: hint) {
            if asking {
                TimeEdit(label: "晚上问心情的时间", value: time) { picked in
                    time = picked
                    resync()
                }
            }
            ThemeSwitch("晚上问问心情", isOn: asking) { toggle($0) }
        }
        .task(id: "\(asking)-\(time)") { scheduled = await EveningMood.pending() }
    }

    private var hint: String {
        guard asking else { return "每天晚上问一句今天心情怎么样，按住通知直接选一档，不用打开 Pour" }
        let done = scheduled > 0 ? " · 手机上排好了 \(scheduled) 个晚上" : ""
        return "每天 \(time) 问一句，按住通知直接选一档。和晚上的倾倒提醒合成了这一种（电脑那边不再推）\(done)"
    }

    private func toggle(_ value: Bool) {
        asking = value
        if value, evening.enabled {
            merged = true
            save(["evening": .object(["enabled": .bool(false), "time": .string(evening.time)])])
        } else if !value, merged {
            merged = false
            save(["evening": .object(["enabled": .bool(true), "time": .string(evening.time)])])
        }
        resync()
    }

    private func resync() {
        Task {
            await model.syncEveningMood()
            scheduled = await EveningMood.pending()
        }
    }
}
