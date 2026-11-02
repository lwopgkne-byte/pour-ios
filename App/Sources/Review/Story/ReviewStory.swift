import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 回顾的故事（06 交互细节第 6 节、10.4）：全屏，一页一个底色、最后一页暖白；顶上一排进度条，5.5 秒自动翻；
/// 点右边（右边三分之二）下一页、点左边上一页；按住暂停；往下拉、右上角 × 关掉。最后一页「看整页」「看完了」。
/// 每日回顾七页、周报七页、月报六页（空的那一页不出现）。读屏开着时不自动翻（上下轻扫换页，或者用「下一页」）
struct ReviewStory: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    let ref: ReviewStoryRef
    @State private var daily: API.DailyReviewPage?
    @State private var period: API.PeriodReviewPage?
    @State private var findings: [API.AuditFinding] = []
    @State private var problem: String?
    @State private var page = 0
    @State private var progress = 0.0
    @State private var paused = false
    @State private var pull: CGFloat = 0
    @State private var width: CGFloat = 1

    private var pages: [StoryPage] {
        if let daily { return StoryPage.daily(daily, findings: findings, today: model.today) }
        if let period { return StoryPage.period(period.review) }
        return []
    }

    var body: some View {
        let pages = self.pages
        let count = max(pages.count, 1)
        let current = min(page, count - 1)
        let last = !pages.isEmpty && current == count - 1
        let ink = Theme.Story.ink(last: last)
        VStack(spacing: Theme.Space.small) {
            StoryProgress(count: count, current: current, progress: last ? 1 : progress, ink: ink)
                .padding(.horizontal, Theme.Space.medium).padding(.top, Theme.Space.small)
                // 读屏：在进度条上上下轻扫换页，或者用「下一页」「上一页」（只挂在这一个元素上，别的字不算能点的）
                .accessibilityAdjustableAction { direction in
                    go(direction == .increment ? current + 1 : current - 1, count: count)
                }
                .accessibilityAction(named: Text("下一页")) { go(current + 1, count: count) }
                .accessibilityAction(named: Text("上一页")) { go(current - 1, count: count) }
            header(ink)
            Group {
                if let page = pages[safe: current] {
                    StoryPageView(page: page, ref: ref, reload: load)
                } else if let problem {
                    Text(problem).font(Theme.Typeface.body).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView().tint(ink).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, Theme.Space.large)
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { point in
                go(point.x < width / 3 ? current - 1 : current + 1, count: count)
            }
            .onLongPressGesture(minimumDuration: 0.3, maximumDistance: Theme.Space.large) {
            } onPressingChanged: { pressing in
                paused = pressing
            }
            .id(current)
            .transition(.opacity)
            Text("点右边下一页 · 点左边上一页").font(Theme.Typeface.footnote).foregroundStyle(ink.opacity(0.7))
                .padding(.bottom, Theme.Space.small)
                .accessibilityHidden(true)
        }
        .background(Theme.Story.background(page: current, last: last).ignoresSafeArea())
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: {
            width = $0
        }
        .offset(y: pull)
        .simultaneousGesture(pullDown)
        .animation(Theme.Motion.standard, value: current)
        .task(id: ref) { await load() }
        .task(id: "\(current)-\(paused)-\(count)-\(voiceOver)") { await tick(current: current, count: count) }
        .statusBarHidden()
    }

    /// 「Pour · 昨天」和关掉
    private func header(_ ink: Color) -> some View {
        HStack {
            Text("Pour · \(scope)").font(Theme.Typeface.footnoteSemibold).foregroundStyle(ink)
            Spacer()
            Button {
                model.review.story = nil
            } label: {
                Image(systemName: "xmark").font(Theme.Typeface.footnoteSemibold).foregroundStyle(ink)
                    .frame(width: Theme.Size.capsule, height: Theme.Size.capsule)
                    .background(ink.opacity(0.12), in: Circle())
                    .frame(width: Theme.Size.touch, height: Theme.Size.touch).contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("关闭"))
            .accessibilityIdentifier("story.close")
        }
        .padding(.horizontal, Theme.Space.medium)
    }

    /// 顶上那一行写的：昨天 / 10月26日、上周、9 月
    private var scope: String {
        switch ref.kind {
        case "daily": Show.relative(ref.day, today: model.today) ?? Show.monthDay(ref.day)
        case "weekly": Show.periodRelative("weekly", from: ref.day, today: model.today) ?? "周报"
        default:
            Show.periodRelative("monthly", from: ref.day, today: model.today)
                ?? Show.monthName(String(ref.day.prefix(7)))
        }
    }

    /// 往下拉：跟着手走，拉过 120 点松手就关掉
    private var pullDown: some Gesture {
        DragGesture(minimumDistance: Theme.Space.section)
            .onChanged { value in
                guard value.translation.height > abs(value.translation.width) else { return }
                pull = max(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 120 {
                    model.review.story = nil
                } else {
                    withAnimation(Theme.Motion.spring) { pull = 0 }
                }
            }
    }

    private func go(_ target: Int, count: Int) {
        guard (0..<count).contains(target) else { return }
        progress = 0
        page = target
    }

    /// 界面测试里不自动翻（审计要审的就是那一页）；要验自动翻时带上 -storyAutoplay
    private static let still =
        CommandLine.arguments.contains("-uiTest") && !CommandLine.arguments.contains("-storyAutoplay")

    /// 自动翻：一页 5.5 秒；按住、读屏开着、最后一页不翻
    private func tick(current: Int, count: Int) async {
        guard !Self.still, !paused, !voiceOver, current < count - 1, daily != nil || period != nil else { return }
        let step = 0.05
        while progress < 1 {
            try? await Task.sleep(for: .milliseconds(50))
            if Task.isCancelled { return }
            progress = min(1, progress + step / Theme.Story.pageSeconds)
        }
        go(current + 1, count: count)
    }

    private func load() async {
        do throws(APIError) {
            if ref.kind == "daily" {
                let path = "/api/review/daily/\(ref.day)"
                if daily == nil, let saved: API.DailyReviewPage = model.client.cached(path) { daily = saved }
                let fresh = try await model.client.dailyReview(ref.day)
                daily = fresh
                if let id = fresh.messageId, !fresh.read { try? await model.client.markRead(message: id) }
                if ref.day < model.today { findings = (try? await model.client.auditFindings(ref.day)) ?? [] }
            } else {
                let fresh = try await model.client.periodReview(ref.kind, ref.day)
                period = fresh
                if let id = fresh.messageId, !fresh.read { try? await model.client.markRead(message: id) }
            }
            problem = nil
        } catch {
            if daily == nil && period == nil { problem = error.message }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
