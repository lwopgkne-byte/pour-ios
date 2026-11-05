import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 一件待办的编辑弹框（待办 2.0 第 5 步，docs/todo-2.0 design/after-06-edit）：名字（直接改）、原话一行、
/// 放进哪一格（2×2，AI 猜的写「AI 猜的，点别的就改」）、日期（今天 · 明天 · 周六 · 下周一 · 选日子，以后再说在选日子里）、
/// 时间（不定时 · 上午 · 下午 · 晚上 · 🔔几点，选了钟点「几点」原地变成「12:30」）、重复（收起一行，点开再选）、
/// 「保存」，下面「标记完成」「删除」。改的都先放在弹框里，点「保存」才一起改（不叫「完成」：和勾掉混）；
/// 点 × 有没存的改动先问一句，往下拉也拦住
struct TodoDetailSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let row: API.TodoRow
    @State private var draft: TodoDraft
    @State private var pickingDay = false
    @State private var pickingTime = false
    @State private var showRepeat = false
    @State private var leaving = false

    init(row: API.TodoRow) {
        self.row = row
        _draft = State(initialValue: TodoDraft(row))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.medium) {
                header
                TodoEditCards(
                    draft: $draft, row: row, today: model.today, pickingDay: $pickingDay, pickingTime: $pickingTime)
                repeatCard
                actions
            }
            .padding(.horizontal, Theme.Space.regular)
            .padding(.top, Theme.Space.large)
            .padding(.bottom, Theme.Space.xLarge)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.Palette.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(dirty)
        .confirmationDialog("不保存这次的改动？", isPresented: $leaving, titleVisibility: .visible) {
            Button("不保存", role: .destructive) { dismiss() }
            Button("保存") { save() }
            Button("继续改", role: .cancel) {}
        }
    }

    private var dirty: Bool { draft != TodoDraft(row) }

    // MARK: - 名字、原话

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            HStack(alignment: .top, spacing: Theme.Space.small) {
                TextField("要做的事", text: $draft.title, axis: .vertical)
                    .font(Theme.Typeface.editTitle).lineLimit(1...3)
                    .submitLabel(.done)
                    .accessibilityIdentifier("todoDetail.title")
                SheetCloseButton {
                    if dirty { leaving = true } else { dismiss() }
                }
            }
            if let source = row.source {
                Button {
                    dismiss()
                    model.openLink("/library?note=\(source.noteId)")
                } label: {
                    Label {
                        Text("原话「\(Show.spaced(source.text))」").lineLimit(2)
                    } icon: {
                        Image(systemName: "quote.closing")
                    }
                    .font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("在笔记库里看这段原话"))
            }
        }
    }

    // MARK: - 重复（收起一行，点开再选）

    private var repeatCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(Theme.Motion.standard) { showRepeat.toggle() }
            } label: {
                HStack {
                    Label("重复", systemImage: Theme.Symbol.repeats).font(Theme.Typeface.bodySemibold)
                        .foregroundStyle(Theme.Palette.label)
                    Spacer()
                    Text(draft.rule?.text ?? "不重复").font(Theme.Typeface.subheadline)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                    Image(systemName: "chevron.right").font(Theme.Typeface.footnoteSemibold)
                        .foregroundStyle(Theme.Palette.tertiaryLabel)
                        .rotationEffect(.degrees(showRepeat ? 90 : 0))
                }
                .frame(minHeight: Theme.Size.touch + Theme.Space.small)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("todoDetail.repeat")
            if showRepeat {
                TodoRepeatPicker(rule: $draft.rule, day: draft.day ?? row.day)
                    .padding(.bottom, Theme.Space.medium)
            }
        }
        .padding(.horizontal, Theme.Space.regular)
        .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.smallCard))
    }

    // MARK: - 保存、标记完成、删除

    private var actions: some View {
        VStack(spacing: Theme.Space.small) {
            Button(action: save) {
                Text("保存").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.onAccent)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.composer - Theme.Space.tight)
                    .background(Theme.Palette.accentFill, in: Theme.rounded(Theme.Corner.stat))
            }
            .buttonStyle(PressScale())
            .accessibilityIdentifier("todoDetail.save")
            HStack(spacing: 0) {
                Button {
                    model.setDone(row.id, !row.done)
                    dismiss()
                } label: {
                    Label(row.done ? "改成没完成" : "标记完成", systemImage: Theme.Symbol.done)
                        .font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.touch).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("todoDetail.done")
                Button {
                    model.deleteTodo(row)
                } label: {
                    Label("删除", systemImage: Theme.Symbol.delete)
                        .font(Theme.Typeface.body).foregroundStyle(Theme.Palette.bad)
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.touch).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("todoDetail.delete")
            }
        }
        .padding(.top, Theme.Space.small)
    }

    /// 保存：只发改了的那几样，一次改完（先改界面再发，没网排队）
    private func save() {
        let change = draft.change(from: row)
        if change.any {
            model.editTodo(
                row.id, content: change.content, day: change.day, time: change.time, repeat: change.rule,
                quadrant: change.quadrant, window: change.window, someday: change.someday)
        }
        dismiss()
    }
}

/// 编辑弹框里改的那一份（点「保存」才发）
struct TodoDraft: Equatable {
    var title: String
    var quadrant: TodoQuadrant
    /// nil：以后再说
    var day: String?
    var time: String?
    var window: TimeWindow?
    var rule: API.Repeat?

    init(_ row: API.TodoRow) {
        title = row.content
        quadrant = row.lane
        day = row.isSomeday ? nil : row.day
        time = row.remindAt
        window = row.timeWindow
        rule = row.repeat
    }

    struct Change {
        var content: String?
        var day: String?
        var time: String??
        var rule: API.Repeat??
        var quadrant: TodoQuadrant?
        var window: TimeWindow??
        var someday: Bool?

        var any: Bool {
            content != nil || day != nil || time != nil || rule != nil || quadrant != nil || window != nil
                || someday != nil
        }
    }

    /// 和原来比，改了哪几样（以后再说没有日子、钟点、时间段）
    func change(from row: API.TodoRow) -> Change {
        var out = Change()
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != row.content { out.content = trimmed }
        if quadrant != row.lane { out.quadrant = quadrant }
        if rule != row.repeat { out.rule = .some(rule) }
        guard let day else {
            if !row.isSomeday { out.someday = true }
            return out
        }
        if day != row.day || row.isSomeday { out.day = day }
        if time != row.remindAt || window != row.timeWindow {
            out.time = .some(time)
            out.window = .some(time == nil ? window : nil)
        }
        return out
    }
}
