import PourAI
import PourDesign
import SwiftUI
import UIKit

/// 设置（从「今天」左上角的头像进）。M2a 只有「关于」：哪一版、AI 网关连没连上——验收时对得上构建号，
/// 整理不动时一眼看出是不是网关没开。越来越懂你、通知、隐私中心、Face ID 以后再加（规范 12 第 2 节）
struct SettingsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var health: GatewayHealth?
    @State private var address = GatewayConfiguration.address.absoluteString
    @State private var code = ""
    @State private var pairing = false
    @State private var pairMessage: String?

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
                pairSection
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

    /// 真机第一次连这台 Mac：输网关显示的 6 位配对码（模拟器直接连本机，不用配对）
    @ViewBuilder private var pairSection: some View {
        #if targetEnvironment(simulator)
            EmptyView()
        #else
            Section {
                TextField("网关地址", text: $address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                TextField("6 位配对码", text: $code)
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier("settings.code")
                Button(pairing ? "正在连……" : "连上这台 Mac") { Task { await pair() } }
                    .disabled(pairing || code.count != 6)
                if let pairMessage {
                    Text(pairMessage).pourText(.callout).foregroundStyle(PourColor.inkSecondary.color)
                }
            } header: {
                Text(GatewayConfiguration.isPaired ? "连这台 Mac（已经连上了）" : "连这台 Mac")
            } footer: {
                Text("配对码显示在 Mac 上网关的窗口里。配好以后，这台手机和 Mac 在同一个 Wi-Fi 下就能整理。")
            }
        #endif
    }

    private func pair() async {
        guard let url = URL(string: address.trimmingCharacters(in: .whitespaces)) else {
            pairMessage = "地址写得不对，像这样：http://Mac的名字.local:5480"
            return
        }
        pairing = true
        defer { pairing = false }
        do {
            let token = try await GatewayClient(baseURL: url).pair(code: code, device: UIDevice.current.name)
            GatewayConfiguration.remember(address: url, token: token)
            code = ""
            pairMessage = "连上了。"
            health = await model.gateway.health(deep: true)
        } catch .server(_, let message, _) {
            pairMessage = message
        } catch {
            pairMessage = "连不上：手机和 Mac 要在同一个 Wi-Fi 下，Mac 上的网关要开着。"
        }
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
