import PourDesign
import SwiftUI

/// M0 的启动页：回答「装上的是不是 Pour、是哪一版」。
/// 纸色底上一个安静的字标，底部一行版本号——验收时对得上我报给你的构建号。
/// M2 起这里换成「今天」。
struct LaunchView: View {
    let version: AppVersion

    var body: some View {
        ZStack {
            PourColor.canvas.color.ignoresSafeArea()

            PourBrandMark()
                .accessibilityIdentifier("launch.brand")
        }
        .safeAreaInset(edge: .bottom) {
            Text(version.displayText)
                .pourText(.caption)
                .monospacedDigit()
                .foregroundStyle(PourColor.inkSecondary.color)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PourSpace.card)
                .padding(.bottom, PourSpace.card)
                .accessibilityIdentifier("launch.version")
        }
    }
}

/// 这一版的版本号和构建号（构建号由 ios/scripts/install-device.sh 按提交数写入）
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
        String(localized: "版本 \(marketing) · 构建 \(build)", comment: "启动页底部的版本号，例如「版本 0.1.0 · 构建 12」")
    }
}

#Preview("亮色") {
    LaunchView(version: AppVersion(marketing: "0.1.0", build: "1"))
}

#Preview("暗色") {
    LaunchView(version: AppVersion(marketing: "0.1.0", build: "1"))
        .preferredColorScheme(.dark)
}
