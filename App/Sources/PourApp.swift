import SwiftUI

@main
struct PourApp: App {
    @State private var model = AppModel.launch()

    var body: some Scene {
        WindowGroup {
            RootView().environment(model)
                // 字号最大到 xxxLarge（系统「更大字体」打开之前的最后一档），辅助功能那几档也按这一档显示：
                // 产品主人 2026-10-21「那种的不要兼容，因为很少人会字体放那么大」
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                // pour://open?path=/review/2026-10-18：打开那一页；只是 pour:// 就回到 App（推送点进来）
                .onOpenURL { url in
                    guard url.scheme == "pour", url.host() == "open",
                        let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                            .first(where: { $0.name == "path" })?.value, path.hasPrefix("/")
                    else { return }
                    model.open(path)
                }
        }
    }
}
