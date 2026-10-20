import SwiftUI

@main
struct PourApp: App {
    @State private var model = AppModel.launch()

    var body: some Scene {
        WindowGroup {
            RootView().environment(model)
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
