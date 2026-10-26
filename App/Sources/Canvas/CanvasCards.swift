import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 卡片：按 `CanvasPlan` 排好的行画出来——整行一张，或者两张半宽一样高
struct CanvasCards: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let day: API.DayView
    let rows: [CanvasPlan.Row]

    var body: some View {
        VStack(spacing: Theme.Space.cardGap) {
            ForEach(rows) { row in
                CanvasRow(row: row, day: day)
                    .themeTransition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .animation(Theme.Motion.pick(Theme.Motion.emphasized, reduceMotion: reduceMotion), value: rows.map(\.id))
    }
}

/// 一行：一张整行，或者两张半宽一样高
private struct CanvasRow: View {
    let row: CanvasPlan.Row
    let day: API.DayView

    var body: some View {
        switch row {
        case .full(let card):
            CanvasCard(card: card, day: day, size: .full)
        case .pair(let left, let right):
            // 读屏一张念完再念另一张（不分组时两张卡是一行一行交错着念的）
            HStack(alignment: .top, spacing: Theme.Space.cardGap) {
                CanvasCard(card: left, day: day, size: .half).frame(maxHeight: .infinity, alignment: .top)
                    .accessibilityElement(children: .contain)
                CanvasCard(card: right, day: day, size: .half).frame(maxHeight: .infinity, alignment: .top)
                    .accessibilityElement(children: .contain)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// 一张卡：标题（图标小方块、名称、右边一个小数）、按样子画的内容、底部相关目标
struct CanvasCard: View {
    @Environment(AppModel.self) private var model
    let card: CanvasPlan.Card
    let day: API.DayView
    let size: CanvasPlan.Size

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            CardHeader(card: card)
            // 健康 App 的步数写在运动卡上（docs/模块/产品优化.md R5）：只有步数时写大字
            if card.id == CanvasPlan.exerciseKey, let steps = day.health?.steps {
                StepsLine(steps: steps, alone: card.entries.isEmpty)
            }
            if card.withBody { BodyBlock(entries: card.entries.filter(Self.isBody), day: day.day) }
            content
            ForEach(goals) { goal in GoalFooter(goal: goal, compact: size == .half) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .themeCard(padding: size == .half ? Theme.Space.inset : Theme.Space.regular)
        .id(card.id)
    }

    @ViewBuilder private var content: some View {
        let entries = card.withBody ? card.entries.filter { !Self.isBody($0) } : card.entries
        switch card.template {
        case .duration: DurationBody(entries: entries, day: day.day, size: size)
        case .count: CountBody(entries: entries, day: day.day, size: size)
        case .quantity: QuantityBody(card: card, day: day, size: size)
        case .general: GeneralBody(entries: entries, day: day.day, size: size)
        case .body: BodyBlock(entries: entries, day: day.day)
        case .sleep: SleepBody(entries: entries, day: day.day, size: size)
        case .diet: DietBody(entries: entries, day: day.day, size: size)
        case .money: MoneyBody(entries: entries, day: day.day)
        case .mood: MoodBody(entries: entries, quotes: quotes)
        case .insight: InsightBody(entries: entries)
        case .todo: TodoBody(entries: entries, events: model.calendar.items[day.day] ?? [])
        case .mentions: MentionsBody(entries: day.entries, history: day.mentions)
        }
    }

    /// 和这张卡同一类的目标（钱的汇总卡、待办、感悟、心情、说到的没有）
    private var goals: [API.DayGoal] {
        guard ![.money, .todo, .insight, .mood, .mentions].contains(card.template) else { return [] }
        return day.goals.filter { goal in goal.category.map { Show.root($0, model.categories) } == card.id }
    }

    /// 当天感悟的摘录：心情的那一刻已经整句在里面，就不再写一遍
    private var quotes: [String] {
        day.entries.compactMap { if case .insight(let insight) = $0.data { insight.quote } else { nil } }
    }

    static func isBody(_ entry: API.Entry) -> Bool {
        CanvasPlan.event(entry).map(CanvasPlan.hasBody) ?? false
    }
}

/// 卡片标题：图标小方块 + 类别名 + 右边一个小数（「还有 1 件」「14 次」「4 笔」「AI 推测」）
private struct CardHeader: View {
    @Environment(AppModel.self) private var model
    let card: CanvasPlan.Card

    var body: some View {
        let meta = CanvasPlan.meta(card.id, model.categories)
        HStack(spacing: Theme.Space.small) {
            CategoryIcon.tile(card.id, model.categories)
            Text(Show.spaced(meta.name)).font(Theme.Typeface.cardTitle).foregroundStyle(Theme.Palette.label)
            Spacer(minLength: Theme.Space.tight)
            side
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// 标题右边：心情卡写「AI 推测」，别的写一个小数
    @ViewBuilder private var side: some View {
        if card.template == .mood {
            Label("AI 推测", systemImage: "sparkles").font(Theme.Typeface.caption)
                .foregroundStyle(Theme.Palette.secondaryLabel)
        } else if let trailing {
            Text(trailing).font(Theme.Typeface.footnoteMedium).foregroundStyle(Theme.Palette.secondaryLabel)
        }
    }

    /// 标题右边的小数
    private var trailing: String? {
        let count = card.entries.count
        switch card.template {
        case .todo:
            // 只有日历里的日程、没有待办时不写（docs/模块/产品优化.md R6）
            guard count > 0 else { return nil }
            let left = card.entries.filter { if case .todo(let todo) = $0.data { !todo.done } else { false } }.count
            return left > 0 ? "还有 \(left) 件" : "都做完了"
        case .money: return "\(count) 笔"
        case .insight: return count > 1 ? "\(count) 条" : nil
        case .count: return count > 1 ? "\(count) 次" : nil
        case .duration, .general, .quantity: return count > 2 ? "\(count) 件" : nil
        default: return nil
        }
    }
}

/// 一行记录：点一下看详情，长按出「修改 / 查看来源 / 删除」；待确认的下面一行追问 +「对」「改一下」
struct CardRow<Content: View>: View {
    @Environment(AppModel.self) private var model
    let entry: API.Entry
    /// 追问和上一行一样：问的话不再写一遍，只在这一行末尾放一个「对」
    var quiet = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            HStack(spacing: Theme.Space.small) {
                content().frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { model.detail = .init(id: entry.id) }
                    .contextMenu {
                        // 健康 App 记的只能看（改、删在健康 App 里）
                        if entry.fromHealthApp {
                            Button("查看", systemImage: "heart.text.square") { model.detail = .init(id: entry.id) }
                        } else {
                            Button("修改", systemImage: "pencil") { model.detail = .init(id: entry.id) }
                            Button("查看来源", systemImage: "text.quote") { model.detail = .init(id: entry.id) }
                            Button("删除", systemImage: "trash", role: .destructive) { model.delete(entry.id) }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                if entry.pending, quiet {
                    Button("对") { model.confirm(entry.id) }
                        .font(Theme.Typeface.footnoteSemibold).buttonStyle(.bordered).buttonBorderShape(.capsule)
                        .tint(Theme.Palette.accent)
                        .accessibilityHint(Text(entry.question ?? "我理解得对吗？"))
                }
            }
            .frame(minHeight: Theme.Size.touch)
            if entry.pending, !quiet { ConfirmBox(entry: entry) }
        }
    }
}

/// 拿不准的：一句追问 +「对」「改一下」（「改一下」打开详情）
private struct ConfirmBox: View {
    @Environment(AppModel.self) private var model
    let entry: API.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text(Show.spaced(entry.question ?? "我理解得对吗？")).font(Theme.Typeface.subheadline)
                .foregroundStyle(Theme.Palette.label)
            HStack(spacing: Theme.Space.small) {
                Button("对") { model.confirm(entry.id) }.buttonStyle(.borderedProminent)
                    .tint(Theme.Palette.accentFill)
                Button("改一下") { model.detail = .init(id: entry.id) }.buttonStyle(.bordered)
                    .tint(Theme.Palette.accent)
            }
            .font(Theme.Typeface.footnoteSemibold).buttonBorderShape(.capsule)
        }
        .padding(Theme.Space.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.bubble, in: Theme.rounded(Theme.Corner.chip))
    }
}

/// 先列 3 条，多的收在「看全部 N 条」里，原地展开
struct ShowFirst<Item: Identifiable, Row: View>: View {
    let items: [Item]
    var first = 3
    @ViewBuilder let row: (Item, Int) -> Row
    @State private var all = false

    var body: some View {
        let shown = all ? items : Array(items.prefix(first))
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Divider().overlay(Theme.Palette.separator) }
                row(item, index)
            }
            if !all && items.count > first {
                Button("看全部 \(items.count) 条") { withAnimation(Theme.Motion.standard) { all = true } }
                    .font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.accent)
                    .buttonStyle(.plain).frame(minHeight: Theme.Size.touch)
            }
        }
    }
}

/// 这一行的追问和上一行完全一样吗：一样的话只在第一行写一次
func repeatsQuestion(_ items: [API.Entry], _ index: Int) -> Bool {
    guard index > 0, index < items.count, items[index].pending, items[index - 1].pending else { return false }
    return (items[index].question ?? "我理解得对吗？") == (items[index - 1].question ?? "我理解得对吗？")
}
