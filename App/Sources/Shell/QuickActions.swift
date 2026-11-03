import Observation
import UIKit

/// 按住主屏幕上 Pour 的图标（docs/3.0/06-交互细节.md 第 1 节、07 开发任务清单 1.9b）：「说一句 · 记一笔 · 加待办 · 记心情」，
/// 点了直接打开那一样（第 1 步先打开对话填好开头，第 2–4 步换成正式的弹层）。
/// 菜单写在 Info.plist 的 UIApplicationShortcutItems（project.yml）；系统把点了哪一个交给场景的代理，存在这里，外壳看到就做
@MainActor
@Observable
final class QuickActions {
    static let shared = QuickActions()

    /// 刚点的那一个（做完清掉）
    var pending: String?
    /// App 没开着时点了提醒的通知：外壳起来以后打开这一页（「/todos」）
    var pendingPath: String?

    /// 菜单里的四样：类型 → 对话里先填好的开头（说一句是空的）
    static let starts = ["pour.say": "", "pour.money": "/记 ", "pour.todo": "待办：", "pour.mood": "心情："]
}

/// App 的代理：只为了把场景的代理换成认得快捷操作的那个
final class PourAppDelegate: NSObject, UIApplicationDelegate {
    /// 通知上的按钮要在启动完以前接上（App 没开着时系统在后台叫醒 App 来做，TodoNotifications）
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        TodoNotifications.listen()
        return true
    }

    func application(
        _ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = QuickActionSceneDelegate.self
        return configuration
    }
}

/// 场景的代理：App 没开着时点的（随启动一起送来）、开着时点的，都交给 QuickActions
final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let item = connectionOptions.shortcutItem else { return }
        let type = item.type
        Task { @MainActor in QuickActions.shared.pending = type }
    }

    func windowScene(
        _ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let type = shortcutItem.type
        Task { @MainActor in QuickActions.shared.pending = type }
        completionHandler(QuickActions.starts[type] != nil)
    }
}
