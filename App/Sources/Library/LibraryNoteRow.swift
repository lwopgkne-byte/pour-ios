import PourAPI
import PourDesign
import SwiftUI

/// 一天的原话：日期标题（「10月19日 周一 昨天」）、「看这一天 →」，下面一段一段
struct DayNotes: View {
    @Environment(AppModel.self) private var model
    let day: String
    let notes: [API.LibraryNote]
    let focus: Int?
    let highlight: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Web.space3) {
                Text(
                    rich(
                        [.init(Show.dayTitle(day, today: model.today), font: Web.bodySemibold)]
                            + (Show.relative(day, today: model.today).map {
                                [.init("  \($0)", color: Web.fgTertiary)]
                            } ?? []))
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
                Button("看这一天 →") {
                    model.page = .canvas
                    model.show(day)
                }
                .buttonStyle(.plain).font(Web.caption).foregroundStyle(Web.fgTertiary)
                .frame(minHeight: Web.touch).contentShape(Rectangle())
                .padding(.vertical, -(Web.touch - Web.space6) / 2)
            }
            .padding(.bottom, Web.space2)
            .overlay(alignment: .bottom) { Rectangle().fill(Web.line).frame(height: 1) }
            .padding(.bottom, Web.space1)
            ForEach(notes) { NoteRow(note: $0, focused: $0.id == focus, highlight: highlight) }
        }
    }
}

/// 一段原话：时间在左，原话是正文，整理结果是一排小标签；右边「…」里能改、重试、删。
/// 改：原地变成输入框，按「完成」或者点别处就保存，服务器自动重新整理
struct NoteRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    let note: API.LibraryNote
    let focused: Bool
    let highlight: String
    @State private var editing = false
    @State private var text = ""
    @State private var saving = false
    @FocusState private var typing: Bool

    var body: some View {
        // 收据里目标那几行，写成小标签
        let goals =
            note.result?.undone == true ? [] : (note.result?.goals ?? []).map { "🎯 \($0.replacing(/^🎯\s*/, with: ""))" }
        // 字很大时时间放在上面一行，原话不被挤窄
        let layout =
            typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Web.space1))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Web.space2))
        layout {
            Text(Show.formatClock(note.createdAt)).font(Web.caption).foregroundStyle(Web.fgTertiary).monospacedDigit()
                .fixedSize().frame(minWidth: Web.space12, alignment: .leading)
            VStack(alignment: .leading, spacing: Web.space2) {
                if editing { editor } else { words }
                if !note.entries.isEmpty || note.status != "done" || !goals.isEmpty {
                    // 字很大时一个标签一行（能折行），不挤出屏幕
                    let pills =
                        typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: Web.space1))
                        : AnyLayout(PourFlowLayout(spacing: Web.space2, lineSpacing: Web.space1))
                    pills {
                        if note.status != "done" { NoteStatusLabel(note: note.note) }
                        ForEach(note.entries, id: \.id) { pill($0.text) }
                        ForEach(goals, id: \.self) { pill($0) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            menu
        }
        .padding(.vertical, Web.space3).padding(.horizontal, Web.space2)
        .background(RoundedRectangle(cornerRadius: Web.radiusControl).fill(focused ? Web.tag("yellow").bg : .clear))
        .padding(.horizontal, -Web.space2)
        .id(note.id)
    }

    /// 搜索时把命中的字标出来
    private var words: some View {
        var shown = AttributedString(note.text)
        if !highlight.isEmpty {
            var from = shown.startIndex
            while let found = shown[from...].range(of: highlight) {
                shown[found].backgroundColor = Web.tag("yellow").bg
                from = found.upperBound
            }
        }
        return PourFlowLayout(spacing: Web.space2, lineSpacing: Web.space1) {
            Text(shown).font(Web.body).foregroundStyle(Web.fg).lineSpacing(Web.bodyLineSpacing)
                .fixedSize(horizontal: false, vertical: true)
            if note.similar == true { MoneyTag(text: "意思相近") }
        }
    }

    private var editor: some View {
        TextField("修改原话", text: $text, axis: .vertical)
            .lineLimit(2...8)
            .font(Web.body).foregroundStyle(Web.fg)
            .focused($typing)
            .disabled(saving)
            .submitLabel(.done)
            .onSubmit { save() }
            .padding(Web.space2)
            .background(RoundedRectangle(cornerRadius: Web.radiusControl).fill(Web.bg))
            .overlay(RoundedRectangle(cornerRadius: Web.radiusControl).strokeBorder(Web.accent, lineWidth: 1))
            .onChange(of: typing) { _, now in if !now { save() } }
            .accessibilityLabel(Text("修改原话"))
    }

    /// 一个小标签：前面的表情和字分开放（表情连着字时，审计量「截断」不准）
    private func pill(_ text: String) -> some View {
        let parts = text.split(separator: " ", maxSplits: 1).map(String.init)
        let emoji =
            parts.count == 2 && parts[0].unicodeScalars.allSatisfy { $0.properties.isEmoji && $0.value > 0x238C }
        return HStack(alignment: .firstTextBaseline, spacing: Web.space1) {
            if emoji { Text(parts[0]) }
            Text(emoji ? parts[1] : text).fixedSize(horizontal: false, vertical: true)
        }
        .font(Web.caption).foregroundStyle(Web.fgSecondary)
        .padding(.horizontal, Web.space2)
        .background(Capsule().fill(Web.bgSubtle))
        .accessibilityElement(children: .combine)
    }

    private var menu: some View {
        Menu {
            Button("修改") { startEditing() }
            if note.status == "failed" { Button("重试") { model.retry(note: note.id) } }
            Button("删除", role: .destructive) { remove() }
        } label: {
            Image(systemName: "ellipsis").font(Web.body).foregroundStyle(Web.fgSecondary)
                .frame(width: Web.touch, height: Web.touch).contentShape(Rectangle())
        }
        .padding(.vertical, -Web.space3)
        .accessibilityLabel(Text("更多操作"))
    }

    private func startEditing() {
        text = note.text
        editing = true
        typing = true
    }

    private func save() {
        guard editing, !saving else { return }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value != note.text else {
            editing = false
            return
        }
        saving = true
        let client = model.client
        Task {
            defer { saving = false }
            do {
                try await client.edit(note: note.id, text: value)
                editing = false
                model.dataChanged()
                model.toast("已修改，正在重新整理")
            } catch {
                model.toast(error.readable)
            }
        }
    }

    private func remove() {
        let client = model.client
        let id = note.id
        Task {
            do {
                try await client.delete(note: id)
                model.dataChanged()
                model.toast("已删除这段话和它的记录", action: "撤销") {
                    Task {
                        try? await client.restore(note: id)
                        model.dataChanged()
                    }
                }
            } catch {
                model.toast(error.readable)
            }
        }
    }
}

/// 原话的处理状态（网页版 StatusLabel）：整理中、已保存 · 待处理、待确认、处理失败（能重试）
struct NoteStatusLabel: View {
    @Environment(AppModel.self) private var model
    let note: API.Note

    var body: some View {
        HStack(spacing: Web.space1) {
            switch note.status {
            case "processing":
                Dots()
                Text("正在整理…")
            case "confirm":
                Image(systemName: "circle.dashed")
                Text("待确认")
            case "failed":
                Image(systemName: "xmark")
                Text("处理失败")
                WebTextButton("重试", font: Web.captionMedium) { model.retry(note: note.id) }
            default:
                Image(systemName: "circle")
                Text("已保存 · 待处理")
            }
        }
        .font(Web.caption)
        .foregroundStyle(note.status == "failed" ? Web.danger : Web.fgTertiary)
    }
}
