import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 调整顺序（待办 2.0，产品主人 2026-11-06：待办和清单没法调顺序）：右上角「···」或者按住一行的菜单里「调整顺序」，
/// 每一组只放还没做完的待办、右边一个拖动的把手（系统的编辑状态），上下拖、松手马上存；同一天的才能互相排
/// （「这周」「以后」按天分开）；日程、过点了的、做完的不在这里（日程照时间、过点了的照时间排在最前）
extension TodosPage {
    func startReorder() {
        mode = .list
        focus = nil
        withAnimation(Theme.Motion.standard) { reordering = true }
    }

    /// 按住的菜单点了「调整顺序」：进来就是调整顺序
    func startReorderIfAsked() {
        guard model.todoReorder else { return }
        model.todoReorder = false
        startReorder()
    }

    @ViewBuilder func reorderSections(_ page: API.TodoPage) -> some View {
        let plan = TodoListPlan.make(page: page, held: [:], events: [], now: now)
        let today = plan.today.compactMap { item -> API.TodoRow? in
            if case .todo(let row) = item, !row.done { row } else { nil }
        }
        let later = plan.later.filter { !$0.done }
        Section {
            Text("按住右边的把手上下拖，排好了点「完成」。日程照时间插在中间，过点了的照旧在最前")
                .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
                .listRowBackground(Color.clear)
                .listRowInsets(
                    EdgeInsets(top: 0, leading: Theme.Space.regular, bottom: 0, trailing: Theme.Space.regular))
        }
        // 今天：放一放的折在后面，一起存（编号连着，放一放的排在后面）
        reorderSection(CanvasTopBar.withAllDay(Self.todayTitle(page), events: []), rows: today) { ids in
            model.reorderTodos(ids + later.map(\.id))
        }
        if !later.isEmpty {
            reorderSection("今天 · 放一放", rows: later) { ids in model.reorderTodos(today.map(\.id) + ids) }
        }
        ForEach(Self.days(plan.ahead, today: page.today), id: \.title) { day in
            reorderSection(day.title, rows: day.rows) { ids in model.reorderTodos(ids) }
        }
    }

    /// 一组能拖的：一行和清单里一样的样子（圈、名字、右边的时间），不能点、不能滑
    @ViewBuilder private func reorderSection(_ title: String, rows: [API.TodoRow], save: @escaping ([Int]) -> Void)
        -> some View
    {
        if !rows.isEmpty {
            Section {
                ForEach(rows) { row in
                    TodoLine(Show.spaced(row.content), done: false, dim: row.lane == .later) {
                        QuadrantBadge(quadrant: row.lane.rawValue)
                            .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                    } trailing: {
                        if let trailing = TodoBoard.trailing(row, today: model.todoPage?.today ?? model.today, now: now)
                        {
                            TodoTrailing(trailing, compact: true, alarm: row.rings)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("todos.reorder.row")
                }
                .onMove { from, to in
                    var ids = rows.map(\.id)
                    ids.move(fromOffsets: from, toOffset: to)
                    save(ids)
                }
            } header: {
                Text(title).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                    .textCase(nil).padding(.horizontal, -Theme.Space.tight)
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }

    private static func todayTitle(_ page: API.TodoPage) -> String {
        page.groups.first { $0.key == "today" }?.title ?? "今天"
    }

    /// 明天、这周、以后按天分开（同一天的才能互相排）；以后再说的一组
    static func days(_ groups: [API.TodoGroup], today: String) -> [(title: String, rows: [API.TodoRow])] {
        let rows = groups.flatMap(\.rows).filter { !$0.done }
        let dated = Dictionary(grouping: rows.filter { !$0.isSomeday }, by: \.day).sorted { $0.key < $1.key }
        let tomorrow = PourDate.addDays(today, 1)
        var out: [(title: String, rows: [API.TodoRow])] = dated.map { day, rows in
            (day == tomorrow ? "明天 · \(Show.dayTitle(day, today: today))" : Show.dayTitle(day, today: today), rows)
        }
        let someday = rows.filter(\.isSomeday)
        if !someday.isEmpty { out.append(("以后再说", someday)) }
        return out
    }
}
