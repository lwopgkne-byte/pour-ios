import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 待办页的另几块：四象限里点开的一格、已完成、按人、右上角
extension TodosPage {
    /// 四象限里点了格头（或「还有 N 件」）：这一格的全部，和清单一样的行（左右滑、按住出菜单）；「‹ 四格」回去
    @ViewBuilder func focusSections(_ page: API.TodoPage, _ lane: TodoQuadrant) -> some View {
        let plan = TodoMatrixPlan.make(page: page, held: model.todoHeld, now: now)
        let rows = plan.cells[lane] ?? []
        Section {
            if rows.isEmpty {
                Text(TodoMatrixSection.empty(lane)).font(Theme.Typeface.subheadline)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.choiceBlock)
            }
            ForEach(rows) { todoRow($0, group: "matrix", today: page.today) }
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Button {
                    withAnimation(Theme.Motion.standard) { focus = nil }
                } label: {
                    Label("四格", systemImage: "chevron.left").font(Theme.Typeface.subheadline.weight(.semibold))
                        .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Palette.accent)
                .accessibilityIdentifier("matrix.back")
                Spacer()
                Text("\(lane.title) · \(plan.open(lane).count) 件").font(Theme.Typeface.bodySemibold)
                    .foregroundStyle(Theme.Quadrant.text(lane.rawValue))
                    .accessibilityAddTraits(.isHeader)
            }
            .textCase(nil)
            .padding(.horizontal, -Theme.Space.tight)
        }
    }

    /// 已完成：平时不出（勾掉的在原地划线，底下再写一行「已完成 8 件」多余，产品主人 2026-11-06）；
    /// 「···」里「显示已完成」打开才有这一组，标题旁「收起」
    func doneSection(_ group: API.TodoGroup) -> some View {
        Section {
            ForEach(group.rows) { todoRow($0, group: "done", today: model.todoPage?.today ?? model.today) }
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text("已完成 · \(group.rows.count) 件").font(Theme.Typeface.bodySemibold)
                    .foregroundStyle(Theme.Palette.label)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                ThemeTextButton("收起", font: Theme.Typeface.subheadline) {
                    withAnimation(Theme.Motion.standard) { showDone = false }
                }
                .accessibilityIdentifier("todos.done")
            }
            .textCase(nil)
            .padding(.horizontal, -Theme.Space.tight)
        }
    }

    // MARK: - 按人（「···」里换）：没做完的按和谁分，没写和谁的放最后

    @ViewBuilder
    func personSections(_ sections: [API.TodoGroup]) -> some View {
        let open = sections.filter { $0.key != "done" }.flatMap(\.rows)
        let names = Array(Set(open.flatMap(\.people))).sorted()
        let today = model.todoPage?.today ?? model.today
        ForEach(names, id: \.self) { name in
            Section {
                ForEach(open.filter { $0.people.contains(name) }) { todoRow($0, group: "person", today: today) }
            } header: {
                Text(name).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label).textCase(nil)
            }
        }
        let alone = open.filter(\.people.isEmpty)
        if !alone.isEmpty {
            Section {
                ForEach(alone) { todoRow($0, group: "person", today: today) }
            } header: {
                Text("没写和谁").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label).textCase(nil)
            }
        }
    }

    // MARK: - 右上角：加待办、更多

    @ToolbarContentBuilder var toolbar: some ToolbarContent {
        if reordering {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") { withAnimation(Theme.Motion.standard) { reordering = false } }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("todos.reorder.done")
            }
        } else {
            standardToolbar
        }
    }

    @ToolbarContentBuilder private var standardToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("调整顺序", systemImage: "arrow.up.arrow.down") { startReorder() }
                    .accessibilityIdentifier("todos.reorder")
                // 作息：几点睡、几点上班（时间线上的底色）
                Button("作息…", systemImage: "moon.zzz") { model.timeline.editing = true }
                    .accessibilityIdentifier("todos.routine")
                Toggle("显示已完成", isOn: $showDone)
                Picker("怎么排", selection: $byPerson) {
                    Text("按时间").tag(false)
                    Text("按人").tag(true)
                }
            } label: {
                Image(systemName: "ellipsis").font(Theme.Typeface.toolbarIcon)
            }
            .accessibilityLabel(Text("更多"))
            .accessibilityIdentifier("todos.more")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                model.todoSheet = .add("")
            } label: {
                Image(systemName: Theme.Symbol.add).font(Theme.Typeface.toolbarIcon)
            }
            .accessibilityLabel(Text("加待办"))
            .accessibilityIdentifier("todos.add")
        }
    }
}

extension TodosPage {
    /// 提醒响不了的时候说一句（提醒是红线）：通知关着；有响铃的待办、闹钟却没打开（只能发一条通知，静音、睡眠模式下叫不醒）
    @ViewBuilder var reminderWarnings: some View {
        if model.reminderState?.permission == .denied {
            warning("通知关着：定了时间的待办到点不会响。点这里去设置，在「通知」里打开", symbol: "bell.slash")
                .accessibilityIdentifier("todos.reminders")
        }
        if model.reminderState?.alarmsOff == true {
            warning("闹钟没打开：响铃的待办到点只发一条通知，静音时叫不醒你。点这里去设置，打开「闹钟」", symbol: "alarm")
                .accessibilityIdentifier("todos.alarms")
        }
    }

    /// 一行沙色的提示，点了直接打开 Pour 在「设置」里的那一页（通知、闹钟的开关都在那）
    private func warning(_ text: String, symbol: String) -> some View {
        Section {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            } label: {
                Label(text, systemImage: symbol).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.warn)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
        }
    }
}
