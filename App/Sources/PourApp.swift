import SwiftUI

@main
struct PourApp: App {
    @State private var model = AppModel.launch()

    var body: some Scene {
        WindowGroup {
            RootView().environment(model)
                // 换了一个 AppModel（画布样张开、关）：整个界面从头来
                .id(ObjectIdentifier(model))
                .onChange(of: model.replaced) { _, now in
                    guard now else { return }
                    model.stop()
                    model = AppModel.launch()
                }
                // 字号最大到 xxxLarge（系统「更大字体」打开之前的最后一档），辅助功能那几档也按这一档显示：
                // 产品主人 2026-10-21「那种的不要兼容，因为很少人会字体放那么大」
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                // pour://open?path=/review/2026-10-18：打开那一页；只是 pour:// 就回到 App（推送点进来）
                .onOpenURL { url in
                    // pour://voice：小组件、控制中心的「说一句」——打开就开始听
                    if url.scheme == "pour", url.host() == "voice" {
                        model.requestVoice()
                        return
                    }
                    guard url.scheme == "pour", url.host() == "open",
                        let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                            .first(where: { $0.name == "path" })?.value, path.hasPrefix("/")
                    else { return }
                    model.open(path)
                }
        }
    }
}
