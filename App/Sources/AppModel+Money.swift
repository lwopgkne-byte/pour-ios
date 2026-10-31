import Foundation
import PourAPI
import PourCore

/// 刚用数字键盘记下的一笔（服务器还没整理完）：钱的主页上先显示一行「整理中」，大数、月历那一格先加上
struct PendingMoney: Identifiable, Hashable {
    let clientId: String
    /// 服务器收下以后的原话编号（撤销、看整理完没有用）
    var noteId: Int?
    /// 「午饭」「借给小王」
    let name: String
    let amount: Double
    /// daily · reimburse · lend · income（只有日常的算进大数）
    let kind: String
    let day: String
    /// 「12:40」
    let time: String

    var id: String { clientId }
}

// MARK: - 钱（3.0 第 3 步，docs/3.0/01-需求文档.md 第 5 章）

extension AppModel {
    /// 记一笔（钱主页的圆按钮、「我的」的快捷、画布钱卡的「＋ 记一笔」、按住图标）：打开数字键盘
    func recordMoney() {
        keypadOpen = true
    }

    /// 数字键盘记下：生成一段原话（「午饭 25」「打车 58 能报销」），走整理（原话是唯一的源头）；
    /// 钱的主页上马上多一行「整理中」、大数和月历那一格先加上；轻提示能撤销
    func record(money text: String, pending: PendingMoney) {
        moneyPending.insert(pending, at: 0)
        outbox.append(Outbox(clientId: pending.clientId, text: text, createdAt: Date(), day: nil, context: "money"))
        OutboxStore.save(outbox)
        Task { await flushOutbox() }
        toast("记下了：\(pending.name) \(Show.yuan(pending.amount))", action: "撤销") { [weak self] in
            self?.undoMoney(pending.clientId)
        }
    }

    /// 撤销刚记的一笔：还没发出去的从手机上拿掉；发出去了的让服务器撤掉这段话整理出的记录（原话留着）
    private func undoMoney(_ clientId: String) {
        let noteId = moneyPending.first { $0.clientId == clientId }?.noteId
        moneyPending.removeAll { $0.clientId == clientId }
        if let index = outbox.firstIndex(where: { $0.clientId == clientId }) {
            outbox.remove(at: index)
            OutboxStore.save(outbox)
            return
        }
        if let noteId { undo(note: noteId) }
    }

    /// 服务器收下了一段话：记下是哪一段（发件箱 flushOutbox 调）
    func posted(_ clientId: String, note: API.Note) {
        guard let index = moneyPending.firstIndex(where: { $0.clientId == clientId }) else { return }
        moneyPending[index].noteId = note.id
    }

    /// 整理完的（或者没整理成的）不再先显示：正式的那一行已经在服务器的单子里（拿对话时调）
    func prunePendingMoney() {
        guard !moneyPending.isEmpty else { return }
        moneyPending.removeAll { pending in
            guard let id = pending.noteId, let note = chat.first(where: { $0.id == id }) else { return false }
            return note.status == "done" || note.status == "failed"
        }
    }

    /// 这个月先算进大数的（刚记下、还在整理的日常的）
    func pendingSpent(month: String) -> Double {
        moneyPending.filter { $0.kind == "daily" && $0.day.hasPrefix(month) }.map(\.amount).reduce(0, +)
    }
}
