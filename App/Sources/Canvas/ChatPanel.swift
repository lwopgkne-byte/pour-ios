import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 对话面板：按天分隔的历史，每段原话下面是整理的结果；拖上面的小横条往下收起。
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
                        // 翻到最上面自动拿更早的一页，拿完停在原来看的地方（看见「加载更早的记录」就拿）
                        if model.chatHasMore {
                            Dots(label: "加载更早的记录").foregroundStyle(Web.fgTertiary).padding(.top, Web.space2)
                                .onScrollVisibilityChange { visible in
                                    guard visible, let first = rows.first?.id else { return }
                                    Task {
                                        await model.loadEarlierChat()
                                        reader.scrollTo(first, anchor: .top)
                                    }
                                }
                        }
                        if rows.isEmpty {
                            Text("说过的话会出现在这里。").font(Web.body).foregroundStyle(Web.fgTertiary)
                                .padding(.top, Web.space12)
                        }
                        ForEach(rows, id: \.id) { row in
                            switch row {
                            case .day(_, let label):
                                Text(label).font(Web.caption).foregroundStyle(Web.fgTertiary).padding(.top, Web.space2)
                            case .note(let note):
                                NoteMessage(note: note)
                            case .message(let message):
                                MessageCard(message: message)
                            case .outbox(let item):
                                OutboxMessage(item: item)
                            }
                        }
                        // 排队的话共用一个暂停原因（比如还没填大模型的 API Key），只在最后说一次
                        if let blocker {
                            Text(Show.spaced("\(waiting) 段话在排队：\(blocker)")).font(Web.caption)
                                .foregroundStyle(Web.fgTertiary).multilineTextAlignment(.center)
                                .containerRelativeFrame(.horizontal) { width, _ in width * 0.85 }
                                .padding(.top, Web.space2)
                        }
                        if let failed = model.outbox.first(where: { $0.failed != nil })?.failed {
                            Text("\(failed)这段话先存在这台设备上，恢复后会自动重发。")
                                .font(Web.caption).foregroundStyle(Web.fgSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
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
        case message(API.SystemMessage)
        case outbox(AppModel.Outbox)

        var id: String {
            switch self {
            case .day(let day, _): "day-\(day)"
            case .note(let note): "note-\(note.id)"
            case .message(let message): "msg-\(message.id)"
            case .outbox(let item): "out-\(item.clientId)"
            }
        }
    }

    /// 原话和系统消息按时间排，每天前面插一个分隔；还没交给服务器的放在最后（算今天）
    private var rows: [Row] {
        var out: [Row] = []
        var lastDay: String?
        func day(_ value: String) {
            guard value != lastDay else { return }
            lastDay = value
            out.append(.day(value, Show.daySeparator(value, today: model.today)))
        }
        let notes = model.chat.map { (at: $0.createdAt, day: $0.day, row: Row.note($0)) }
        let messages = model.messages.map { message in
            let day = Show.logicalDay(message.createdAt, boundary: model.dayBoundary) ?? model.today
            return (at: message.createdAt, day: day, row: Row.message(message))
        }
        for item in (notes + messages).sorted(by: { $0.at < $1.at }) {
            day(item.day)
            out.append(item.row)
        }
        for item in model.outbox {
            day(model.today)
            out.append(.outbox(item))
        }
        return out
    }

    private var waiting: Int { model.chat.filter { $0.status == "pending" }.count }
    private var blocker: String? { model.chat.first { $0.status == "pending" && $0.error != nil }?.error }

    /// 有新的话、最后一段整理完长出结果时滚到底
    private var bottomKey: String { "\(rows.last?.id ?? "")-\(model.chat.last?.status ?? "")" }
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
        Bubble(text: item.text, time: Show.formatClock(ISO8601DateFormatter().string(from: item.createdAt))) {
            if item.failed == nil {
                HStack(spacing: Web.space1) {
                    Dots()
                    Text("正在保存")
                }
            } else {
                HStack(spacing: Web.space1) {
                    Text("没有保存上 ·").foregroundStyle(Web.danger)
                    WebTextButton("重试", font: Web.captionMedium) { Task { await model.flushOutbox() } }
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
            Bubble(text: note.text, time: Show.formatClock(note.createdAt)) { status(quiet: hasReply) }
            if note.status == "failed", let error = note.error {
                Text(Show.spaced(error)).font(Web.caption).foregroundStyle(Web.fgTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            // 正在生成的回答：整理完之前逐字显示（整理好了下面的回答是完整的）
            if note.status == "processing", let live = model.answers[note.id], !live.isEmpty {
                Text(Show.spaced(live)).font(Web.body).foregroundStyle(Web.fg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, Web.space12)
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
            HStack(spacing: Web.space1) {
                Dots()
                Text("正在整理…")
            }
        case "pending":
            Label("已保存 · 待处理", systemImage: "circle").labelStyle(StatusLabelStyle())
        case "confirm":
            Label("待确认", systemImage: "circle.dashed").labelStyle(StatusLabelStyle())
                .foregroundStyle(Web.fgSecondary)
        case "failed":
            HStack(spacing: Web.space1) {
                Label("处理失败", systemImage: "xmark").labelStyle(StatusLabelStyle()).foregroundStyle(Web.danger)
                WebTextButton("重试", font: Web.captionMedium) { model.retry(note: note.id) }
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
                    WebTextButton("撤销") { model.undo(note: note.id) }
                }
            }
            if !undone, let advanced = result.advanced, !advanced.isEmpty {
                muted("推进了目标：\(advanced.joined(separator: "、"))")
            }
            if !undone, let created = result.created, !created.isEmpty {
                muted("新建了类别：\(created.joined(separator: "、"))")
            }
            if !undone, let learned = result.learned, !learned.isEmpty {
                Text(learnedText(learned)).font(Web.caption).foregroundStyle(Web.fgTertiary)
                    .environment(
                        \.openURL,
                        OpenURLAction { url in
                            let find = url.lastPathComponent.addingPercentEncoding(
                                withAllowedCharacters: .alphanumerics)
                            model.open("/about?find=\(find ?? "")")
                            return .handled
                        })
            }
            if !result.reply.isEmpty { Text(Show.spaced(result.reply)).font(Web.body).foregroundStyle(Web.fg) }
            if let answer = result.answer { AnswerView(answer: answer) }
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

    /// 「记住了：「小王」= 同事」能点：收起对话，打开「关于我」里这一条（docs/prd-about-me.md 6.9）
    private func learnedText(_ learned: [String]) -> AttributedString {
        var text = AttributedString("记住了：")
        for (index, item) in learned.enumerated() {
            if index > 0 { text += AttributedString("、") }
            var part = AttributedString(Show.spaced(item))
            if let phrase = Show.learnedPhrase(item) {
                part.foregroundColor = Web.accent
                part.font = Web.captionMedium
                part.link = URL(string: "pour://find")?.appending(path: phrase)
            }
            text += part
        }
        return text
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
