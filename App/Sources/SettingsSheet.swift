import PourAI
import PourDesign
import SwiftUI

/// 设置（从「今天」左上角的头像进）。M2a 只有「关于」：哪一版、AI 网关连没连上——验收时对得上构建号，
/// 整理不动时一眼看出是不是网关没开。越来越懂你、通知、隐私中心、Face ID 以后再加（规范 12 第 2 节）
struct SettingsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var health: GatewayHealth?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("版本", value: AppVersion.current.displayText)
                        .accessibilityIdentifier("settings.version")
                } header: {
                    Text("关于 Pour")
                }
                Section {
                    LabeledContent("地址", value: model.gateway.baseURL.absoluteString)
                    LabeledContent("状态", value: status)
                        .accessibilityIdentifier("settings.gateway")
                } header: {
                    Text("AI 网关")
                } footer: {
                    Text("整理时，原话经过这台 Mac 上的网关交给 AI 服务商；网关不保存任何东西。")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
            .task { health = await model.gateway.health(deep: true) }
        }
        .tint(PourColor.action.color)
    }

    private var status: String {
        guard let health else { return "正在问……" }
        guard health.reachable else { return "连不上：网关没开，或者不在同一个网络" }
        let key =
            switch health.key {
            case "valid": "密钥能用"
            case "invalid": "密钥不对"
            case "missing": "还没填密钥"
            default: health.problem ?? "密钥没查成"
            }
        return "连上了 · \(health.model ?? "") · \(key)"
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
