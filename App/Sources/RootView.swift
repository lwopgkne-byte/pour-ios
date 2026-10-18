import PourDesign
import SwiftUI

/// App 的外壳：系统标签栏（4 个 + 搜索）、常驻在标签栏上方的倾倒栏（规范 12 第 2 节）。
/// 点倾倒栏：浮起能打字的栏和键盘；发出去就回到「今天」看它凝结
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.tab) {
            Tab("今天", systemImage: "sun.max", value: AppModel.Tab.today) {
                NavigationStack { TodayView() }
            }
            Tab("回顾", systemImage: "book.pages", value: AppModel.Tab.review) {
                NavigationStack {
                    LaterPage(
                        title: "回顾", systemImage: "book.pages", headline: "说上几天，这里会有你的回顾",
                        example: "昨天睡得比平时晚 40 分钟")
                }
            }
            Tab("关于我", systemImage: "person.crop.circle", value: AppModel.Tab.about) {
                NavigationStack {
                    LaterPage(
                        title: "关于我", systemImage: "person.crop.circle", headline: "说得越多，这里越懂你",
                        example: "和小王在一起的日子，心情都不错")
                }
            }
            Tab("钱", systemImage: "yensign.circle", value: AppModel.Tab.money) {
                NavigationStack {
                    LaterPage(
                        title: "钱", systemImage: "yensign.circle", headline: "说一句花了多少，这里就有账",
                        example: "中午吃了碗牛肉面 28")
                }
            }
            Tab(value: AppModel.Tab.search, role: .search) {
                NavigationStack {
                    LaterPage(
                        title: "搜索", systemImage: "magnifyingglass", headline: "搜你说过的话",
                        example: "上次去爬山是什么时候")
                }
            }
        }
        .tint(PourColor.action.color)
        .tabViewBottomAccessory { PourBarButton { model.composing = true } }
        .tabBarMinimizeBehavior(.onScrollDown)
        .overlay {
            if model.composing { ComposeLayer() }
        }
        .animation(PourMotion.smooth, value: model.composing)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.becameActive() }
        }
    }
}

/// 标签栏上方的倾倒栏（空闲）：整条是一个按钮，点一下开始打字。
/// 附件的高度由系统定、不随字号长高：字号封顶，更大的字号长按看大字（和系统标签栏一样，M1 自验收）
private struct PourBarButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                PourBarPlaceholder()
                Spacer(minLength: PourSpace.related)
                Image(systemName: "square.and.pencil").foregroundStyle(PourColor.inkSecondary.color)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, PourSpace.card)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityLabel(Text("说点什么"))
        .accessibilityHint(Text("打字记下一件事"))
        .accessibilityShowsLargeContentViewer { Label("说点什么", systemImage: "square.and.pencil") }
        .accessibilityIdentifier("pourbar")
    }
}

/// 打字的那一层：浮在最上面，栏贴着键盘；点空白处收起（打了一半的字留着，下次接着打）
private struct ComposeLayer: View {
    @Environment(AppModel.self) private var model
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var model = model
        ZStack(alignment: .bottom) {
            PourColor.scrim.color
                .ignoresSafeArea()
                .onTapGesture { model.composing = false }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(Text("收起"))
            PourInputBar(text: $model.draft, isFocused: $focused) { model.send() }
                .padding(.bottom, PourSpace.related)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .transition(.opacity)
        .onAppear { focused = true }
    }
}

/// 还没做的标签页：说清楚以后这里会有什么，给一个能照着说的例子（规范 12「空状态」）
private struct LaterPage: View {
    let title: String
    let systemImage: String
    let headline: String
    let example: String

    var body: some View {
        ScrollView {
            PourEmptyState(systemImage: systemImage, title: headline, example: example)
                .padding(.horizontal, PourSpace.card)
        }
        .background(PourColor.canvas.color)
        .navigationTitle(title)
    }
}
