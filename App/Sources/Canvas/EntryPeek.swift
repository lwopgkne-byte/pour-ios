import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 记录详情：从底部滑出的半屏，照原型 RecordSheet：上面一行类别的彩色小方块和类别名、右上角灰圆的关闭，下面大字的名称。
/// 拿不准的先问一句、能确认；所有字段原地修改（交给服务器改）；最近 7 天；相关目标；来源原话（对应的那一段标黄）；删除
struct EntryPeek: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let entryId: Int
    /// 记录是哪一天的；nil 是画布正在看的那一天（回顾里打开别的日子的记录时，详情自己去拿那一天）
    var day: String?
    @State private var otherDay: API.DayView?

    @State private var trend: API.Trend?

    /// 详情里显示的总是最新的数据：原地修改后跟着刷新
    private var source: API.DayView? { day == nil ? model.day : otherDay }
    private var entry: API.Entry? { source?.entries.first { $0.id == entryId } }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                if let entry, entry.fromHealthApp {
                    // 健康 App 记的：只能看（docs/模块/产品优化.md R5）
                    HealthPeek(entry: entry).padding(.horizontal, Theme.Space.regular).padding(
                        .bottom, Theme.Space.xLarge)
                } else if let entry {
                    VStack(alignment: .leading, spacing: Theme.Space.xLarge) {
                        if entry.pending { confirmCard(entry) }
                        PeekFields(entry: entry)
                        if let filled = entry.fromHealth, !filled.isEmpty {
                            Text(Show.spaced("\(filled.joined(separator: "、"))是健康 App 补上的（你没说）。改了就用你改的。"))
                                .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                        }
                        if let trend, trend.points.contains(where: { $0.value != nil }) {
                            PeekSection(title: "最近 7 天") {
                                Sparkline(trend: trend, color: color(entry), today: entry.day)
                            }
                        }
                        relatedGoals(entry)
                        if !entry.sources.isEmpty { sources(entry) }
                        Button("删除这条记录") {
                            dismiss()
                            model.delete(entry.id)
                        }
                        .font(Theme.Typeface.bodyMedium).foregroundStyle(Theme.Palette.bad).buttonStyle(.plain)
                        .frame(minHeight: Theme.Size.touch)
                        .accessibilityIdentifier("detail.delete")
                    }
                    .padding(.horizontal, Theme.Space.regular)
                    .padding(.bottom, Theme.Space.xLarge)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Theme.Palette.card)
        .presentationDetents([.fraction(0.6), .large])
        .presentationCornerRadius(Theme.Corner.chip)
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.light)
        .tint(Theme.Palette.accent)
        // 健康 App 记的编号是负数，服务器上没有这条：不去拿最近 7 天
        .task { if entryId > 0 { trend = try? await model.client.trend(of: entryId) } }
        .task(id: "\(day ?? "")-\(model.dataVersion)") {
            if let day { otherDay = try? await model.client.day(day) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            HStack(spacing: Theme.Space.small) {
                if let entry {
                    let meta = Show.meta(entry.category, model.categories)
                    IconTile(
                        symbol: CategoryIcon.symbol(key: entry.category, name: meta.name), emoji: meta.emoji,
                        color: Theme.tag(meta.color))
                    Text(meta.name).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
                }
                Spacer(minLength: 0)
                SheetCloseButton { dismiss() }
            }
            Text(Show.spaced(title)).font(Theme.Typeface.recordTitle).foregroundStyle(Theme.Palette.label)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, Theme.Space.regular)
        .padding(.top, Theme.Space.medium).padding(.bottom, Theme.Space.small)
    }

    /// 大字的名称（心情就是「心情」）；类别在上面一行，不再写 emoji
    private var title: String {
        guard let entry else { return "" }
        switch entry.data {
        case .event(let event): return event.label
        case .todo(let todo): return todo.content
        case .insight(let insight): return insight.title
        case .mood: return "心情"
        }
    }

    private func confirmCard(_ entry: API.Entry) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            Text(Show.spaced(entry.question ?? "我理解得对吗？")).font(Theme.Typeface.body).foregroundStyle(
                Theme.Palette.label)
            HStack(spacing: Theme.Space.medium) {
                Button {
                    model.confirm(entry.id)
                } label: {
                    Text("确认").font(Theme.Typeface.bodyMedium).foregroundStyle(Theme.Palette.onAccent)
                        .padding(.horizontal, Theme.Space.regular)
                        .frame(minHeight: Theme.Size.touch)
                        .background(RoundedRectangle(cornerRadius: Theme.Corner.tile).fill(Theme.Palette.accent))
                }
                .buttonStyle(.plain)
                Text("不对的话，直接改下面的内容，或者在对话里说").font(Theme.Typeface.footnote).foregroundStyle(
                    Theme.Palette.secondaryLabel)
            }
        }
        .padding(Theme.Space.regular)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.Corner.tile).fill(Theme.Palette.fill))
    }

    /// 相关目标的完整进度：圆点、目标、推进了多少、细进度条、进度说明
    @ViewBuilder private func relatedGoals(_ entry: API.Entry) -> some View {
        let goals = (source?.goals ?? []).filter { goal in
            guard entry.kind == "event", let category = goal.category else { return false }
            return entry.category == category || Show.root(entry.category, model.categories) == category
        }
        if !goals.isEmpty {
            PeekSection(title: "相关目标") {
                VStack(alignment: .leading, spacing: Theme.Space.medium) {
                    ForEach(goals) { goal in
                        Button {
                            model.openGoal(goal.id)
                        } label: {
                            relatedGoal(goal)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    /// 相关的一个目标：名称、这天推进了多少、进度条、一句话
    private func relatedGoal(_ goal: API.DayGoal) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            HStack(spacing: Theme.Space.small) {
                ToneDot(tone: goal.tone)
                Text(Show.spaced(goal.title)).foregroundStyle(Theme.Palette.label).lineLimit(1)
                Spacer(minLength: 0)
                if let delta = goal.delta {
                    Text(Show.spaced(Show.grouped(delta))).foregroundStyle(Theme.Palette.secondaryLabel)
                }
            }
            .font(Theme.Typeface.body)
            GoalBar(pct: goal.pct, tone: goal.tone)
            Text(Show.spaced(goal.headline)).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
        }
        .contentShape(Rectangle())
    }

    private func sources(_ entry: API.Entry) -> some View {
        PeekSection(title: "来源") {
            VStack(alignment: .leading, spacing: Theme.Space.medium) {
                ForEach(entry.sources, id: \.self) { source in
                    VStack(alignment: .leading, spacing: Theme.Space.tight) {
                        Text(highlighted(source)).font(Theme.Typeface.body).lineSpacing(Theme.Leading.body)
                            .padding(.leading, Theme.Space.medium)
                            .overlay(alignment: .leading) { Rectangle().fill(Theme.Palette.separator).frame(width: 1) }
                        Text(caption(source)).font(Theme.Typeface.footnote).foregroundStyle(
                            Theme.Palette.secondaryLabel)
                    }
                }
                HStack(spacing: Theme.Space.regular) {
                    if let note = entry.sources.first?.noteId {
                        Button("在笔记库查看") {
                            dismiss()
                            model.open("/library?note=\(note)")
                        }
                    }
                    Button("在对话里查看") {
                        dismiss()
                        model.chatOpen = true
                    }
                }
                .font(Theme.Typeface.bodyMedium).foregroundStyle(Theme.Palette.accent).buttonStyle(.plain)
                .frame(minHeight: Theme.Size.touch)
            }
        }
    }

    /// 原话，对应的那一段黄底
    private func highlighted(_ source: API.Source) -> AttributedString {
        var text = AttributedString(Show.spaced(source.text))
        text.foregroundColor = Theme.Palette.secondaryLabel
        let span = Show.spaced(source.span)
        if !span.isEmpty, let range = text.range(of: span) {
            text[range].backgroundColor = Theme.tag("yellow").tint
            text[range].foregroundColor = Theme.Palette.label
        }
        return text
    }

    /// 「10月15日 08:00 · 记下」
    private func caption(_ source: API.Source) -> String {
        let words = [
            "created": "记下", "updated": "补充", "duplicate": "再次提到", "completed": "完成", "confirmed": "确认",
            "deleted": "删除",
        ]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: source.createdAt) ?? Date()
        let parts = Calendar.current.dateComponents([.month, .day, .hour, .minute], from: date)
        return String(
            format: "%d月%d日 %02d:%02d · %@", parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0, parts.minute ?? 0,
            words[source.action] ?? source.action)
    }

    private func color(_ entry: API.Entry) -> Color {
        Theme.tag(Show.meta(entry.category, model.categories).color).solid
    }
}
