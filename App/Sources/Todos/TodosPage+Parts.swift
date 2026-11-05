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

    /// 已完成：默认收起，一行「已完成 5 件 ›」，点了展开
    func doneSection(_ group: API.TodoGroup) -> some View {
        Section {
            Button {
                withAnimation(Theme.Motion.standard) { showDone.toggle() }
            } label: {
                HStack {
                    Text(showDone ? "收起已完成" : "已完成 \(group.rows.count) 件")
                        .font(Theme.Typeface.bodyMedium).foregroundStyle(Theme.Palette.accent)
                    Spacer()
                    Image(systemName: "chevron.right").font(Theme.Typeface.glyph)
                        .foregroundStyle(Theme.Palette.tertiaryLabel)
                        .rotationEffect(.degrees(showDone ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("todos.done")
            if showDone {
                ForEach(group.rows) { todoRow($0, group: "done", today: model.todoPage?.today ?? model.today) }
            }
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
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
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
