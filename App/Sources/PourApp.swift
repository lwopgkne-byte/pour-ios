import SwiftUI

@main
struct PourApp: App {
    @State private var model = AppModel.launch()

    var body: some Scene {
        WindowGroup {
            RootView().environment(model)
        }
    }
}
