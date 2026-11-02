import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 今天重温（06 交互细节 5.1）：服务器挑的一句（一个月前、一年前的今天 → 收藏的 → 很久没见过的，30 天内不重复），
/// 大卡片点了翻过来看原话；下面「收藏」（收藏了变黄「已收藏」）「分享」「换一句」（卡片往左滑走、下一句从右边进来；
/// 按住卡片往左滑也是换一句）。一句都没有时整块不出现
struct InsightsRevisit: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var today: API.InsightDetail?
    @State private var flipped = false
    /// 换一句时卡片往左滑走、从右边进来；手指拖着时跟着走
    @State private var slide: CGFloat = 0
    @State private var switching = false

    /// 滑出去多远（比屏幕宽一点）
    private let away: CGFloat = 480

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            if let today, let picked = today.insight, !model.insight.removed.contains(picked.id) {
                let item = model.insight.shown(picked)
                InsightRevisitCard(
                    ago: today.ago ?? "以前你说", quote: item.quote, meta: meta(item), said: today.said,
                    related: today.related.count, flipped: $flipped
                ) {
                    model.insight.sheet = .detail(item)
                }
                .offset(x: slide)
                .opacity(reduceMotion && switching ? 0 : 1)
                .simultaneousGesture(swipe)
                .accessibilityAction(named: Text("换一句")) { Task { await next() } }
                actions(item)
            }
        }
        .task(id: model.dataVersion) { await load() }
    }

    private func meta(_ item: API.InsightItem) -> String {
        ([Show.monthDay(item.day)] + item.tags).joined(separator: " · ")
    }

    /// 收藏 · 分享 · 换一句
    private func actions(_ item: API.InsightItem) -> some View {
        HStack(spacing: Theme.Space.small) {
            RevisitAction(
                item.isStarred ? "已收藏" : "收藏", symbol: item.isStarred ? "star.fill" : "star", active: item.isStarred
            ) {
                model.star(item, !item.isStarred)
            }
            .accessibilityIdentifier("insights.revisit.star")
            RevisitAction("分享", symbol: "square.and.arrow.up") { model.insight.sheet = .share(item) }
                .accessibilityIdentifier("insights.revisit.share")
            RevisitAction("换一句", symbol: "arrow.clockwise") { Task { await next() } }
                .accessibilityIdentifier("insights.revisit.next")
                .disabled(switching)
        }
    }

    /// 按住卡片往左拖：卡片跟着走；拖过 80 点松手就换一句，不够就弹回来（上下滑照常翻页面）
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                guard !switching, abs(value.translation.width) > abs(value.translation.height) else { return }
                slide = min(0, value.translation.width)
            }
            .onEnded { value in
                guard !switching else { return }
                if value.translation.width < -80, abs(value.translation.width) > abs(value.translation.height) {
                    Task { await next() }
                } else {
                    withAnimation(Theme.Motion.spring) { slide = 0 }
                }
            }
    }

    /// 换一句：这张往左滑走，同时去拿下一句；新的从右边进来（翻回正面）。减弱动态效果时只渐变
    private func next() async {
        guard !switching else { return }
        switching = true
        defer { switching = false }
        let client = model.client
        async let fetched = try? client.insightToday(next: true)
        withAnimation(Theme.Motion.pick(Theme.Motion.swapOut, reduceMotion: reduceMotion)) {
            if !reduceMotion { slide = -away }
        }
        try? await Task.sleep(for: .milliseconds(260))
        let fresh = await fetched
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            flipped = false
            if let fresh, fresh.insight != nil { today = fresh }
            slide = reduceMotion ? 0 : away
        }
        withAnimation(Theme.Motion.pick(Theme.Motion.spring, reduceMotion: reduceMotion)) { slide = 0 }
        if fresh == nil { model.toast("没连上电脑上的 Pour，等连上了再换") }
    }

    private func load() async {
        if today == nil, let saved: API.InsightDetail = model.client.cached("/api/insights/today") { today = saved }
        if let fresh = try? await model.client.insightToday() { today = fresh }
    }
}

/// 今天重温下面的一个按钮：浅灰胶囊 + 图标；「已收藏」浅黄底深金棕字
private struct RevisitAction: View {
    let title: String
    let symbol: String
    let active: Bool
    let action: () -> Void

    init(_ title: String, symbol: String, active: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.active = active
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.tight) {
                Image(systemName: symbol).contentTransition(.symbolEffect(.replace))
                Text(title)
            }
            .font(Theme.Typeface.footnoteSemibold)
            .foregroundStyle(active ? Theme.Idea.ink : Theme.Palette.label)
            .padding(.horizontal, Theme.Space.medium)
            .frame(minHeight: Theme.Size.capsule + Theme.Space.tight)
            .background(active ? Theme.Idea.soft : Theme.Palette.card, in: Capsule())
            .overlay { Capsule().stroke(active ? Color.clear : Theme.Palette.separator) }
            .frame(minHeight: Theme.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .themeSelectionFeedback(trigger: active)
    }
}
