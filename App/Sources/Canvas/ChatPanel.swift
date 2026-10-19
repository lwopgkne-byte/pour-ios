import PourCore
import PourData
import PourDesign
import SwiftUI

/// 对话面板（网页版 ChatPanel 1 比 1）：按天分隔的历史，每段原话下面是整理的结果；拖上面的小横条往下收起
struct ChatPanel: View {
    @Environment(AppModel.self) private var model
    @Binding var drag: CGFloat

    var body: some View {
        let chat = model.chat
        VStack(spacing: 0) {
            Capsule().fill(Web.lineStrong).frame(width: Web.space8, height: Web.space1)
                .padding(.vertical, Web.space2)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { drag = $0.translation.height }
                        .onEnded { end in
                            withAnimation(Web.panel) {
                                if end.translation.height > Web.space12 + Web.space3 { model.chatOpen = false }
                                drag = 0
                            }
                        }
                )
                // 读屏用输入框旁边的「收起对话」按钮，这条拖动的小横条不再读一遍
                .accessibilityHidden(true)
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(spacing: Web.space3) {
                        if chat.notes.isEmpty {
                            Text("说过的话会出现在这里。").font(Web.body).foregroundStyle(Web.fgTertiary)
                                .padding(.top, Web.space12)
                        }
                        ForEach(rows(chat), id: \.id) { row in
                            switch row {
                            case .day(_, let label):
                                Text(label).font(Web.caption).foregroundStyle(Web.fgTertiary)
                                    .padding(.top, Web.space2)
                            case .note(let note):
                                NoteMessage(note: note, chat: chat).id(note.id)
                            }
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, Web.space4)
                    .padding(.bottom, Web.space4)
                }
                .scrollDismissesKeyboard(.interactively)
                .onAppear { reader.scrollTo("bottom", anchor: .bottom) }
                .onChange(of: bottomKey(chat)) { _, _ in
                    withAnimation(Web.panel) { reader.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
        .background(Web.bgSubtle)
        .overlay(alignment: .bottom) { Rectangle().fill(Web.line).frame(height: 1) }
    }

    private enum Row {
        case day(String, String)
        case note(Note)

        var id: String {
            switch self {
            case .day(let day, _): "day-\(day)"
            case .note(let note): note.id
            }
        }
    }

    /// 每天前面插一个分隔：「今天」「昨天」「9月22日 周二」
    private func rows(_ chat: ChatSnapshot) -> [Row] {
        var out: [Row] = []
        var lastDay: String?
        for note in chat.notes {
            if note.day != lastDay {
                lastDay = note.day
                out.append(.day(note.day, WebText.daySeparator(note.day, today: model.today)))
            }
            out.append(.note(note))
        }
        return out
    }

    /// 有新的话、最后一段整理完长出结果时滚到底
    private func bottomKey(_ chat: ChatSnapshot) -> String {
        guard let last = chat.notes.last else { return "" }
        return "\(last.id)-\(last.status)-\(last.actions.count)"
    }
}

/// 一段原话 + 它的整理结果：右边是你说的话（白底框），左边是安静的收据、回复、追问
private struct NoteMessage: View {
    @Environment(AppModel.self) private var model
    let note: Note
    let chat: ChatSnapshot

    var body: some View {
        let receipt = receiptLine
        let hasReply = receipt != nil || note.reply != nil || !note.questions.isEmpty
        VStack(spacing: Web.space3) {
            VStack(alignment: .trailing, spacing: Web.space1) {
                Text(note.text).font(Web.body).foregroundStyle(Web.fg)
                    .padding(.vertical, Web.space2).padding(.horizontal, Web.space3)
                    .background(RoundedRectangle(cornerRadius: Web.radiusCard).fill(Web.bg))
                    .overlay(RoundedRectangle(cornerRadius: Web.radiusCard).strokeBorder(Web.line, lineWidth: 1))
                HStack(spacing: Web.space2) {
                    Text(PourFormat.clock(note.localTime))
                    status(quiet: hasReply)
                }
                .font(Web.caption).foregroundStyle(Web.fgTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, Web.space12)
            if note.status == .failed, let problem = note.problem {
                Text(problem).font(Web.caption).foregroundStyle(Web.fgTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if note.status == .done && hasReply {
                VStack(alignment: .leading, spacing: Web.space1) {
                    if let receipt { receiptView(receipt) }
                    if let reply = note.reply { Text(reply).font(Web.body).foregroundStyle(Web.fg) }
                    ForEach(note.questions, id: \.self) { question in
                        Text(question).font(Web.bodyMedium).foregroundStyle(Web.fg)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, Web.space12)
            }
        }
    }

    /// 「已记录：🏃 跑步 5 公里 · 💼 开会」：数字全部来自记下的记录
    private var receiptLine: String? {
        let items = note.actions.compactMap { action -> WebReceipt.Item? in
            guard let entry = chat.mentioned[action.entryId] else { return nil }
            return WebReceipt.item(action.kind, entry: entry, categories: chat.categories)
        }
        return WebReceipt.line(items)
    }

    /// 收据后面紧跟「撤销」；撤销了就划掉，后面说一句「已撤销，原话还在」
    private func receiptView(_ receipt: String) -> some View {
        Text(receiptText(receipt)).font(Web.body)
            .environment(
                \.openURL,
                OpenURLAction { _ in
                    model.undo(note: note.id)
                    return .handled
                })
    }

    private func receiptText(_ receipt: String) -> AttributedString {
        if note.undoneAt != nil {
            var text = AttributedString(receipt)
            text.strikethroughStyle = .single
            text.foregroundColor = Web.fgSecondary
            var tail = AttributedString(" 已撤销，原话还在")
            tail.font = Web.caption
            tail.foregroundColor = Web.fgTertiary
            return text + tail
        }
        var text = AttributedString(receipt + " ")
        text.foregroundColor = Web.fgSecondary
        var undo = AttributedString("撤销")
        undo.foregroundColor = Web.accent
        undo.font = Web.bodyMedium
        undo.link = URL(string: "pour://undo")
        return text + undo
    }

    /// 原话下面的状态：整理中、等着、没整理成（能重试）；整理好了下面有收据就只留一个对勾
    @ViewBuilder private func status(quiet: Bool) -> some View {
        switch note.status {
        case .organizing:
            Text("正在整理…")
        case .queued, .waitingForNetwork:
            Label("已保存 · 待处理", systemImage: "circle").labelStyle(StatusLabelStyle())
        case .failed:
            HStack(spacing: Web.space1) {
                Label("处理失败", systemImage: "xmark").labelStyle(StatusLabelStyle()).foregroundStyle(Web.danger)
                Button("重试") { model.retry(note.id) }.font(Web.captionMedium).foregroundStyle(Web.accent)
                    .buttonStyle(.plain)
            }
        case .done:
            let label = WebReceipt.doneLabel(note)
            if quiet {
                Image(systemName: "checkmark").accessibilityLabel(Text(label))
            } else {
                Label(label, systemImage: "checkmark").labelStyle(StatusLabelStyle())
            }
        }
    }
}

private struct StatusLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Web.space1) {
            configuration.icon
            configuration.title
        }
    }
}
