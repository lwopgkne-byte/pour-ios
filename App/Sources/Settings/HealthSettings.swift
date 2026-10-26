import PourDesign
import SwiftUI

/// 设置里的「健康」（docs/模块/产品优化.md R5）：接上、断开。只读步数、睡眠、锻炼
struct HealthSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingRow(label: "健康 App", hint: "只读步数、睡眠、锻炼，不往健康里写；送到电脑上的 Pour，算进画布、目标、回顾和问答") {
                if model.health.connected {
                    WebTextButton("断开") { model.disconnectHealth() }
                } else if model.health.available {
                    WebButton("接上", variant: .primary) { model.connectHealth() }
                } else {
                    Text("这台设备上没有健康 App")
                }
            }
            if model.health.connected {
                FieldMessage(text: "断开以后不再读，电脑上的 Pour 里送过去的都删掉。系统给 Pour 的读取权限在「设置 → 健康 → 数据访问与设备」里关。")
            }
        }
    }
}

/// 设置里的「日历」（docs/模块/产品优化.md R6）：接上、断开。只读，日程只在这台手机上
struct CalendarSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingRow(label: "日历", hint: "今天的日程出现在待办里；只读，不改日历，不送到电脑上的 Pour") {
                if model.calendar.connected {
                    WebTextButton("断开") { model.calendar.disconnect() }
                } else {
                    WebButton("接上", variant: .primary) { model.connectCalendar() }
                }
            }
            if model.calendar.connected {
                FieldMessage(text: "断开以后不再读。系统给 Pour 的读取权限在 iPhone 的「设置 → 隐私与安全性 → 日历」里关。")
            }
        }
    }
}
