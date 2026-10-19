import PourDesign
import SwiftUI

/// App 的外壳（网页版 Layout 手机那一档 1 比 1）：顶栏左上角菜单、右上角搜索，中间是生活画布，
/// 底部是输入框；发出去就向上展开对话面板，后面的页面轻微压暗，点暗处收起
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var navOpen = false
    @State private var showsSettings = false
    @State private var showsLater: String?

    var body: some View {
        // 看得见的高度（键盘弹出时是键盘上面那一截）：对话面板占它的 55%（网页版 --viewport-height × 0.55）
        GeometryReader { proxy in
            shell.environment(\.visibleHeight, proxy.size.height)
        }
    }

    private var shell: some View {
        @Bindable var model = model
        return VStack(spacing: 0) {
            AppHeader(navOpen: $navOpen) { showsLater = "搜索" }
            CanvasView()
        }
        .background(Web.bg)
        .overlay {
            if model.chatOpen {
                // 只压暗上面的页面，不盖住底下的输入框（不然点「收起」会同时点到压暗的那一层）
                Web.overlay.ignoresSafeArea(edges: .top)
                    .onTapGesture { withAnimation(Web.panel) { model.chatOpen = false } }
                    .accessibilityLabel(Text("收起对话"))
                    .accessibilityAddTraits(.isButton)
                    .transition(.opacity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: Web.space3) {
                if let undo = model.undoable {
                    Toast(message: undo.message, action: "撤销") { model.undo() }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .id(undo.id)
                }
                Composer()
            }
        }
        .overlay { NavDrawer(open: $navOpen, settings: $showsSettings, later: $showsLater) }
        .animation(Web.panel, value: model.chatOpen)
        .animation(Web.panel, value: model.undoable)
        .sheet(item: $model.detail) { ref in EntryDetailView(entryId: ref.id) }
        .sheet(isPresented: $showsSettings) { SettingsSheet() }
        .alert(
            "\(showsLater ?? "")还在做",
            isPresented: .init(get: { showsLater != nil }, set: { if !$0 { showsLater = nil } })
        ) {
            Button("好") { showsLater = nil }
        } message: {
            Text("先做好生活画布，别的页面一个一个照网页版搬过来。")
        }
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

/// 左侧导航（网页版 NavDrawer）：页面一个一个照网页版搬，还没搬的点了说一声
private struct NavDrawer: View {
    @Binding var open: Bool
    @Binding var settings: Bool
    @Binding var later: String?

    private static let pages: [(label: String, icon: String)] = [
        ("生活画布", "square.grid.2x2"), ("回顾", "book"), ("钱", "yensign.circle"), ("关于我", "person"),
        ("目标", "target"), ("笔记库", "books.vertical"), ("设置", "gearshape"),
    ]

    var body: some View {
        ZStack(alignment: .leading) {
            if open {
                Web.overlay.ignoresSafeArea()
                    .onTapGesture { close() }
                    .accessibilityLabel(Text("关闭菜单"))
                    .accessibilityAddTraits(.isButton)
                    .transition(.opacity)
                VStack(alignment: .leading, spacing: Web.space1) {
                    ForEach(Self.pages, id: \.label) { page in link(page) }
                    Spacer()
                }
                .padding(.horizontal, Web.space2)
                .padding(.vertical, Web.space3)
                .frame(width: min(Web.navWidth, UIScreenWidth.value * 0.85))
                .frame(maxHeight: .infinity, alignment: .top)
                .background(Web.bgSubtle.ignoresSafeArea())
                .transition(.move(edge: .leading))
            }
        }
        .animation(Web.panel, value: open)
    }

    private func link(_ page: (label: String, icon: String)) -> some View {
        let current = page.label == "生活画布"
        return Button {
            close()
            if page.label == "设置" {
                settings = true
            } else if !current {
                later = page.label
            }
        } label: {
            HStack(spacing: Web.space2) {
                Image(systemName: page.icon).foregroundStyle(current ? Web.fgSecondary : Web.fgTertiary)
                    .frame(width: Web.icon)
                Text(page.label).foregroundStyle(current ? Web.fg : Web.fgSecondary)
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

/// 轻提示（网页版 toast）：深底浅字，右边一个操作
private struct Toast: View {
    let message: String
    let action: String
    let perform: () -> Void

    var body: some View {
        HStack(spacing: Web.space3) {
            Text(message).font(Web.body).foregroundStyle(Web.onAccent)
            Button(action, action: perform).font(Web.bodyMedium).foregroundStyle(Web.onAccent).buttonStyle(.plain)
                .accessibilityIdentifier("undoToast")
        }
        .padding(.horizontal, Web.space4)
        .padding(.vertical, Web.space2)
        .frame(minHeight: Web.control)
        .background(RoundedRectangle(cornerRadius: Web.radiusPanel).fill(Web.fg))
    }
}
