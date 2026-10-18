import PourDesign
import Testing
import UIKit

@testable import Pour

@Suite("App 本体：资源和令牌对得上")
@MainActor
struct AppTests {
    /// 启动画面的底色在资源目录里另写了一份（系统画启动画面时还没运行我们的代码），必须和令牌一致
    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func launchScreenColorMatchesCanvasToken(style: UIUserInterfaceStyle) throws {
        let asset = try #require(UIColor(named: "Canvas"))
        let resolved = asset.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        let token = style == .dark ? PourColor.canvas.dark : PourColor.canvas.light
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        #expect(resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        #expect(Int((red * 255).rounded()) == Int(token.rgb.red))
        #expect(Int((green * 255).rounded()) == Int(token.rgb.green))
        #expect(Int((blue * 255).rounded()) == Int(token.rgb.blue))
    }

    /// 隐私清单要真的打进安装包（ADR A20）
    @Test func privacyManifestIsBundled() {
        #expect(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") != nil)
    }

    @Test func versionText() {
        #expect(AppVersion(marketing: "0.1.0", build: "12").displayText == "版本 0.1.0 · 构建 12")
    }
}
