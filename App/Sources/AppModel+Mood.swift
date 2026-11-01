import Foundation
import Observation
import PourAPI
import PourCore

// MARK: - 心情（3.0 第 4 步，docs/3.0/01-需求文档.md 第 6 章）

/// 心情这一块的状态：记心情的弹层、打开的那一条心情、刚记下还在整理的几刻（AppModel.mood）
@Observable
@MainActor
final class MoodState {
    /// 记心情的弹层开着没有、点的是哪一档（心情页的五个表情、「我的」的快捷、画布心情卡、按住图标、小组件）
    var checkin: MoodCheckin?
    /// 打开的那一条心情（今天的一刻、月历上那天的一刻、好时刻）
    var detail: API.MoodMoment?
    /// 刚记下、服务器还没整理完的几刻：心情页「今天」里先显示（「整理中」），整理完换成正式的
    var pending: [PendingMood] = []
}

/// 打开记心情：点的是哪一档（没点就是 nil，弹层里再选）
struct MoodCheckin: Identifiable, Hashable {
    let id = UUID()
    var level: Int?
}

/// 刚记下的一刻（服务器还没整理完）
struct PendingMood: Identifiable, Hashable {
    let clientId: String
    /// 服务器收下以后的原话编号（撤销、看整理完没有用）
    var noteId: Int?
    let level: Int
    let emotions: [String]
    /// 「因为」后面那段；没写是 nil
    let because: String?
    let day: String
    /// 「21:30」
    let time: String

    var id: String { clientId }
}

extension AppModel {
    /// 记心情：打开弹层（level 是点的那一档）
    func checkinMood(_ level: Int? = nil) {
        mood.checkin = MoodCheckin(level: level)
    }

    /// 记心情的弹层记下：生成一段原话（「心情挺好，放松，因为……」），走整理（原话是唯一的源头）；
    /// 心情页「今天」里马上多一刻（整理中）；轻提示能撤销
    func record(mood text: String, pending: PendingMood) {
        mood.pending.append(pending)
        outbox.append(Outbox(clientId: pending.clientId, text: text, createdAt: Date(), day: nil, context: "mood"))
        OutboxStore.save(outbox)
        Task { await flushOutbox() }
        let words = ([MoodText.names[pending.level - 1]] + pending.emotions).joined(separator: " · ")
        toast("记下了：\(words)", action: "撤销") { [weak self] in self?.undoMood(pending.clientId) }
    }

    /// 撤销刚记的一刻：还没发出去的从手机上拿掉；发出去了的让服务器撤掉这段话整理出的记录（原话留着）
    private func undoMood(_ clientId: String) {
        let noteId = mood.pending.first { $0.clientId == clientId }?.noteId
        mood.pending.removeAll { $0.clientId == clientId }
        if let index = outbox.firstIndex(where: { $0.clientId == clientId }) {
            outbox.remove(at: index)
            OutboxStore.save(outbox)
            return
        }
        if let noteId { undo(note: noteId) }
    }

    /// 服务器收下了一段话：记下是哪一段（发件箱 flushOutbox 经 posted 调）
    func postedMood(_ clientId: String, note: API.Note) {
        guard let index = mood.pending.firstIndex(where: { $0.clientId == clientId }) else { return }
        mood.pending[index].noteId = note.id
    }

    /// 刚记下的一笔钱、一刻心情：整理完的不再先显示（拿对话时调）
    func prunePending() {
        prunePendingMoney()
        prunePendingMood()
    }

    /// 整理完的（或者没整理成的）不再先显示：正式的那一刻已经在服务器的单子里
    private func prunePendingMood() {
        guard !mood.pending.isEmpty else { return }
        mood.pending.removeAll { pending in
            guard let id = pending.noteId, let note = chat.first(where: { $0.id == id }) else { return false }
            return note.status == "done" || note.status == "failed"
        }
    }
}

/// 记心情的原话怎么写（docs/3.0/06-交互细节.md 4.2）：「心情挺好」「心情不太好，烦躁，因为方案又改了」——
/// 情绪词只写你点的和你说的；只点一档就只写「心情挺好」（整理时不编那一刻、不编情绪词）
enum MoodText {
    static let names = ["很差", "不太好", "一般", "挺好", "很好"]

    static func said(level: Int, emotions: [String], because: String) -> String {
        let reason = because.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = ["心情\(names[min(5, max(1, level)) - 1])"] + emotions + (reason.isEmpty ? [] : ["因为\(reason)"])
        return parts.joined(separator: "，")
    }
}
