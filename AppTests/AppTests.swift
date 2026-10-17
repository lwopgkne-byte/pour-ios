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
        #expect(Int((red * 255).rounded()) == Int(token.red))
        #expect(Int((green * 255).rounded()) == Int(token.green))
        #expect(Int((blue * 255).rounded()) == Int(token.blue))
    }

    /// 原话之声用宋体（规范 02）：Font.custom 找不到字体时会悄悄换成系统字，所以要真的确认系统里有。
    /// M0 实测（2026-10-17，iOS 26.5）：iPhone 没有预装宋体（只有苹方），规范的这个前提不成立。
    /// 怎么解决是 M1 的设计决定（按需下载系统字体 / 内置思源宋体 / 换方向），先记成已知问题；
    /// 解决后这里会报「已知问题没有出现」，提醒把标记去掉。
    @Test func songtiIsAvailableOnDevice() {
        withKnownIssue("iPhone 没有预装宋体，M1 决定原话之声用什么字") {
            #expect(UIFont.familyNames.contains("Songti SC"))
        }
    }

    /// 隐私清单要真的打进安装包（ADR A20）
    @Test func privacyManifestIsBundled() {
        #expect(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") != nil)
    }

    @Test func versionText() {
        #expect(AppVersion(marketing: "0.1.0", build: "12").displayText == "版本 0.1.0 · 构建 12")
    }
}
