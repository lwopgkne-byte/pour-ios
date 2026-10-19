import PourDesign
import SwiftUI
import Testing
import UIKit

@testable import Pour

@Suite("App 本体：资源和令牌对得上")
@MainActor
struct AppTests {
    /// 启动画面的底色在资源目录里另写了一份（系统画启动画面时还没运行我们的代码），必须和页面底色一致：
    /// 照网页版是白（Web.bg）；App 照网页版只用亮色，系统是暗色模式时也是白
    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func launchScreenColorMatchesPageBackground(style: UIUserInterfaceStyle) throws {
        let asset = try #require(UIColor(named: "Canvas"))
        let resolved = asset.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        #expect(Self.rgb(resolved) == Self.rgb(UIColor(Web.bg)))
    }

    private static func rgb(_ color: UIColor) -> [Int] {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        _ = color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue].map { Int(($0 * 255).rounded()) }
    }

    /// 隐私清单要真的打进安装包（ADR A20）
    @Test func privacyManifestIsBundled() {
        #expect(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") != nil)
    }

    @Test func versionText() {
        #expect(AppVersion(marketing: "0.1.0", build: "12").displayText == "版本 0.1.0 · 构建 12")
    }
}
