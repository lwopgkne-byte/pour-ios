import Foundation

/// 打开 App：连哪个服务器、要不要直接打开某一天；画布样张开、关时换一个新的 AppModel
extension AppModel {
    /// 换了 AppModel 以后先打开对话（样张里说了一句，回到服务器的数据时看它整理）
    static var openChatOnLaunch = false

    static func launch() -> AppModel {
        let arguments = ProcessInfo.processInfo.arguments
        CanvasSamples.readArguments(arguments)
        // 界面测试每次从头开始：上一个测试没发出去的话不留到这一个
        if arguments.contains("-uiTest") { UserDefaults.standard.removeObject(forKey: OutboxStore.key) }
        let model = AppModel(client: ServerConfiguration.client(arguments: arguments))
        model.start()
        // 开发时对照演示数据：-day 2026-10-15 直接打开那一天
        if let index = arguments.firstIndex(of: "-day"), index + 1 < arguments.count {
            model.show(arguments[index + 1])
        }
        if openChatOnLaunch {
            openChatOnLaunch = false
            model.chatOpen = true
        }
        return model
    }

    /// 打开、关掉画布样张：记下开关，PourApp 换一个连着新数据来源的 AppModel（旧的连接停掉）
    func showSamples(_ isOn: Bool) {
        CanvasSamples.set(isOn)
        replaced = true
    }
}
