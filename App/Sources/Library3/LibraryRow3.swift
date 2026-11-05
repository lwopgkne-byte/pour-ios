import PourAPI
import PourDesign
import SwiftUI

/// 一段原话（docs/3.0/01-需求文档.md 第 11 章、06 交互细节 10.7）：时间在左；原话宋体最多两行，点了展开全文和
/// 「回答一下 · 重试 · 修改原话 · 看这一天 · 删除」；下面最多两个整理出的胶囊 +「+3」，点一个开那条记录；
/// 待确认 / 处理失败 / 整理中写在最前面；按意思找到的标「意思相近」。左滑删除、重新整理；按住出菜单
struct LibraryRow3: View {
    @Environment(AppModel.self) private var model
    let note: API.LibraryNote
    let highlight: String
    let open: Bool
    let toggle: () -> Void
    let edit: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.medium) {
            Text(Show.formatClock(note.createdAt)).font(Theme.Typeface.footnote).monospacedDigit()
                .foregroundStyle(Theme.Palette.secondaryLabel)
                .frame(minWidth: Theme.Size.tile + Theme.Space.medium, alignment: .leading)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Space.small) {
                Button(action: toggle) {
                    Text(words).font(Theme.Typeface.quote).foregroundStyle(Theme.Palette.label)
                        .lineSpacing(Theme.Leading.quote / 2).lineLimit(open ? nil : 2).multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(spoken))
                .accessibilityHint(Text(open ? "收起" : "展开全文和能做的"))
                chips
                if open { actions }
            }
        }
        .padding(.vertical, Theme.Space.medium)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("library.note.\(note.id)")
    }

    /// 读屏念的：「17:07，待确认，原话……，意思相近」（时间、状态的小字不单独念）
    private var spoken: String {
        [Show.formatClock(note.createdAt), Self.status(note.status)?.0, note.text, note.similar == true ? "意思相近" : nil]
            .compactMap { $0 }.joined(separator: "，")
    }

    /// 搜索时把命中的字标出来
    private var words: AttributedString {
        var shown = AttributedString(note.text)
        guard !highlight.isEmpty else { return shown }
        var from = shown.startIndex
        while let found = shown[from...].range(of: highlight) {
            shown[found].backgroundColor = Theme.tag("yellow").tint
            from = found.upperBound
        }
        return shown
    }

    @ViewBuilder private var chips: some View {
        let shown = open ? note.entries : Array(note.entries.prefix(2))
        let more = note.entries.count - shown.count
        if note.status != "done" || !shown.isEmpty || note.similar == true {
            PourFlowLayout(spacing: Theme.Space.small, lineSpacing: Theme.Space.tight) {
                if let status = Self.status(note.status) { statusChip(status.0, warn: status.1) }
                ForEach(shown, id: \.id) { entry in
                    Button {
                        model.openEntry(entry.id, day: note.day)
                    } label: {
                        // 照原型：小标签不带表情（服务器写的类别表情去掉，类别看点开的那条）
                        Text(Show.spaced(Show.plain(entry.text))).font(Theme.Typeface.footnote)
                            .foregroundStyle(Theme.Palette.label)
                            .padding(.horizontal, Theme.Space.small).padding(.vertical, Theme.Space.tight)
                            .background(Theme.Palette.fill, in: Capsule())
                            .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("library.entry.\(entry.id)")
                }
                if more > 0 {
                    Button(action: toggle) {
                        Text("+\(more)").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                            .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("还有 \(more) 条"))
                }
                if note.similar == true { statusChip("意思相近", warn: false) }
            }
        }
    }

    private func statusChip(_ text: String, warn: Bool) -> some View {
        Text(text).font(Theme.Typeface.footnoteMedium)
            .foregroundStyle(warn ? Theme.Palette.warnInk : Theme.Palette.secondaryLabel)
            .padding(.horizontal, Theme.Space.small).padding(.vertical, Theme.Space.tight)
            .background(warn ? Theme.Palette.warnFill : Theme.Palette.fill, in: Capsule())
            // 已经念在原话那一句里了
            .accessibilityHidden(true)
    }

    /// 展开以后能做的：待确认的「回答一下」、失败的「重试」、修改原话、看这一天、删除
    private var actions: some View {
        PourFlowLayout(spacing: Theme.Space.medium, lineSpacing: 0) {
            if note.status == "confirm" {
                LinkButton("回答一下", identifier: "library.answer") { model.chatOpen = true }
            }
            if note.status == "failed" {
                LinkButton("重试", identifier: "library.retry") { model.retry(note: note.id) }
            }
            LinkButton("修改原话", identifier: "library.edit", action: edit)
            LinkButton("看这一天", identifier: "library.day") { Self.showDay(note.day, model) }
            LinkButton("删除", identifier: "library.delete") { Self.remove(note, model) }
        }
    }

    /// 状态写什么、要不要显眼（待确认、失败黄底）；已整理的不写
    static func status(_ status: String) -> (String, Bool)? {
        switch status {
        case "processing": ("正在整理…", false)
        case "confirm": ("待确认", true)
        case "failed": ("处理失败", true)
        case "pending": ("已保存 · 待处理", false)
        default: nil
        }
    }

    static func showDay(_ day: String, _ model: AppModel) {
        model.goHome()
        model.show(day)
    }

    /// 删除这段话和它整理出的记录；轻提示带撤销
    static func remove(_ note: API.LibraryNote, _ model: AppModel) {
        let client = model.client
        let id = note.id
        Task {
            do throws(APIError) {
                try await client.delete(note: id)
                model.dataChanged()
                model.toast("已删除这段话和它的记录", action: "撤销") {
                    Task {
                        try? await client.restore(note: id)
                        model.dataChanged()
                    }
                }
            } catch {
                model.toast(error.message)
            }
        }
    }

    /// 重新整理：照原话再整理一遍（以前整理出的撤掉）
    static func reorganize(_ note: API.LibraryNote, _ model: AppModel) {
        let client = model.client
        Task {
            do throws(APIError) {
                try await client.edit(note: note.id, text: note.text)
                model.dataChanged()
                model.toast("正在重新整理这段话")
            } catch {
                model.toast(error.message)
            }
        }
    }
}

/// 一天的卡片里一行的底：第一行上面圆角、最后一行下面圆角（系统列表的行拼成一张卡片）
struct LibraryRowCard: View {
    let first: Bool
    let last: Bool

    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: first ? Theme.Corner.card : 0, bottomLeadingRadius: last ? Theme.Corner.card : 0,
            bottomTrailingRadius: last ? Theme.Corner.card : 0, topTrailingRadius: first ? Theme.Corner.card : 0,
            style: .continuous
        )
        .fill(Theme.Palette.card)
        .padding(.horizontal, Theme.Space.screen)
        .padding(.bottom, last ? Theme.Space.small : 0)
    }
}
