import PourAPI
import PourDesign
import PourPlatform
import SwiftUI

/// 设置：大模型、AI 准不准、提醒和推送、类别、个人词典、局域网访问、数据。
/// 最后一块「这台手机」：连哪台电脑上的 Pour
struct SettingsPage: View {
    @Environment(AppModel.self) private var model
    /// 打开时滚到哪一块：画布上点「演示数据 · 回到真实数据」（/settings#data）直接到「数据」；
    /// 「我的」里的健康格子（/settings#health）到「健康」
    let anchor: String?

    var body: some View {
        ScrollViewReader { reader in
            page.onAppear { jump(reader) }
        }
    }

    private func jump(_ reader: ScrollViewProxy) {
        guard let anchor, ["data", "health"].contains(anchor) else { return }
        withAnimation(Web.panel) { reader.scrollTo(anchor, anchor: .top) }
    }

    private var page: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Web.space12) {
                VStack(alignment: .leading, spacing: Web.space8) {
                    Text("设置").font(Web.title).foregroundStyle(Web.fg).accessibilityAddTraits(.isHeader)
                    SettingsSection(title: "大模型") { LlmSettings() }
                }
                SettingsSection(title: "AI 准不准") { EvalSettings() }
                SettingsSection(title: "提醒和推送") { ReminderSettings() }
                SettingsSection(title: "类别") { CategorySettings() }
                SettingsSection(title: "个人词典") {
                    // 搬进了「关于我」：AI 用到的对你的了解都在那一处，能看、能改
                    Button {
                        model.open("/about")
                    } label: {
                        SettingRow(label: "个人词典搬到了「关于我」") { Text("→").accessibilityHidden(true) }
                            .padding(.horizontal, Web.space2)
                    }
                    .buttonStyle(WebPressStyle(radius: Web.radiusControl))
                    .padding(.horizontal, -Web.space2)
                }
                SettingsSection(title: "局域网访问") { LanSettings() }
                SettingsSection(title: "数据") { DataSettings() }.id("data")
                SettingsSection(title: "健康") { HealthSettings() }.id("health")
                SettingsSection(title: "日历") { CalendarSettings() }
                SettingsSection(title: "这台手机") { PhoneSettings() }
            }
            .padding(.horizontal, Web.space4)
            .padding(.top, Web.space4)
            .padding(.bottom, Web.space12)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

/// 这台手机连的是哪台电脑上的 Pour（只有手机上有）：地址、连上没有、版本（要输 PIN 时整个 App 先显示 PinGate）
private struct PhoneSettings: View {
    @Environment(AppModel.self) private var model
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingRow(label: "电脑上的 Pour", hint: "手机和电脑在同一个 WiFi 时，用这个地址连") {
                InlineEdit(
                    label: "电脑上的 Pour 的地址", value: ServerConfiguration.address.absoluteString,
                    keyboard: .URL, validate: Self.checkAddress,
                    onSave: { text in
                        guard let url = URL(string: text.trimmingCharacters(in: .whitespaces)) else { return }
                        ServerConfiguration.remember(address: url)
                        saved = true
                    })
            }
            if saved { FieldMessage(text: "下次打开 App 时用新的地址。") }
            SettingRow(label: "连接") {
                if let offline = model.offline {
                    Text(offline).foregroundStyle(Web.danger)
                } else {
                    Text("已连上")
                }
            }
            SettingRow(label: "版本") { Text(AppVersion.current.displayText) }
            // 电脑上的 Pour 是哪个版本（docs/模块/产品优化.md R8）
            if let server = model.serverVersionText { SettingRow(label: "电脑上的 Pour") { Text(server) } }
        }
    }

    private static func checkAddress(_ text: String) -> String? {
        URL(string: text.trimmingCharacters(in: .whitespaces))?.host == nil ? "地址写成 http://电脑的名字.local:5188 这样" : nil
    }
}

/// 这一版的版本号和构建号（构建号由 scripts/install-device.sh 按提交数写入）
struct AppVersion: Equatable {
    let marketing: String
    let build: String

    static var current: AppVersion {
        let info = Bundle.main.infoDictionary ?? [:]
        return AppVersion(
            marketing: info["CFBundleShortVersionString"] as? String ?? "0",
            build: info["CFBundleVersion"] as? String ?? "0")
    }

    var displayText: String {
        String(localized: "版本 \(marketing) · 构建 \(build)", comment: "设置里的版本号，例如「版本 0.1.0 · 构建 12」")
    }
}
