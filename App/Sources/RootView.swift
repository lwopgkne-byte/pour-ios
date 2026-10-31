import PourAPI
import PourDesign
import SwiftUI

/// App 的外壳（3.0，docs/3.0/01-需求文档.md 第 2 章、06 交互细节第 1 节）：没有标签栏。
/// 一个导航栈，根是生活画布；左上角「我」进全部功能，别的页都推进来，返回一路回到画布。
/// 底部只有「说一句」，每一页都在；发出去就向上展开对话面板，后面的页面轻微压暗，点暗处收起
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    /// 说话（输入框的麦克风）：手机上的听写；界面测试用假的
    @State private var voice = VoiceSession(input: VoiceSession.makeInput())
    /// 底部那一整块（轻提示、整理到哪的小条、输入框）有多高：每一页底下留出这么高，滚到底最后一行也露在它上面
    @State private var barHeight: CGFloat = 0

    /// 要删的重复待办：问「只删这一次 / 以后都不要了」
    private var deletingRepeat: Binding<Bool> {
        Binding {
            model.todoDeleting != nil
        } set: {
            if !$0 { model.todoDeleting = nil }
        }
    }

    var body: some View {
        // 看得见的高度（键盘弹出时是键盘上面那一截）：对话面板占它的 55%
        GeometryReader { proxy in
            if Self.widgetSamples {
                #if DEBUG
                    WidgetSamplesView()
                #endif
            } else if model.needsPin {
                PinGate()
            } else {
                shell.environment(\.visibleHeight, proxy.size.height).environment(voice)
            }
        }
    }

    /// 开发版的「小组件样张」（启动参数 -widgetSamples）
    private static let widgetSamples = ProcessInfo.processInfo.arguments.contains("-widgetSamples")

    private var barHidden: Bool {
        model.sayBarHidden && !model.chatOpen && model.draft.isEmpty && model.notice == nil
    }

    private var shell: some View {
        @Bindable var model = model
        return NavigationStack(path: $model.stack) {
            CanvasView()
                .hiddenWhenCovered()
                .sayBarSpace(barHeight)
                .navigationDestination(for: Route.self) { route in
                    RouteView(route: route).hiddenWhenCovered().sayBarSpace(barHeight)
                }
        }
        // 没连上、页面显示的是上次存的：顶上一条细条说是几点的（docs/3.0/01-需求文档.md 3.3）
        .safeAreaInset(edge: .top, spacing: 0) {
            if let since = model.staleSince {
                StaleBar(since: since).transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Theme.Motion.standard, value: model.staleSince)
        .overlay {
            if model.chatOpen {
                // 只压暗上面的页面，不盖住底下的输入框（不然点「收起」会同时点到压暗的那一层）
                Theme.Palette.dim.ignoresSafeArea(edges: .top)
                    .onTapGesture { withAnimation(Theme.Motion.standard) { model.chatOpen = false } }
                    .accessibilityLabel(Text("收起对话"))
                    .accessibilityAddTraits(.isButton)
                    .transition(.opacity)
            }
        }
        // 底下的输入框是一条「栏」（safeAreaBar）：页面滑到它下面时自动柔化淡出，玻璃上的提示语不和后面的字叠在一起
        .safeAreaBar(edge: .bottom, spacing: 0) {
            VStack(spacing: Theme.Space.small) {
                if let notice = model.notice {
                    ThemeToast(Show.spaced(notice.message), action: notice.action) { model.performNotice() }
                        .themeTransition(.move(edge: .bottom).combined(with: .opacity))
                        .id(notice.id)
                }
                Composer()
            }
            // 量高度：每一页底下留出这么高（挂在导航栈外面的这一块，系统不会替里面的页留位置，2026-10-31 查出来的）
            .onGeometryChange(for: CGFloat.self) {
                $0.size.height
            } action: {
                barHeight = $0
            }
            // 界面测试认底部这一整块（轻提示、整理到哪的小条、输入框）用：滚页面时别把要点的东西压在它下面
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("say.bar")
            // 往下翻看内容时收起（不挡最后一行），往上翻、对话开着、正在输入时都在
            .offset(y: barHidden ? Theme.Size.composer * 2 : 0)
            .opacity(barHidden ? 0 : 1)
            .animation(Theme.Motion.standard, value: barHidden)
        }
        .animation(Web.panel, value: model.chatOpen)
        .animation(Web.panel, value: model.notice)
        .sheet(item: $model.detail) { ref in EntryPeek(entryId: ref.id, day: ref.day) }
        .sheet(item: $model.goalDetail) { ref in GoalPeek(goalId: ref.id) }
        // 待办的弹层（3.0 第 2 步）：加待办、详情、推迟到哪——待办页、画布、「我的」、通知都打开这几个
        .sheet(item: $model.todoSheet) { sheet in
            switch sheet {
            case .add(let text): TodoAddSheet(text: text)
            case .detail(let row): TodoDetailSheet(row: row)
            case .snooze(let row): TodoSnoozeSheet(row: row)
            }
        }
        // 重复的待办删的时候问一句（01 需求文档 4.4）
        .confirmationDialog(
            "这是重复的待办", isPresented: deletingRepeat, titleVisibility: .visible, presenting: model.todoDeleting
        ) { row in
            Button("只删这一次", role: .destructive) { model.deleteTodo(row, onlyThisTime: true) }
            Button("以后都不要了", role: .destructive) { model.deleteTodo(row, onlyThisTime: false) }
            Button("不删了", role: .cancel) {}
        } message: { row in
            Text(row.repeatText.map { "「\(row.content)」\($0)都会有" } ?? row.content)
        }
        // 画布右上角的搜索、「/找 三体」：浮在页面上面，后面压暗
        .overlay {
            if let search = model.search {
                SearchPalette(initial: search).transition(.opacity)
            }
        }
        .animation(Web.fast, value: model.search != nil)
        // 只有一种样子（亮色）：产品主人 2026-10-21「把黑色的风格去掉，只要一种」
        .preferredColorScheme(.light)
        .tint(Theme.Palette.accent)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.becameActive() }
        }
    }
}

extension EnvironmentValues {
    /// 看得见的高度（不算键盘）
    @Entry var visibleHeight: CGFloat = 800
}

extension View {
    /// 这一页翻动时「说一句」跟着收起、出来（docs/3.0/01-需求文档.md 2.2）：往下翻过一屏顶上那一截就收起，往上翻就出来
    func sayBarFollowsScroll() -> some View {
        modifier(SayBarFollowsScroll())
    }
}

private struct SayBarFollowsScroll: ViewModifier {
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { before, now in
            let moved = now - before
            if moved > Theme.Space.tight, now > Theme.Size.touch * 2 {
                if !model.sayBarHidden { model.sayBarHidden = true }
            } else if moved < -Theme.Space.tight || now <= 0 {
                if model.sayBarHidden { model.sayBarHidden = false }
            }
        }
    }
}

/// 没连上时顶上那一条：「没连上 · 显示的是 10:32 的」（不是今天存的写日子）
private struct StaleBar: View {
    let since: Date

    var body: some View {
        Text(Self.text(since, now: Date()))
            .font(Theme.Typeface.footnoteMedium).foregroundStyle(Theme.Palette.secondaryLabel)
            .padding(.horizontal, Theme.Space.medium).frame(minHeight: Theme.Size.badge)
            .background(Theme.Palette.statFill, in: Capsule())
            .frame(maxWidth: .infinity)
            .padding(.bottom, Theme.Space.tight)
            .accessibilityIdentifier("stale")
    }

    static func text(_ since: Date, now: Date) -> String {
        let clock = since.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        guard !Calendar.current.isDate(since, inSameDayAs: now) else { return "没连上 · 显示的是 \(clock) 的" }
        let day = since.formatted(.dateTime.month(.defaultDigits).day())
        return "没连上 · 显示的是 \(day) \(clock) 的"
    }
}

extension View {
    /// 搜索、对话面板开着：后面压暗、被盖住的这一页读屏不读、不算进审计。
    /// 要加在导航栈里面的每一页上：加在导航栈外面传不进去（2026-10-31 界面测试查出来的）
    func hiddenWhenCovered() -> some View {
        modifier(HiddenWhenCovered())
    }
}

private struct HiddenWhenCovered: ViewModifier {
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        content.accessibilityHidden(model.search != nil || model.chatOpen)
    }
}

extension View {
    /// 底下留出「说一句」那一整块的高度：滚到底，最后一行也露在它上面、点得到
    func sayBarSpace(_ height: CGFloat) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: height).allowsHitTesting(false) }
    }
}
