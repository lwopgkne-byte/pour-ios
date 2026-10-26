import PourAPI
import PourCore
import PourDesign
import SwiftUI
import UIKit

/// 你说的话：右边浅蓝的气泡（右下角小一点），下面一行时间 + 状态；长按能复制
struct Bubble<Status: View>: View {
    let text: String
    let time: String
    /// 时间前面的一小段：「补记到 10月24日」
    var tag: String?
    @ViewBuilder let status: () -> Status

    var body: some View {
        VStack(alignment: .trailing, spacing: Theme.Space.tight) {
            Text(Show.spaced(text)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                .lineSpacing(Theme.Leading.body)
                .padding(.vertical, Theme.Space.small + Theme.Space.hairline).padding(.horizontal, Theme.Space.inset)
                .background(
                    Theme.Palette.bubble,
                    in: UnevenRoundedRectangle(
                        topLeadingRadius: Theme.Corner.bubble, bottomLeadingRadius: Theme.Corner.bubble,
                        bottomTrailingRadius: Theme.Corner.bar, topTrailingRadius: Theme.Corner.bubble,
                        style: .continuous)
                )
                .contextMenu {
                    Button("复制", systemImage: "doc.on.doc") { UIPasteboard.general.string = text }
                }
            HStack(spacing: Theme.Space.snug) {
                if let tag { Text("\(tag) ·") }
                Text(time).monospacedDigit()
                status()
            }
            .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, Theme.Space.section + Theme.Space.regular)
    }
}

/// 还没交给服务器的一段话：「正在保存」，没网时「没有保存上 · 重试」
struct OutboxMessage: View {
    @Environment(AppModel.self) private var model
    let item: AppModel.Outbox

    var body: some View {
        Bubble(
            text: item.text, time: Show.formatClock(ISO8601DateFormatter().string(from: item.createdAt)),
            tag: item.day.map { "补记到 \(Show.monthDay($0))" }
        ) {
            if item.failed == nil {
                Label("正在保存", systemImage: "arrow.up.circle").labelStyle(ChatStatusStyle())
            } else {
                HStack(spacing: Theme.Space.tight) {
                    Text("没有保存上 ·").foregroundStyle(Theme.Palette.bad)
                    Button("重试") { Task { await model.flushOutbox() } }
                        .font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.accent).buttonStyle(.plain)
                        .frame(minHeight: Theme.Size.touch)
                }
            }
        }
    }
}

/// 一段原话 + 它的整理结果：右边是你说的话，左边是收据小卡、回复、追问
struct NoteMessage: View {
    @Environment(AppModel.self) private var model
    let note: API.Note

    var body: some View {
        let result = note.result
        let receipt = result.flatMap { Show.receipt($0.receipt) }
        let hasReply = result.map { Self.hasReply($0, receipt: receipt) } ?? false
        VStack(spacing: Theme.Space.medium) {
            Bubble(
                text: note.text, time: Show.formatClock(note.createdAt),
                tag: note.backfill == true ? "补记到 \(Show.monthDay(note.day))" : nil
            ) { NoteStatus(note: note, quiet: hasReply) }
            if note.status == "failed", let error = note.error {
                Text(Show.spaced(error)).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            // 正在生成的回答：整理完之前逐字显示（整理好了下面的回答是完整的）
            if note.status == "processing", let live = model.answers[note.id], !live.isEmpty {
                Text(Show.spaced(live)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, Theme.Space.section)
            }
            if let result, hasReply {
                Reply(note: note, result: result, receipt: receipt)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, Theme.Space.section)
            }
        }
    }

    static func hasReply(_ result: API.NoteResult, receipt: String?) -> Bool {
        receipt != nil || !result.reply.isEmpty || !result.questions.isEmpty || !result.notices.isEmpty
            || !(result.created ?? []).isEmpty || !(result.learned ?? []).isEmpty
            || !(result.goals ?? []).isEmpty || !(result.cards ?? []).isEmpty || !(result.advanced ?? []).isEmpty
            || result.answer != nil
    }
}

/// 原话下面的状态：整理中（呼吸的小图标）、等着、待确认、没整理成（能重试）；整理好了下面有收据就只留一个对勾
private struct NoteStatus: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let note: API.Note
    let quiet: Bool

    var body: some View {
        switch note.status {
        case "processing":
            Label("正在整理…", systemImage: "sparkles").labelStyle(ChatStatusStyle())
                .symbolEffect(.breathe, options: .repeating, isActive: !reduceMotion)
        case "pending":
            Label("已保存 · 待处理", systemImage: "clock").labelStyle(ChatStatusStyle())
        case "confirm":
            Label("待确认", systemImage: "questionmark.circle").labelStyle(ChatStatusStyle())
        case "failed":
            HStack(spacing: Theme.Space.tight) {
                Label("处理失败", systemImage: "exclamationmark.circle").labelStyle(ChatStatusStyle())
                    .foregroundStyle(Theme.Palette.bad)
                Button("重试") { model.retry(note: note.id) }
                    .font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.accent).buttonStyle(.plain)
                    .frame(minHeight: Theme.Size.touch)
            }
        default:
            let label = Show.doneLabel(note.result)
            if quiet {
                Image(systemName: "checkmark").accessibilityLabel(Text(label))
            } else {
                Label(label, systemImage: "checkmark").labelStyle(ChatStatusStyle())
            }
        }
    }
}

/// 整理的结果（左边，不用气泡）：收据小卡和「撤销」、目标的变化、推进了目标、新建了类别、记住了、回复、回答、追问、说明
private struct Reply: View {
    @Environment(AppModel.self) private var model
    let note: API.Note
    let result: API.NoteResult
    let receipt: String?

    var body: some View {
        let undone = result.undone == true
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            if let receipt { ReceiptCard(text: receipt, undone: undone) { model.undo(note: note.id) } }
            // 目标的变化、画布的变化（新卡片、改名字、不再显示，docs/模块/产品优化.md R3、R2）：一样一行，撤销了划掉
            ForEach((result.goals ?? []) + (result.cards ?? []), id: \.self) { line in
                Text(Show.spaced(line)).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
                    .strikethrough(undone)
            }
            if receipt == nil, !(result.goals ?? []).isEmpty || !(result.cards ?? []).isEmpty {
                if undone {
                    muted("已撤销，原话还在")
                } else {
                    Button("撤销") { model.undo(note: note.id) }.font(Theme.Typeface.footnoteSemibold)
                        .foregroundStyle(Theme.Palette.accent).buttonStyle(.plain).frame(minHeight: Theme.Size.touch)
                }
            }
            if !undone, let advanced = result.advanced, !advanced.isEmpty {
                muted("推进了目标：\(advanced.joined(separator: "、"))")
            }
            if !undone, let created = result.created, !created.isEmpty {
                muted("新建了类别：\(created.joined(separator: "、"))")
            }
            if !undone, let learned = result.learned, !learned.isEmpty { LearnedLine(learned: learned) }
            if !result.reply.isEmpty {
                Text(Show.spaced(result.reply)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
            }
            if let answer = result.answer { AnswerView(answer: answer) }
            ForEach(result.questions, id: \.self) { question in
                Text(Show.spaced(question)).font(Theme.Typeface.bodyMedium).foregroundStyle(Theme.Palette.label)
            }
            ForEach(result.notices, id: \.self) { muted($0) }
        }
    }

    private func muted(_ text: String) -> some View {
        Text(Show.spaced(text)).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
    }
}

/// 收据小卡：「✓ 已记录：🏃 跑步 32 分钟 5 公里、🍽 吃面 ¥32」+ 右边「撤销」；撤销了划掉，下面说一句原话还在
private struct ReceiptCard: View {
    let text: String
    let undone: Bool
    let undo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.small) {
                Image(systemName: undone ? "arrow.uturn.backward" : "checkmark.circle.fill")
                    .foregroundStyle(undone ? Theme.Palette.secondaryLabel : Theme.Palette.good)
                Text(Show.spaced(text)).font(Theme.Typeface.subheadline)
                    .foregroundStyle(undone ? Theme.Palette.secondaryLabel : Theme.Palette.label)
                    .strikethrough(undone).lineSpacing(Theme.Leading.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !undone { undoButton }
            }
            if undone {
                Text("已撤销，原话还在").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            }
        }
        .padding(.horizontal, Theme.Space.medium).padding(.vertical, Theme.Space.tight)
        .background(Theme.Palette.background, in: Theme.rounded(Theme.Corner.receipt))
    }

    private var undoButton: some View {
        Button("撤销", action: undo).font(Theme.Typeface.footnoteSemibold)
            .foregroundStyle(Theme.Palette.accent).buttonStyle(.plain).frame(minHeight: Theme.Size.touch)
    }
}

/// 「记住了：「小王」= 同事」：那个说法能点，收起对话，打开「关于我」里这一条（docs/prd-about-me.md 6.9）
private struct LearnedLine: View {
    @Environment(AppModel.self) private var model
    let learned: [String]

    var body: some View {
        Text(text).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            .environment(
                \.openURL,
                OpenURLAction { url in
                    let find = url.lastPathComponent.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
                    model.open("/about?find=\(find ?? "")")
                    return .handled
                })
    }

    private var text: AttributedString {
        var out = AttributedString("记住了：")
        for (index, item) in learned.enumerated() {
            if index > 0 { out += AttributedString("、") }
            var part = AttributedString(Show.spaced(item))
            if let phrase = Show.learnedPhrase(item) {
                part.foregroundColor = Theme.Palette.accent
                part.font = Theme.Typeface.footnoteSemibold
                part.link = URL(string: "pour://find")?.appending(path: phrase)
            }
            out += part
        }
        return out
    }
}

/// 状态的小图标 + 字
struct ChatStatusStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Theme.Space.tight) {
            configuration.icon
            configuration.title
        }
    }
}
