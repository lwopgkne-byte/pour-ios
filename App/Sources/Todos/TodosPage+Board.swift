import PourAPI
import PourCore
import PourDesign
import SwiftUI

extension TodosPage {
    /// 四象限、时间线（不放在 List 里：List 自己接拖放，格子、时间线收不到放下来的卡片，2026-11-05 测出来的）
    func board(_ page: API.TodoPage) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.medium) {
                    heading(now: now)
                    if mode == .matrix {
                        TodoMatrixSection(page: page, now: now, mode: $mode, focus: $focus)
                    } else {
                        TodoTimelineView(
                            page: page, events: events(page.today), now: now, scroll: $scroll,
                            offset: scrollOffset
                        )
                        .id("timeline")
                    }
                }
                .padding(.horizontal, Theme.Space.regular)
                .padding(.bottom, Theme.Space.large)
            }
            .refreshable { await model.loadTodos() }
            // 时间线缩放时把手指下面那一刻留在原地：要知道滚到哪、能滚过去
            .scrollPosition($scroll)
            .onScrollGeometryChange(for: CGFloat.self) {
                $0.contentOffset.y
            } action: { _, new in
                scrollOffset.y = new
            }
            // 四象限「排进空档 ›」过来：滚到时间线（空档在上面标出来了）
            .task(id: mode) {
                guard mode == .timeline, model.todoGaps else { return }
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(Theme.Motion.standard) { proxy.scrollTo("timeline", anchor: .top) }
            }
        }
    }
}
