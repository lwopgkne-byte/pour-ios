import PourAPI
import PourCore
import PourDesign
import SwiftUI
import UIKit

// 说一句弹层里的一条条（照可交互原型 ChatSheet 1:1）：你的话在右边蓝底白字的气泡里（.bub.me），
// Pour 的在左边白气泡里（.bub.pour）；气泡最宽八成，圆角 18，贴着说话人那一角 6

/// 你说的话（原型 .bub.me）：右边蓝底白字；平常下面不写什么，只在补记、没整理成、没网时写一行小字（原型 .cmt）；长按能复制
struct Bubble<Note: View>: View {
    let text: String
    @ViewBuilder let note: () -> Note

    var body: some View {
        VStack(alignment: .trailing, spacing: Theme.Space.tight) {
            Text(Show.spaced(text)).font(Theme.Typeface.message).foregroundStyle(Theme.Palette.onAccent)
                .lineSpacing(Theme.Leading.body)
                .padding(.vertical, Theme.Space.small + Theme.Space.hairline).padding(.horizontal, Theme.Space.inset)
                .background(
                    Theme.Palette.accentFill,
                    in: UnevenRoundedRectangle(
                        topLeadingRadius: Theme.Corner.receipt, bottomLeadingRadius: Theme.Corner.receipt,
                        bottomTrailingRadius: Theme.Corner.tail, topTrailingRadius: Theme.Corner.receipt,
                        style: .continuous)
                )
                .contextMenu {
                    Button("复制", systemImage: "doc.on.doc") { UIPasteboard.general.string = text }
                }
            note()
                .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, Bubble<EmptyView>.inset)
    }

    /// 气泡最宽八成：另一边空出两成
    static var inset: CGFloat { Theme.Space.section * 2 + Theme.Space.small }
}

extension View {
    /// Pour 说的（原型 .bub.pour）：左边白气泡，左下角小一点，一点点影子；最宽八成（trailing：右边至少空多少；
    /// 待办的结果卡片空得少一点，三个小标签放得下一行，设计稿 after-07-voice）
    func pourBubble(padding: CGFloat = Theme.Space.inset, trailing: CGFloat = Bubble<EmptyView>.inset) -> some View {
        self
            .padding(.vertical, Theme.Space.small + Theme.Space.hairline).padding(.horizontal, padding)
            .background(
                Theme.Palette.card,
                in: UnevenRoundedRectangle(
                    topLeadingRadius: Theme.Corner.receipt, bottomLeadingRadius: Theme.Corner.tail,
                    bottomTrailingRadius: Theme.Corner.receipt, topTrailingRadius: Theme.Corner.receipt,
                    style: .continuous)
            )
            .shadow(color: Theme.Palette.shadowFar, radius: 1, y: 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, trailing)
    }
}

/// 还没交给服务器的一段话：下面一行「正在保存」，没网时「没有保存上 · 先存在手机上，连上自动发 · 重试」
struct OutboxMessage: View {
    @Environment(AppModel.self) private var model
    let item: AppModel.Outbox

    var body: some View {
        Bubble(text: item.text) {
            VStack(alignment: .trailing, spacing: Theme.Space.hairline) {
                if let day = item.day { Text("补记到 \(Show.monthDay(day))") }
                if item.failed == nil {
                    Text("正在保存…")
                } else {
                    HStack(spacing: Theme.Space.tight) {
                        Text("没有保存上 · 先存在手机上，连上自动发 ·")
                        ThemeTextButton("重试", font: Theme.Typeface.footnote) { Task { await model.flushOutbox() } }
                    }
                }
            }
        }
    }
}

/// 一段原话 + 它的整理结果：右边是你说的话，左边是收据、回复、回答、追问
struct NoteMessage: View {
    @Environment(AppModel.self) private var model
    let note: API.Note

    var body: some View {
        let result = note.result
        VStack(spacing: Theme.Space.small) {
            Bubble(text: note.text) { NoteStatus(note: note) }
            switch note.status {
            case "processing":
                // 正在生成的回答逐字出来；还没字的时候一个「整理中…」的白气泡（原型）
                if let live = model.answers[note.id], !live.isEmpty {
                    Text(Show.spaced(live)).font(Theme.Typeface.message).foregroundStyle(Theme.Palette.label)
                        .pourBubble()
                } else {
                    Text("整理中…").font(Theme.Typeface.message).foregroundStyle(Theme.Palette.secondaryLabel)
                        .pourBubble()
                }
            default:
                if let result, Self.hasReply(result) { Reply(note: note, result: result) }
            }
        }
    }

    static func hasReply(_ result: API.NoteResult) -> Bool {
        !result.receipt.isEmpty || !result.reply.isEmpty || !result.questions.isEmpty || !result.notices.isEmpty
            || !(result.created ?? []).isEmpty || !(result.learned ?? []).isEmpty
            || !(result.goals ?? []).isEmpty || !(result.cards ?? []).isEmpty || !(result.advanced ?? []).isEmpty
            || result.answer != nil
    }
}

/// 你说的话下面那一行小字（原型 .cmt）：补记到哪天、等着、待确认、没整理成（红字 + 重试）；整理好了不写
private struct NoteStatus: View {
    @Environment(AppModel.self) private var model
    let note: API.Note

    var body: some View {
        VStack(alignment: .trailing, spacing: Theme.Space.hairline) {
            if note.backfill == true { Text("补记到 \(Show.monthDay(note.day))") }
            switch note.status {
            case "pending": Text("已保存 · 待处理")
            case "confirm": Text("待确认")
            case "failed":
                HStack(spacing: Theme.Space.tight) {
                    Text(Show.spaced(note.error ?? "没整理成")).foregroundStyle(Theme.Palette.bad)
                    Text("·").foregroundStyle(Theme.Palette.bad)
                    ThemeTextButton("重试", font: Theme.Typeface.footnote) { model.retry(note: note.id) }
                }
            default: EmptyView()
            }
        }
    }
}

/// 整理的结果：收据一条一张（最后一张上「撤销」，撤的是这一整段话）、目标和画布的变化、回复、回答、追问、说明
private struct Reply: View {
    @Environment(AppModel.self) private var model
    @Environment(\.latestNote) private var latestNote
    let note: API.Note
    let result: API.NoteResult
    /// 「拿不准的时候先问你，不瞎猜」只在第一次问的那段话下面写（待办 2.0 第 10 步）：记着是哪一段
    @AppStorage("chat.askExplained") private var askExplained = 0

    var body: some View {
        let undone = result.undone == true
        let changes = (result.goals ?? []) + (result.cards ?? [])
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            ForEach(Array(result.receipt.enumerated()), id: \.offset) { index, item in
                let last = index == result.receipt.count - 1
                ReceiptRow(
                    item: item, undone: undone, undo: last && changes.isEmpty ? { model.undo(note: note.id) } : nil,
                    extras: last ? extras(undone: undone) : [])
                if let todo = item.todo, !undone, latestNote == note.id {
                    TodoWindowAsk(entryId: item.entryId, todo: todo)
                }
            }
            // 目标的变化、画布的变化（新卡片、改名字、不再显示）：一个白气泡，一样一行，撤销了划掉
            if !changes.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Space.tight) {
                    ForEach(changes, id: \.self) { line in
                        Text(Show.spaced(line)).font(Theme.Typeface.message).foregroundStyle(Theme.Palette.label)
                            .strikethrough(undone)
                    }
                    if undone {
                        Text("已撤销，原话还在").font(Theme.Typeface.footnote).foregroundStyle(
                            Theme.Palette.secondaryLabel)
                    } else {
                        ThemeTextButton("撤销", font: Theme.Typeface.subheadline) { model.undo(note: note.id) }
                    }
                }
                .pourBubble()
            }
            if result.receipt.isEmpty, !undone, !extras(undone: undone).isEmpty {
                VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                    ForEach(extras(undone: undone), id: \.self) { extra($0) }
                }
                .padding(.horizontal, Theme.Space.tight)
            }
            if !undone, let learned = result.learned, !learned.isEmpty {
                LearnedLine(learned: learned).padding(.horizontal, Theme.Space.tight)
            }
            if !result.reply.isEmpty {
                Text(Show.spaced(result.reply)).font(Theme.Typeface.message).foregroundStyle(Theme.Palette.label)
                    .lineSpacing(Theme.Leading.body)
                    .pourBubble()
            }
            if let answer = result.answer { AnswerView(answer: answer, font: Theme.Typeface.message).pourBubble() }
            // 追问（原型的 ask）：问的话 + 一行小字说为什么问
            ForEach(result.questions, id: \.self) { question in
                VStack(alignment: .leading, spacing: Theme.Space.snug) {
                    Text(Show.spaced(question)).font(Theme.Typeface.message).foregroundStyle(Theme.Palette.label)
                        .lineSpacing(Theme.Leading.body)
                    if askExplained == 0 || askExplained == note.id {
                        Text("拿不准的时候先问你，不瞎猜").font(Theme.Typeface.footnote)
                            .foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                }
                .pourBubble()
                .onAppear { if askExplained == 0 { askExplained = note.id } }
            }
            ForEach(result.notices, id: \.self) { notice in
                Text(Show.spaced(notice)).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    .padding(.horizontal, Theme.Space.tight)
            }
        }
    }

    /// 收据下面的几行小字：推进了目标（绿）、新建了类别
    private func extras(undone: Bool) -> [String] {
        guard !undone else { return [] }
        var out: [String] = []
        if let advanced = result.advanced, !advanced.isEmpty { out.append("推进了目标：\(advanced.joined(separator: "、"))") }
        if let created = result.created, !created.isEmpty { out.append("新建了类别：\(created.joined(separator: "、"))") }
        return out
    }

    private func extra(_ line: String) -> some View {
        Text(Show.spaced(line)).font(Theme.Typeface.footnote)
            .foregroundStyle(line.hasPrefix("推进了目标") ? Theme.Palette.good : Theme.Palette.secondaryLabel)
    }
}

/// 一条收据（原型「说一句」）：白气泡里左边彩色小方块（待办蓝、钱橙、心情粉、感悟金、别的灰，白色小图标）+
/// 粗体那件事 + 灰字（类别、地方、和谁）+ 下面的小字，右边「撤销」；撤销了划掉，写一句原话还在
struct ReceiptRow: View {
    @Environment(AppModel.self) private var model
    let item: API.ReceiptItem
    let undone: Bool
    /// 只有最后一张有（撤的是这一整段话）
    let undo: (() -> Void)?
    let extras: [String]

    var body: some View {
        let parts = Self.parts(item, categories: model.categories)
        HStack(alignment: .center, spacing: Theme.Space.small) {
            Image(systemName: Self.symbol(item)).font(Theme.Typeface.subheadline)
                .foregroundStyle(Theme.Palette.onAccent)
                .frame(width: Theme.Size.tile, height: Theme.Size.tile)
                .background(Self.color(item), in: Theme.rounded(Theme.Corner.tile))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.small) {
                    Text(Show.spaced(item.todo?.content ?? parts.title)).font(Theme.Typeface.cardTitle)
                        .foregroundStyle(Theme.Palette.label)
                        .strikethrough(undone)
                        .fixedSize(horizontal: false, vertical: true)
                    // 待办 2.0：改了已有的待办写「已改」
                    if item.todo != nil, item.action == "updated", !undone {
                        Text("已改").font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                }
                if undone {
                    Text("已撤销，原话还在").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                } else if let todo = item.todo, item.kind == "todo" {
                    TodoReceiptTags(entryId: item.entryId, snapshot: todo)
                } else if !parts.sub.isEmpty {
                    Text(Show.spaced(parts.sub)).font(Theme.Typeface.footnote)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(extras, id: \.self) { line in
                    Text(Show.spaced(line)).font(Theme.Typeface.footnote)
                        .foregroundStyle(line.hasPrefix("推进了目标") ? Theme.Palette.good : Theme.Palette.secondaryLabel)
                        .padding(.top, Theme.Space.hairline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("\(Self.verb(item))：\(Show.spaced(item.text))\(undone ? "，已撤销" : "")"))
            if let undo, !undone {
                ThemeTextButton("撤销", font: Theme.Typeface.subheadline, action: undo)
            }
        }
        .pourBubble(
            padding: Theme.Space.medium, trailing: item.todo == nil ? Bubble<EmptyView>.inset : Theme.Space.section)
    }

    /// 「已记录」「已修改」「已完成」……（读屏念的、界面测试认的）
    static func verb(_ item: API.ReceiptItem) -> String {
        switch item.action {
        case "updated": "已修改"
        case "completed": "已完成"
        case "confirmed": "已确认"
        case "deleted": "已删除"
        default: "已记录"
        }
    }

    /// 收据那一行拆开（服务器的 describeEntry）：「🍽 食堂午饭 ¥15 · 在公司食堂」→ 粗体「食堂午饭 ¥15」、灰字「饮食 · 在公司食堂」；
    /// 「💭 心情：挺好 · 开心（AI 推测）」→「挺好」「心情 · 开心（AI 推测）」；末尾括号里的（几点提醒、之前已记过）挪到灰字里
    static func parts(_ item: API.ReceiptItem, categories: [API.Category]) -> (title: String, sub: String) {
        var text = Show.receiptBare(item).trimmingCharacters(in: .whitespaces)
        var emoji: String?
        if let first = text.first, isEmoji(first) {
            emoji = String(first)
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        var pieces = text.components(separatedBy: " · ").map { $0.trimmingCharacters(in: .whitespaces) }
        var title = pieces.removeFirst()
        var kindName: String?
        if let colon = title.firstIndex(of: "："), title.distance(from: title.startIndex, to: colon) <= 3 {
            kindName = String(title[..<colon])
            title = String(title[title.index(after: colon)...])
        }
        if title.hasSuffix("）"), let open = title.lastIndex(of: "（"), open > title.startIndex {
            pieces.insert(String(title[title.index(after: open)..<title.index(before: title.endIndex)]), at: 0)
            title = String(title[..<open])
        }
        let category = emoji.flatMap { emoji in categories.first { $0.emoji == emoji }?.name }
        var sub = [kindName ?? category].compactMap { $0 } + pieces.filter { !$0.isEmpty }
        if !["created", "duplicate"].contains(item.action) { sub.insert(verb(item), at: 0) }
        if item.pending { sub.append("待确认") }
        return (title.isEmpty ? item.text : title, sub.joined(separator: " · "))
    }

    /// 开头那个是不是表情（「🍽」不带变体符号也算；数字、井号、星号不算）
    static func isEmoji(_ character: Character) -> Bool {
        guard let first = character.unicodeScalars.first else { return false }
        return first.properties.isEmoji && !first.isASCII
    }

    /// 小方块的颜色和图标：待办、钱（说了多少钱的）、心情、感悟，别的一个对勾
    static func color(_ item: API.ReceiptItem) -> Color {
        switch kind(item) {
        case .todo: Theme.Palette.kindTodo
        case .money: Theme.Palette.kindMoney
        case .mood: Theme.Palette.kindMood
        case .insight: Theme.Palette.kindInsight
        case .other: Theme.Palette.kindNote
        }
    }

    static func symbol(_ item: API.ReceiptItem) -> String {
        switch kind(item) {
        case .todo: "checklist"
        case .money: "yensign"
        case .mood: Theme.Symbol.mood
        case .insight: "lightbulb"
        case .other: "checkmark"
        }
    }

    private enum Kind { case todo, money, mood, insight, other }

    private static func kind(_ item: API.ReceiptItem) -> Kind {
        switch item.kind {
        case "todo": .todo
        case "mood": .mood
        case "insight": .insight
        default: item.text.contains("¥") ? .money : .other
        }
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
