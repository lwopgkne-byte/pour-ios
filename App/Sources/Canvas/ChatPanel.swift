import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 对话面板（网页版 ChatPanel 1 比 1）：按天分隔的历史，每段原话下面是整理的结果；拖上面的小横条往下收起。
/// 还没交给服务器的话（没网时）排在最后，写「正在保存」或者「没有保存上 · 重试」
struct ChatPanel: View {
    @Environment(AppModel.self) private var model
    @Binding var drag: CGFloat

    var body: some View {
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
                        if model.chatHasMore {
                            Button("加载更早的记录") { Task { await model.loadEarlierChat() } }
                                .font(Web.caption).foregroundStyle(Web.fgTertiary).buttonStyle(.plain)
                                .frame(minHeight: Web.touch)
                        }
                        if model.chat.isEmpty && model.outbox.isEmpty {
                            Text("说过的话会出现在这里。").font(Web.body).foregroundStyle(Web.fgTertiary)
                                .padding(.top, Web.space12)
                        }
                        ForEach(rows, id: \.id) { row in
                            switch row {
                            case .day(_, let label):
                                Text(label).font(Web.caption).foregroundStyle(Web.fgTertiary).padding(.top, Web.space2)
                            case .note(let note):
                                NoteMessage(note: note)
                            case .outbox(let item):
                                OutboxMessage(item: item)
                            }
                        }
                        if let offline = model.offline, !model.outbox.isEmpty {
                            Text("\(offline)这段话先存在这台手机上，连上了会自动发。")
                                .font(Web.caption).foregroundStyle(Web.fgSecondary)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, Web.space4)
                    .padding(.bottom, Web.space4)
                }
                .scrollDismissesKeyboard(.interactively)
                .onAppear { reader.scrollTo("bottom", anchor: .bottom) }
                .onChange(of: bottomKey) { _, _ in
                    withAnimation(Web.panel) { reader.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
        .background(Web.bgSubtle)
        .overlay(alignment: .bottom) { Rectangle().fill(Web.line).frame(height: 1) }
    }

    private enum Row {
        case day(String, String)
        case note(API.Note)
        case outbox(AppModel.Outbox)

        var id: String {
            switch self {
            case .day(let day, _): "day-\(day)"
            case .note(let note): "note-\(note.id)"
            case .outbox(let item): "out-\(item.clientId)"
            }
        }
    }

    /// 原话按时间排，每天前面插一个分隔；还没交给服务器的放在最后（算今天）
    private var rows: [Row] {
        var out: [Row] = []
        var lastDay: String?
        func day(_ value: String) {
            guard value != lastDay else { return }
            lastDay = value
            out.append(.day(value, Show.daySeparator(value, today: model.today)))
        }
        for note in model.chat {
            day(note.day)
            out.append(.note(note))
        }
        for item in model.outbox {
            day(model.today)
            out.append(.outbox(item))
        }
        return out
    }

    /// 有新的话、最后一段整理完长出结果时滚到底
    private var bottomKey: String {
        let last = model.chat.last
        return "\(last?.id ?? 0)-\(last?.status ?? "")-\(last?.result?.receipt.count ?? 0)-\(model.outbox.count)"
    }
}

/// 你说的那段话：右边的白底框，下面是几点说的和状态
private struct Bubble<Status: View>: View {
    let text: String
    let time: String
    @ViewBuilder let status: () -> Status

    var body: some View {
        VStack(alignment: .trailing, spacing: Web.space1) {
            Text(Show.spaced(text)).font(Web.body).foregroundStyle(Web.fg)
                .padding(.vertical, Web.space2).padding(.horizontal, Web.space3)
                .background(RoundedRectangle(cornerRadius: Web.radiusCard).fill(Web.bg))
                .overlay(RoundedRectangle(cornerRadius: Web.radiusCard).strokeBorder(Web.line, lineWidth: 1))
            HStack(spacing: Web.space2) {
                Text(time)
                status()
            }
            .font(Web.caption).foregroundStyle(Web.fgTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, Web.space12)
    }
}

/// 还没交给服务器的一段话
private struct OutboxMessage: View {
    @Environment(AppModel.self) private var model
    let item: AppModel.Outbox

    var body: some View {
        Bubble(text: item.text, time: MoodRows.clock(ISO8601DateFormatter().string(from: item.createdAt))) {
            if item.failed == nil {
                Text("正在保存")
            } else {
                HStack(spacing: Web.space1) {
                    Text("没有保存上 ·").foregroundStyle(Web.danger)
                    Button("重试") { Task { await model.flushOutbox() } }
                        .font(Web.captionMedium).foregroundStyle(Web.accent).buttonStyle(.plain)
                }
            }
        }
    }
}

/// 一段原话 + 它的整理结果：右边是你说的话，左边是安静的收据、回复、追问
private struct NoteMessage: View {
    @Environment(AppModel.self) private var model
    let note: API.Note

    var body: some View {
        let result = note.result
        let receipt = result.flatMap { Show.receipt($0.receipt) }
        let hasReply =
            result.map { result in
                receipt != nil || !result.reply.isEmpty || !result.questions.isEmpty || !result.notices.isEmpty
                    || !(result.created ?? []).isEmpty || !(result.learned ?? []).isEmpty
                    || !(result.goals ?? []).isEmpty || !(result.advanced ?? []).isEmpty || result.answer != nil
            } ?? false
        VStack(spacing: Web.space3) {
            Bubble(text: note.text, time: MoodRows.clock(note.createdAt)) { status(quiet: hasReply) }
            if note.status == "failed", let error = note.error {
                Text(Show.spaced(error)).font(Web.caption).foregroundStyle(Web.fgTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let result, hasReply {
                Reply(note: note, result: result, receipt: receipt)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, Web.space12)
            }
        }
    }

    /// 原话下面的状态：整理中、等着、没整理成（能重试）；整理好了下面有收据就只留一个对勾
    @ViewBuilder private func status(quiet: Bool) -> some View {
        switch note.status {
        case "processing":
            Text("正在整理…")
        case "pending":
            Label("已保存 · 待处理", systemImage: "circle").labelStyle(StatusLabelStyle())
        case "confirm":
            Label("待确认", systemImage: "circle.dashed").labelStyle(StatusLabelStyle())
                .foregroundStyle(Web.fgSecondary)
        case "failed":
            HStack(spacing: Web.space1) {
                Label("处理失败", systemImage: "xmark").labelStyle(StatusLabelStyle()).foregroundStyle(Web.danger)
                Button("重试") { model.retry(note: note.id) }.font(Web.captionMedium).foregroundStyle(Web.accent)
                    .buttonStyle(.plain)
            }
        default:
            let label = Show.doneLabel(note.result)
            if quiet {
                Image(systemName: "checkmark").accessibilityLabel(Text(label))
            } else {
                Label(label, systemImage: "checkmark").labelStyle(StatusLabelStyle())
            }
        }
    }
}

/// 整理的结果（左边，不用气泡）：收据和「撤销」、目标的变化、推进了目标、新建了类别、记住了、回复、回答、追问、说明
private struct Reply: View {
    @Environment(AppModel.self) private var model
    let note: API.Note
    let result: API.NoteResult
    let receipt: String?

    var body: some View {
        let undone = result.undone == true
        VStack(alignment: .leading, spacing: Web.space1) {
            if let receipt {
                Text(receiptText(receipt, undone: undone)).font(Web.body).environment(\.openURL, undoAction)
            }
            ForEach(result.goals ?? [], id: \.self) { line in
                Text(Show.spaced(line)).font(Web.body).foregroundStyle(Web.fgSecondary).strikethrough(undone)
            }
            if receipt == nil, !(result.goals ?? []).isEmpty {
                if undone {
                    muted("已撤销，原话还在")
                } else {
                    Button("撤销") { model.undo(note: note.id) }.font(Web.bodyMedium).foregroundStyle(Web.accent)
                        .buttonStyle(.plain)
                }
            }
            if !undone, let advanced = result.advanced, !advanced.isEmpty {
                muted("推进了目标：\(advanced.joined(separator: "、"))")
            }
            if !undone, let created = result.created, !created.isEmpty {
                muted("新建了类别：\(created.joined(separator: "、"))")
            }
            if !undone, let learned = result.learned, !learned.isEmpty {
                muted("记住了：\(learned.joined(separator: "、"))")
            }
            if !result.reply.isEmpty { Text(Show.spaced(result.reply)).font(Web.body).foregroundStyle(Web.fg) }
            if let answer = result.answer { Text(Show.spaced(answer.text)).font(Web.body).foregroundStyle(Web.fg) }
            ForEach(result.questions, id: \.self) { question in
                Text(Show.spaced(question)).font(Web.bodyMedium).foregroundStyle(Web.fg)
            }
            ForEach(result.notices, id: \.self) { muted($0) }
        }
    }

    private func muted(_ text: String) -> some View {
        Text(Show.spaced(text)).font(Web.caption).foregroundStyle(Web.fgTertiary)
    }

    private var undoAction: OpenURLAction {
        OpenURLAction { _ in
            model.undo(note: note.id)
            return .handled
        }
    }

    /// 收据后面紧跟「撤销」；撤销了就划掉，后面说一句「已撤销，原话还在」
    private func receiptText(_ receipt: String, undone: Bool) -> AttributedString {
        var text = AttributedString(Show.spaced(receipt))
        text.foregroundColor = Web.fgSecondary
        if undone {
            text.strikethroughStyle = .single
            var tail = AttributedString(" 已撤销，原话还在")
            tail.font = Web.caption
            tail.foregroundColor = Web.fgTertiary
            return text + tail
        }
        var undo = AttributedString("撤销")
        undo.foregroundColor = Web.accent
        undo.font = Web.bodyMedium
        undo.link = URL(string: "pour://undo")
        return text + AttributedString(" ") + undo
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
