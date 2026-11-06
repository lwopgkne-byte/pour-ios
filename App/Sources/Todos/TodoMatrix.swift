import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 四象限（待办 2.0 第 7 步，docs/todo-2.0 design/after-03-matrix）：2×2 等高四格（左上马上做、右上排时间、左下快速办、
/// 右下放一放），每格最多 4 张小卡（过点的在前，再按时间），多了「还有 N 件」，点格头进这一格的全部；按住卡片拖到别的格子
/// 就换一格（松手轻震，不再是猜的）。排时间下面「排进空档 ›」去时间线；格子下面「还没分 · N」托盘（拖进格子或点一下选）。
/// 马上做多于 3 件：格头「5 · 有点多」，问要不要只留 3 件；排时间里到了日子没定时间的卡片上写「今天到期」（不再问要不要升到
/// 马上做——产品主人 2026-11-06：太突兀；想升就拖过去或按住选一格）。范围：今天的、过点了的、没定日子的；日程不进来
struct TodoMatrixSection: View {
    @Environment(AppModel.self) private var model
    let page: API.TodoPage
    let now: String
    @Binding var mode: TodosPage.Mode
    @Binding var focus: TodoQuadrant?
    /// 拖着卡片停在哪一格上
    @State private var target: TodoQuadrant?
    /// 放下一次轻震一下
    @State private var dropped = 0
    /// 「马上做」多了点过「先不用」的那一天（那天不再问）
    @AppStorage("todos.crowdSkipped") private var crowdSkipped = ""

    var body: some View {
        let plan = TodoMatrixPlan.make(page: page, held: model.todoHeld, now: now)
        VStack(spacing: Theme.Space.medium) {
            Grid(horizontalSpacing: Theme.Space.medium, verticalSpacing: Theme.Space.medium) {
                GridRow {
                    cell(.doNow, plan)
                    cell(.schedule, plan)
                }
                GridRow {
                    cell(.quick, plan)
                    cell(.later, plan)
                }
            }
            if !plan.unsorted.isEmpty { tray(plan.unsorted) }
        }
        .sensoryFeedback(Theme.Haptics.drop, trigger: dropped)
    }

    // MARK: - 一格

    private func cell(_ lane: TodoQuadrant, _ plan: TodoMatrixPlan) -> some View {
        let rows = plan.cells[lane] ?? []
        let open = plan.open(lane).count
        let crowded = lane == .doNow && open > TodoMatrixPlan.crowd
        return MatrixCell(
            quadrant: lane.rawValue, title: lane.title, subtitle: lane.subtitle, count: open, crowded: crowded,
            targeted: target == lane
        ) {
            withAnimation(Theme.Motion.standard) { focus = lane }
        } content: {
            if crowded && crowdSkipped != page.today { crowdAsk(plan) }
            if rows.isEmpty {
                Text(Self.empty(lane)).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.choiceBlock * 2)
            }
            ForEach(rows.prefix(TodoMatrixPlan.shown)) { row in
                card(row, due: plan.dueToday.contains { $0.id == row.id })
            }
            if rows.count > TodoMatrixPlan.shown {
                ThemeTextButton("还有 \(rows.count - TodoMatrixPlan.shown) 件") {
                    withAnimation(Theme.Motion.standard) { focus = lane }
                }
            }
            if lane == .schedule && !rows.isEmpty {
                Button {
                    model.todoGaps = true
                    withAnimation(Theme.Motion.standard) { mode = .timeline }
                } label: {
                    Label("排进空档", systemImage: "chevron.right").labelStyle(TrailingIcon())
                        .font(Theme.Typeface.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Quadrant.text(lane.rawValue))
                        .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("matrix.gaps")
            }
        }
        .frame(minHeight: Theme.Size.choiceBlock * 3, alignment: .top)
        // 两格各占一半宽，里面的字再长也不把格子撑宽（2026-11-06：「09:53 · 3 分钟后」把整页撑出了屏幕）
        .containerRelativeFrame(.horizontal) { length, _ in
            max(0, (length - Theme.Space.regular * 2 - Theme.Space.medium) / 2)
        }
        .dropDestination(for: String.self) { items, _ in
            drop(items, into: lane)
        } isTargeted: { over in
            if over { target = lane } else if target == lane { target = nil }
        }
        // 一格是一组（里面的卡片、按钮各有各的名字；不包一层的话这个编号会盖到每一个上）
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("matrix.cell.\(lane.rawValue)")
    }

    /// 空着的一格说一句（快速办、放一放、马上做；排时间空着就空着）
    static func empty(_ lane: TodoQuadrant) -> String {
        switch lane {
        case .doNow: "没有火烧眉毛的事"
        case .quick: "没有杂事来打扰"
        case .later: "空着正好"
        default: "重要不急的放这里"
        }
    }

    /// 格里的一张小卡：圈点了勾掉，别的地方点了打开编辑，按住拖到别的格子
    private func card(_ row: API.TodoRow, due: Bool) -> some View {
        let when = TodoBoard.trailing(row, today: page.today, now: now) ?? (row.isSomeday ? .day("以后再说") : nil)
        return MatrixCard(
            Show.spaced(row.content), done: row.done, when: when, note: due ? "今天到期" : nil,
            spoken: [row.content, row.done ? "已完成" : nil, due ? "今天到期" : when?.text].compactMap { $0 }
                .joined(separator: "，")
        ) {
            model.todoSheet = .detail(row)
        } ring: {
            QuadrantRing(quadrant: row.lane.rawValue, done: row.done, label: row.content) {
                model.setDone(row.id, !row.done)
            }
        }
        .draggable(TodoMatrixPlan.dragText(row)) {
            TrayChip(Show.spaced(row.content))
        }
    }

    // MARK: - 问一句

    /// 马上做多了：只留 3 件最要紧的（排在最前的），别的挪到排时间？
    private func crowdAsk(_ plan: TodoMatrixPlan) -> some View {
        MatrixAsk("挑 3 件最要紧的，其余的挪到「排时间」？", yes: "好", later: "先不用") {
            model.file(plan.overflow(), into: .schedule)
        } skip: {
            withAnimation(Theme.Motion.standard) { crowdSkipped = page.today }
        }
    }

    // MARK: - 还没分

    /// 「还没分 · 1」：一件一个胶囊，点了选一格，按住拖进格子。放得下一行就一行（设计稿），放不下胶囊另起一行横着滑
    private func tray(_ rows: [API.TodoRow]) -> some View {
        let title = Text("还没分 · \(rows.count)").font(Theme.Typeface.footnoteSemibold)
            .foregroundStyle(Theme.Palette.secondaryLabel)
        let hint = Label("拖进格子", systemImage: "hand.draw").font(Theme.Typeface.footnote)
            .foregroundStyle(Theme.Palette.secondaryLabel)
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Space.small) {
                title
                trayChips(rows)
                Spacer(minLength: Theme.Space.small)
                hint
            }
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                HStack {
                    title
                    Spacer()
                    hint
                }
                ScrollView(.horizontal, showsIndicators: false) { trayChips(rows) }
            }
        }
        .padding(.horizontal, Theme.Space.regular)
        .padding(.vertical, Theme.Space.small)
        .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.smallCard))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("matrix.tray")
    }

    private func trayChips(_ rows: [API.TodoRow]) -> some View {
        HStack(spacing: Theme.Space.small) {
            ForEach(rows) { row in
                Menu {
                    ForEach(TodoQuadrant.sorted, id: \.self) { lane in
                        Button("放进\(lane.title)", systemImage: lane.symbol ?? "circle") {
                            model.file([row], into: lane)
                        }
                    }
                    Button("编辑…", systemImage: "pencil") { model.todoSheet = .detail(row) }
                } label: {
                    TrayChip(Show.spaced(row.content))
                }
                .draggable(TodoMatrixPlan.dragText(row)) { TrayChip(Show.spaced(row.content)) }
                .accessibilityIdentifier("matrix.tray.chip")
            }
        }
        .padding(.vertical, Theme.Space.tight)
    }

    // MARK: - 放下

    /// 放进这一格：你选的就不再是猜的；松手轻震
    private func drop(_ items: [String], into lane: TodoQuadrant) -> Bool {
        target = nil
        let ids = Set(items.compactMap(TodoMatrixPlan.dragId))
        let rows = page.groups.flatMap(\.rows).filter { ids.contains($0.id) && $0.lane != lane }
        guard !rows.isEmpty else { return false }
        model.file(rows, into: lane)
        dropped += 1
        return true
    }
}

/// 格里问的一句：一行字 + 「好」「先不用」
private struct MatrixAsk: View {
    let text: String
    let yes: String
    let later: String
    let accept: () -> Void
    let skip: () -> Void

    init(_ text: String, yes: String, later: String, accept: @escaping () -> Void, skip: @escaping () -> Void) {
        self.text = text
        self.yes = yes
        self.later = later
        self.accept = accept
        self.skip = skip
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            Text(text).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.label)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Theme.Space.small) {
                MiniChip(yes, action: accept)
                MiniChip(later, action: skip)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// 字在前、图标在后（「排进空档 ›」）
private struct TrailingIcon: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Theme.Space.tight) {
            configuration.title
            configuration.icon.font(Theme.Typeface.footnoteSemibold)
        }
    }
}
