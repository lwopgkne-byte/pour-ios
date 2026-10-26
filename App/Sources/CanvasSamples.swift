import Foundation

/// 画布样张（产品主人 2026-10-26：「现在只做了生活画布，我希望在生活画布上面能够看到所有的功能」）：
/// 打开后不连服务器，用 App 里的假服务器，这一周每天是一种人的一天（StubServer+Canvas 的 CanvasSample.week），
/// 左右滑一遍就看到画布的每一种卡片和样子。开关存在这台手机上；从电脑上打开 App 时也能用启动参数
/// 「-canvasSamples on / off」开关。只在开发版里有（装到手机上的就是开发版）
enum CanvasSamples {
    static let key = "pour.canvasSamples"

    static var isOn: Bool {
        #if DEBUG
            UserDefaults.standard.bool(forKey: key)
        #else
            false
        #endif
    }

    static func set(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
    }

    /// 启动参数只认一次：退出样张后换新的 AppModel 时，不能又被启动参数打开
    nonisolated(unsafe) private static var argumentsRead = false

    static func readArguments(_ arguments: [String]) {
        guard !argumentsRead else { return }
        argumentsRead = true
        if let index = arguments.firstIndex(of: "-canvasSamples"), index + 1 < arguments.count {
            set(arguments[index + 1] == "on")
        } else if arguments.contains("-uiTest") {
            // 界面测试一个一个独立：上一个测试没走完、留下的样张开关不算（不然后面的测试都在样张里跑）
            set(false)
        }
    }
}
