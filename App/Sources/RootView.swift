import PourAPI
import PourDesign
import SwiftUI

/// App 的外壳：顶栏左上角菜单、右上角搜索，中间是生活画布，
/// 底部是输入框；发出去就向上展开对话面板，后面的页面轻微压暗，点暗处收起
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var navOpen = false
    /// 说话（输入框的麦克风）：手机上的听写；界面测试用假的
    @State private var voice = VoiceSession(input: VoiceSession.makeInput())

    var body: some View {
        // 看得见的高度（键盘弹出时是键盘上面那一截）：对话面板占它的 55%
        GeometryReader { proxy in
            if model.needsPin {
                PinGate()
            } else {
                shell.environment(\.visibleHeight, proxy.size.height).environment(voice)
            }
        }
    }

    private var shell: some View {
        @Bindable var model = model
        return VStack(spacing: 0) {
            // 生活画布 2.0 自己有浮着的玻璃按钮和「演示数据」小胶囊；别的页面还是原来的顶栏和横幅
            if model.page != .canvas {
                AppHeader(navOpen: $navOpen) { model.search = "" }
                if model.mode == "demo" { DemoBanner() }
            }
            PageView(page: model.page) { withAnimation(Web.panel) { navOpen = true } }
        }
        // 搜索、对话面板开着：后面压暗、被盖住的页面读屏不读、不算进审计
        .accessibilityHidden(model.search != nil || model.chatOpen)
        .background(Web.bg)
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
                    Toast(message: notice.message, action: notice.action) { model.performNotice() }
                        .themeTransition(.move(edge: .bottom).combined(with: .opacity))
                        .id(notice.id)
                }
                Composer()
            }
        }
        .overlay { NavDrawer(open: $navOpen) }
        .animation(Web.panel, value: model.chatOpen)
        .animation(Web.panel, value: model.notice)
        .sheet(item: $model.detail) { ref in EntryPeek(entryId: ref.id, day: ref.day) }
        .sheet(item: $model.goalDetail) { ref in GoalPeek(goalId: ref.id) }
        // 右上角的搜索、「/找 三体」：浮在页面上面，后面压暗
        .overlay {
            if let search = model.search {
                SearchPalette(initial: search).transition(.opacity)
            }
        }
        .animation(Web.fast, value: model.search != nil)
        // 只有一种样子（亮色）：产品主人 2026-10-21「把黑色的风格去掉，只要一种」
        .preferredColorScheme(.light)
        .tint(Web.accent)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.becameActive() }
        }
    }
}

extension EnvironmentValues {
    /// 看得见的高度（不算键盘）
    @Entry var visibleHeight: CGFloat = 800
}

/// 顶栏：左上角菜单，右上角搜索（48 点高，白底）
private struct AppHeader: View {
    @Binding var navOpen: Bool
    let search: () -> Void

    var body: some View {
        HStack {
            iconButton("line.3.horizontal", label: "菜单") { withAnimation(Web.panel) { navOpen = true } }
                .accessibilityIdentifier("today.menu")
            Spacer()
            iconButton("magnifyingglass", label: "搜索", action: search)
        }
        .padding(.horizontal, Web.space2)
        .frame(height: Web.header)
        .background(Web.bg)
    }

    private func iconButton(_ name: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(Web.section).foregroundStyle(Web.fgSecondary)
                .frame(width: Web.touch, height: Web.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

/// 演示数据：页面顶上一条安静但清楚的横幅（规格第十三章）
private struct DemoBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            Text("正在看演示数据，你的真实数据没有变化 · ")
            WebTextButton("回到真实数据", font: Web.captionMedium) { model.open("/settings#data") }
        }
        .font(Web.caption).foregroundStyle(Web.notice.fg)
        .multilineTextAlignment(.center)
        .padding(.vertical, Web.space2).padding(.horizontal, Web.space4)
        .frame(maxWidth: .infinity)
        .background(Web.notice.bg)
    }
}

/// 左侧导航：点哪一页换到哪一页
private struct NavDrawer: View {
    @Environment(AppModel.self) private var model
    @Binding var open: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            if open {
                Web.overlay.ignoresSafeArea()
                    .onTapGesture { close() }
                    .accessibilityLabel(Text("关闭菜单"))
                    .accessibilityAddTraits(.isButton)
                    .transition(.opacity)
                VStack(alignment: .leading, spacing: Web.space1) {
                    ForEach(Page.allCases) { page in
                        link(page.label, icon: page.icon, current: model.page == page) {
                            close()
                            model.page = page
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, Web.space2)
                .padding(.vertical, Web.space3)
                .frame(width: min(Web.navWidth, UIScreenWidth.value * 0.85))
                .frame(maxHeight: .infinity, alignment: .top)
                .background(Web.bgSubtle.ignoresSafeArea())
                .themeTransition(.move(edge: .leading))
            }
        }
        .animation(Web.panel, value: open)
    }

    private func link(_ label: String, icon: String, current: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Web.space2) {
                Image(systemName: icon).foregroundStyle(current ? Web.fgSecondary : Web.fgTertiary)
                    .frame(width: Web.icon)
                Text(label).foregroundStyle(current ? Web.fg : Web.fgSecondary)
                    .fontWeight(current ? .medium : .regular)
                Spacer(minLength: 0)
            }
            .font(Web.body)
            .padding(.horizontal, Web.space2)
            .frame(minHeight: Web.touch)
            .background(RoundedRectangle(cornerRadius: Web.radiusControl).fill(current ? Web.bgPressed : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(current ? .isSelected : [])
    }

    private func close() {
        withAnimation(Web.panel) { open = false }
    }
}

/// 屏幕宽度（导航最宽 240 点、不超过屏幕的 85%）
enum UIScreenWidth {
    @MainActor static var value: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.width ?? Web.navWidth
    }
}

/// 轻提示（生活画布2.0.md 第 6 节）：输入框上面一条玻璃胶囊，右边可以有一个操作（「撤销」）
private struct Toast: View {
    let message: String
    let action: String?
    let perform: () -> Void

    var body: some View {
        HStack(spacing: Theme.Space.medium) {
            Text(Show.spaced(message)).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.label)
            if let action {
                Button(action, action: perform).font(Theme.Typeface.cardTitle).foregroundStyle(Theme.Palette.accent)
                    .buttonStyle(.plain).frame(minHeight: Theme.Size.touch)
                    .accessibilityIdentifier("undoToast")
            }
        }
        .padding(.horizontal, Theme.Space.regular)
        .frame(minHeight: Theme.Size.touch)
        .themeGlass(radius: Theme.Corner.composer)
    }
}
