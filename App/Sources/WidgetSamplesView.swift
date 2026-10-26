#if DEBUG
    import PourDesign
    import SwiftUI
    import WidgetKit

    /// 小组件样张（开发版，启动参数 -widgetSamples）：桌面和锁屏上各个小组件的样子，界面测试截图验收用
    /// （docs/模块/产品优化.md R7）。尺寸照 iPhone 15：小 170×170、中 364×170、锁屏长条 160×72、圆 76×76
    struct WidgetSamplesView: View {
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.regular) {
                    Text("小组件样张").font(Theme.Typeface.largeTitle).foregroundStyle(Theme.Palette.label)
                    HStack(spacing: Theme.Space.medium) {
                        tile(SayWidgetView(), width: 170, height: 170)
                        tile(QuoteWidgetView(glance: WidgetSamples.glance, problem: nil), width: 170, height: 170)
                    }
                    tile(TodayWidgetView(glance: WidgetSamples.glance, problem: nil), width: 364, height: 170)
                    tile(TodayWidgetView(glance: nil, problem: "连不上电脑上的 Pour"), width: 364, height: 170)
                    Text("锁屏").font(Theme.Typeface.section).foregroundStyle(Theme.Palette.label)
                    HStack(spacing: Theme.Space.medium) {
                        lock(SayCircleView(), width: 76, height: 76)
                        lock(NextTodoView(glance: WidgetSamples.glance, problem: nil), width: 160, height: 72)
                    }
                }
                .padding(Theme.Space.screen)
            }
            .background(Theme.Palette.background)
        }

        private func tile(_ content: some View, width: CGFloat, height: CGFloat) -> some View {
            content.padding(Theme.Space.regular)
                .frame(width: width, height: height)
                .background(Theme.Palette.card, in: Theme.rounded(22))
                .accessibilityElement(children: .contain)
        }

        /// 锁屏的组件是单色的，压在照片上：用深底白字看个大概
        private func lock(_ content: some View, width: CGFloat, height: CGFloat) -> some View {
            content.foregroundStyle(Theme.Palette.onAccent).padding(Theme.Space.small)
                .frame(width: width, height: height)
                .background(Theme.Palette.label.opacity(0.85), in: Theme.rounded(16))
                .environment(\.colorScheme, .dark)
        }
    }
#endif
