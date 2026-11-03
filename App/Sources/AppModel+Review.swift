import Foundation
import Observation
import PourAPI

// MARK: - 回顾（3.0 第 6 步，docs/3.0/01-需求文档.md 第 8 章、06 交互细节第 6 节）

/// 回顾这一块的状态（AppModel.review）：开着的故事
@Observable
@MainActor
final class ReviewState {
    /// 全屏的故事（回顾页点一张卡、画布上「昨天的回顾好了」、对话里的回顾和报告）
    var story: ReviewStoryRef?
}

/// 打开哪一篇的故事：每日回顾（那一天）、周报月报（那一期的第一天）
struct ReviewStoryRef: Identifiable, Hashable {
    /// daily、weekly、monthly
    let kind: String
    let day: String

    var id: String { "\(kind)-\(day)" }

    /// 「看整页」：这一篇长页面的地址
    var path: String { kind == "daily" ? "/review/\(day)" : Show.reportPath(kind, from: day) }

    /// 「/review/2026-10-18」「/review/week/2026-10-12」「/review/month/2026-09」；别的是 nil
    init?(path: String) {
        switch ReviewRoute(path) {
        case .daily(let day)?: self.init(kind: "daily", day: day)
        case .period(let kind, let day)?: self.init(kind: kind, day: day)
        case nil: return nil
        }
    }

    init(kind: String, day: String) {
        self.kind = kind
        self.day = day
    }
}

extension AppModel {
    /// 打开一篇回顾的故事（地址认不出就照常打开那一页）
    func openStory(path: String) {
        guard let ref = ReviewStoryRef(path: path) else {
            open(path)
            return
        }
        chatOpen = false
        review.story = ref
    }

    /// 故事最后的「看整页」：收起故事，推进那一篇的长页面
    func openFullReview(_ ref: ReviewStoryRef) {
        review.story = nil
        open(ref.path)
    }
}

// MARK: - 还没收尾的、自动检查查出的（故事第 6 页和整页里共用）

extension AppModel {
    /// 没做完的待办「带到今天」
    func carryToToday(_ entryId: Int, content: String, after: @escaping @MainActor () async -> Void) {
        reviewAct(after: after, done: "「\(content)」带到今天了", work: { try await $0.carry(entry: entryId) })
    }

    /// 拿不准的点「对」
    func confirmOpen(_ entryId: Int, after: @escaping @MainActor () async -> Void) {
        reviewAct(after: after, done: "确认了", work: { try await $0.confirm(entry: entryId) })
    }

    /// 自动检查查出的：「确实错了」——按审核员的改法改好、记进「你改过的地方」；说不清怎么改的打开那条记录自己改。能撤销
    func confirmFinding(_ finding: API.AuditFinding, after: @escaping @MainActor () async -> Void) {
        let client = self.client
        Task { [self] in
            do {
                let result = try await client.confirmFinding(finding.id)
                dataChanged()
                await after()
                switch result.kind {
                case "fixed":
                    toast("改好了，也记进了「你改过的地方」", action: "撤销") { [weak self] in
                        self?.undoFinding(finding.id, after: after)
                    }
                case "candidate":
                    toast("记进了「你改过的地方」", action: "撤销") { [weak self] in self?.undoFinding(finding.id, after: after) }
                default:
                    toast(result.why == "changed" ? "这条记录后来改过了，你看看现在对不对" : "记下了，这一处要你自己改一下")
                    if let entry = result.entryIds?.first { openEntry(entry, day: finding.day) }
                }
            } catch {
                toast(error.readable)
            }
        }
    }

    /// 自动检查查出的：「没错」——算审核员看错了；能撤销
    func dismissFinding(_ finding: API.AuditFinding, after: @escaping @MainActor () async -> Void) {
        let undo: () -> Void = { [weak self] in self?.undoFinding(finding.id, after: after) }
        reviewAct(after: after, done: "好，这一处不算错", undo: undo, work: { try await $0.dismissFinding(finding.id) })
    }

    private func undoFinding(_ id: Int, after: @escaping @MainActor () async -> Void) {
        reviewAct(after: after, done: "撤销了", work: { try await $0.undoFinding(id) })
    }

    private func reviewAct(
        after: @escaping @MainActor () async -> Void, done: String, undo: (() -> Void)? = nil,
        work: @escaping @Sendable (APIClient) async throws -> Void
    ) {
        let client = self.client
        Task {
            do {
                try await work(client)
                dataChanged()
                await after()
                if let undo { toast(done, action: "撤销", perform: undo) } else { toast(done) }
            } catch {
                toast(error.readable)
            }
        }
    }
}
