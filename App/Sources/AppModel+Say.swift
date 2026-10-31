import Foundation
import PourAPI

// MARK: - 说一句、提醒

extension AppModel {
    /// 发出去：原话先存在手机上，马上出现在对话里；交给服务器排队整理
    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        // 在手机上直接做的命令（/找 /今天 /周报 /撤销）：不发给 AI
        if let slash = Show.parseSlash(text), slash.command.intent == nil {
            Task { await run(slash.command, slash.rest) }
            return
        }
        // 画布样张只用来看：说的话交给真的服务器——回到服务器的数据，新的 AppModel 起来就发出去、打开对话
        if CanvasSamples.isOn {
            OutboxStore.queueForServer(text)
            Self.openChatOnLaunch = true
            showSamples(false)
            return
        }
        // 在画布上看以前的某一天时说的：补记到那一天，留在那一天（docs/模块/产品优化.md R1.1）；看以后的日子照旧回到今天。
        // 在别的页说的不补记，带上是哪一页（意图识别作参考）
        let backfill = stack.isEmpty && shownDay < today ? shownDay : nil
        outbox.append(
            Outbox(
                clientId: UUID().uuidString, text: text, createdAt: Date(), day: backfill, context: sayContext))
        OutboxStore.save(outbox)
        chatOpen = true
        if stack.isEmpty, backfill == nil, shownDay != today { show(today) }
        Task { await flushOutbox() }
    }

    /// 把手机上存着的话交给服务器（同一段话带着同一个编号，重发不会记两遍）
    func flushOutbox() async {
        for item in outbox {
            do {
                try await client.send(item.text, clientId: item.clientId, day: item.day, context: item.context)
                outbox.removeAll { $0.clientId == item.clientId }
                offline = nil
            } catch {
                if let index = outbox.firstIndex(where: { $0.clientId == item.clientId }) {
                    outbox[index].failed = error.message
                }
            }
            OutboxStore.save(outbox)
        }
        await reloadChat()
        await reloadDay()
    }
}
