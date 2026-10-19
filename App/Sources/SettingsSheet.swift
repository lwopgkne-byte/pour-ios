import PourAPI
import PourDesign
import SwiftUI
import UIKit

/// 设置（左上角菜单里进）：连的是哪台电脑上的 Pour、连上没有、要不要输 PIN、哪一版。
/// 网页版设置页的其余部分（日界线、提醒、类别、数据）照网页版搬过来以后放在这里
struct SettingsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var address = ServerConfiguration.address.absoluteString
    @State private var pin = ""
    @State private var message: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("状态", value: model.offline == nil ? "连上了" : "没连上")
                    if let offline = model.offline { Text(offline).font(Web.caption).foregroundStyle(Web.fgSecondary) }
                    TextField("地址", text: $address)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("保存地址") { saveAddress() }
                } header: {
                    Text("电脑上的 Pour")
                } footer: {
                    Text("记录和整理都在电脑上的 Pour 里，手机和电脑要在同一个 Wi-Fi 下。")
                }
                Section {
                    SecureField("PIN（4–6 位数字）", text: $pin).keyboardType(.numberPad)
                    Button(busy ? "正在登录……" : "输入 PIN") { Task { await login() } }
                        .disabled(busy || pin.count < 4)
                } header: {
                    Text("PIN")
                } footer: {
                    Text("电脑上的 Pour 开了局域网 PIN 时要输一次。")
                }
                if let message { Section { Text(message).font(Web.caption).foregroundStyle(Web.fgSecondary) } }
                Section("关于") {
                    LabeledContent("Pour", value: AppVersion.current.displayText)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
        .preferredColorScheme(.light)
        .tint(Web.accent)
    }

    private func saveAddress() {
        guard let url = URL(string: address.trimmingCharacters(in: .whitespaces)), url.scheme != nil else {
            message = "地址写得不对，像这样：http://Mac的名字.local:5188"
            return
        }
        ServerConfiguration.remember(address: url)
        message = "保存了。重新打开 Pour 以后连新的地址。"
    }

    private func login() async {
        busy = true
        defer { busy = false }
        do {
            try await model.client.login(pin: pin)
            pin = ""
            message = "登录了。"
            await model.refreshAll()
        } catch {
            message = error.message
        }
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
