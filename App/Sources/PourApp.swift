import SwiftUI

@main
struct PourApp: App {
    @UIApplicationDelegateAdaptor(PourAppDelegate.self) private var appDelegate
    @State private var model = AppModel.launch()
    @State private var quickActions = QuickActions.shared
    @Environment(\.scenePhase) private var scenePhase

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
                    model.openLink(path)
                }
                // 按住图标的快捷操作（QuickActions）：回到画布，打开对话、填好开头
                .onChange(of: quickActions.pending, initial: true) { _, type in
                    guard let type, let start = QuickActions.starts[type] else { return }
                    quickActions.pending = nil
                    model.goHome()
                    // 加待办是正式的弹层（第 2 步）；记一笔、记心情第 3、4 步换
                    if type == "pour.todo" { model.todoSheet = .add("") } else { model.startSaying(start) }
                }
                // App 没开着时点了提醒的通知：打开待办
                .onChange(of: quickActions.pendingPath, initial: true) { _, path in
                    guard let path else { return }
                    quickActions.pendingPath = nil
                    model.openLink(path)
                }
        }
        // 进后台时约一次后台刷新：系统挑时候叫醒 App 重排提醒（07 开发任务清单 2.15）
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, model.remindersOn { TodoNotifications.schedule() }
        }
        .backgroundTask(.appRefresh(TodoNotifications.refreshTask)) {
            await TodoNotifications.refreshInBackground()
        }
    }
}
