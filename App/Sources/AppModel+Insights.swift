import Foundation
import Observation
import PourAPI
import PourCore

// MARK: - 感悟（3.0 第 5 步，docs/3.0/01-需求文档.md 第 7 章）

/// 感悟这一块的状态（AppModel.insight）：开着的弹层；点过的星、改过的字、删掉的（先改界面再发，服务器的单子拿回来以前先按这个画）；
/// 刚用「记一句」记下、还在整理的那几句
@Observable
@MainActor
final class InsightState {
    /// 记一句、一条感悟、分享成图片（感悟页、「我的」的快捷、今天重温都打开它）
    var sheet: InsightSheet?
    /// 点过的星：编号 → 收藏了没有
    var stars: [Int: Bool] = [:]
    /// 一条感悟里改过的那一句和标签
    var edits: [Int: API.InsightItem] = [:]
    /// 删掉的（撤销就放回来）
    var removed: Set<Int> = []
    /// 刚记下、还在整理的：感悟页最上面先放着（「整理中」）
    var pending: [PendingSaying] = []
    /// 刚记下的那句整理好了：那张卡亮一下（原话编号）
    var fresh: Int?

    /// 一句感悟现在的样子：改过的、点过星的先用上
    func shown(_ item: API.InsightItem) -> API.InsightItem {
        var out = edits[item.id] ?? item
        if let star = stars[item.id] { out.starred = star }
        return out
    }

    /// 服务器的单子拿回来了：和它一样了的不用再记着
    func settle(_ page: API.InsightsPage) {
        for item in page.insights {
            if stars[item.id] == item.isStarred { stars[item.id] = nil }
            if let edit = edits[item.id], edit.quote == item.quote, edit.tags == item.tags { edits[item.id] = nil }
        }
        removed = removed.filter { id in page.insights.contains { $0.id == id } }
    }
}

/// 感悟的弹层：记一句、一条感悟、分享成图片（换一个时系统先收起再弹出）
enum InsightSheet: Identifiable, Hashable {
    case add
    case detail(API.InsightItem)
    case share(API.InsightItem)

    var id: String {
        switch self {
        case .add: "add"
        case .detail(let item): "detail-\(item.id)"
        case .share(let item): "share-\(item.id)"
        }
    }
}

/// 刚记下的一句（服务器还没整理完）
struct PendingSaying: Identifiable, Hashable {
    let clientId: String
    /// 服务器收下以后的原话编号（撤销、看整理完没有用）
    var noteId: Int?
    let text: String
    let day: String

    var id: String { clientId }
}

extension AppModel {
    /// 收藏成语录 / 取消（★、长按、一条感悟里的开关、今天重温的「收藏」）：先改界面再发，服务器不收就退回去
    func star(_ item: API.InsightItem, _ starred: Bool) {
        insight.stars[item.id] = starred
        write("POST", "/api/insights/\(item.id)/star", json: .object(["starred": .bool(starred)])) { [weak self] in
            self?.insight.stars[item.id] = !starred
        }
    }

    /// 一条感悟的「好了」：改那一句、标签；轻提示能撤销
    func edit(_ before: API.InsightItem, quote: String, tags: [String]) {
        var after = insight.shown(before)
        after.quote = quote
        after.tags = tags
        let id = before.id
        apply(after, to: id) { [weak self] in self?.insight.edits[id] = nil }
        toast("改好了", action: "撤销") { [weak self] in
            self?.apply(before, to: id) {}
        }
    }

    private func apply(_ item: API.InsightItem, to id: Int, revert: @escaping @MainActor () -> Void) {
        insight.edits[id] = item
        let fields: JSONValue = .object(["quote": .string(item.quote), "tags": .array(item.tags.map(JSONValue.string))])
        write("PATCH", "/api/entries/\(id)", json: .object(["fields": fields]), revert: revert)
    }

    /// 删掉一句（长按、一条感悟里的「删除」）：轻提示能撤销
    func deleteInsight(_ item: API.InsightItem) {
        insight.sheet = nil
        insight.removed.insert(item.id)
        write("DELETE", "/api/entries/\(item.id)") { [weak self] in self?.insight.removed.remove(item.id) }
        toast("删了这句感悟", action: "撤销") { [weak self] in
            self?.insight.removed.remove(item.id)
            self?.write("POST", "/api/entries/\(item.id)/restore") {}
        }
    }

    /// 记一句（docs/3.0/01-需求文档.md 7.3）：原话「记一句：……」走整理，记成语录（R4）；
    /// 感悟页最上面马上多一张（整理中、亮一下）；轻提示能撤销
    func recordSaying(_ text: String) {
        let pending = PendingSaying(clientId: UUID().uuidString, text: text, day: today)
        insight.pending.insert(pending, at: 0)
        outbox.append(
            Outbox(clientId: pending.clientId, text: "记一句：\(text)", createdAt: Date(), day: nil, context: "insights"))
        OutboxStore.save(outbox)
        Task { await flushOutbox() }
        toast("记下了，收藏成你的语录", action: "撤销") { [weak self] in self?.undoSaying(pending.clientId) }
    }

    /// 撤销刚记的一句：还没发出去的从手机上拿掉；发出去了的让服务器撤掉这段话整理出的记录（原话留着）
    private func undoSaying(_ clientId: String) {
        let noteId = insight.pending.first { $0.clientId == clientId }?.noteId
        insight.pending.removeAll { $0.clientId == clientId }
        if let index = outbox.firstIndex(where: { $0.clientId == clientId }) {
            outbox.remove(at: index)
            OutboxStore.save(outbox)
            return
        }
        if let noteId { undo(note: noteId) }
    }

    /// 服务器收下了一段话：记下是哪一段（发件箱 flushOutbox 调）
    func postedSaying(_ clientId: String, note: API.Note) {
        guard let index = insight.pending.firstIndex(where: { $0.clientId == clientId }) else { return }
        insight.pending[index].noteId = note.id
    }

    /// 整理完的不再先放着：正式的那张卡在服务器的单子里，亮一下
    func prunePendingSayings() {
        guard !insight.pending.isEmpty else { return }
        let status = { (pending: PendingSaying) in self.chat.first { $0.id == pending.noteId }?.status }
        let finished = insight.pending.filter { status($0) == "done" || status($0) == "failed" }
        guard !finished.isEmpty else { return }
        insight.pending.removeAll { finished.contains($0) }
        if let done = finished.last(where: { status($0) == "done" }) { insight.fresh = done.noteId }
    }
}
