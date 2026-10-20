import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 记录详情（网页版 EntryPeek 手机那一档 1 比 1）：从底部滑出的半屏，标题是图标和名称，右上角关闭。
/// 拿不准的先问一句、能确认；所有字段原地修改（交给网页版服务器改）；最近 7 天；相关目标；来源原话（对应的那一段标黄）；删除
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
                if let entry {
                    VStack(alignment: .leading, spacing: Web.space6) {
                        if entry.pending { confirmCard(entry) }
                        PeekFields(entry: entry)
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
                        .font(Web.bodyMedium).foregroundStyle(Web.danger).buttonStyle(.plain)
                        .frame(minHeight: Web.touch)
                        .accessibilityIdentifier("detail.delete")
                    }
                    .padding(.horizontal, Web.space4)
                    .padding(.bottom, Web.space6)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Web.bg)
        .presentationDetents([.fraction(0.6), .large])
        .presentationCornerRadius(Web.radiusPanel)
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.light)
        .tint(Web.accent)
        .task { trend = try? await model.client.trend(of: entryId) }
        .task(id: "\(day ?? "")-\(model.dataVersion)") {
            if let day { otherDay = try? await model.client.day(day) }
        }
    }

    private var header: some View {
        HStack(spacing: Web.space2) {
            Text(Show.spaced(title)).font(Web.section.weight(.semibold)).foregroundStyle(Web.fg).lineLimit(2)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark").font(Web.section).foregroundStyle(Web.fgSecondary)
                    .frame(width: Web.touch, height: Web.touch).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("关闭"))
        }
        .padding(.leading, Web.space4)
        .padding([.trailing, .vertical], Web.space2)
        .frame(minHeight: Web.header)
    }

    /// 标题：类别的图标 + 名称（心情就是「心情」）
    private var title: String {
        guard let entry else { return "" }
        let emoji = Show.meta(entry.category, model.categories).emoji
        switch entry.data {
        case .event(let event): return "\(emoji) \(event.label)"
        case .todo(let todo): return "\(emoji) \(todo.content)"
        case .insight(let insight): return "\(emoji) \(insight.title)"
        case .mood: return "\(emoji) 心情"
        }
    }

    private func confirmCard(_ entry: API.Entry) -> some View {
        VStack(alignment: .leading, spacing: Web.space3) {
            Text(Show.spaced(entry.question ?? "我理解得对吗？")).font(Web.body).foregroundStyle(Web.fg)
            HStack(spacing: Web.space3) {
                Button {
                    model.confirm(entry.id)
                } label: {
                    Text("确认").font(Web.bodyMedium).foregroundStyle(Web.onAccent)
                        .padding(.horizontal, Web.space4)
                        .frame(minHeight: Web.touch)
                        .background(RoundedRectangle(cornerRadius: Web.radiusControl).fill(Web.accent))
                }
                .buttonStyle(.plain)
                Text("不对的话，直接改下面的内容，或者在对话里说").font(Web.caption).foregroundStyle(Web.fgTertiary)
            }
        }
        .padding(Web.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Web.radiusCard).fill(Web.bgSubtle))
    }

    /// 相关目标的完整进度（网页版「相关目标」）：圆点、目标、推进了多少、细进度条、进度说明
    @ViewBuilder private func relatedGoals(_ entry: API.Entry) -> some View {
        let goals = (source?.goals ?? []).filter { goal in
            guard entry.kind == "event", let category = goal.category else { return false }
            return entry.category == category || Show.root(entry.category, model.categories) == category
        }
        if !goals.isEmpty {
            PeekSection(title: "相关目标") {
                VStack(alignment: .leading, spacing: Web.space3) {
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
        VStack(alignment: .leading, spacing: Web.space1) {
            HStack(spacing: Web.space2) {
                ToneDot(tone: goal.tone)
                Text(Show.spaced(goal.title)).foregroundStyle(Web.fg).lineLimit(1)
                Spacer(minLength: 0)
                if let delta = goal.delta { Text(Show.spaced(delta)).foregroundStyle(Web.fgSecondary) }
            }
            .font(Web.body)
            GoalBar(pct: goal.pct, tone: goal.tone)
            Text(Show.spaced(goal.headline)).font(Web.caption).foregroundStyle(Web.fgTertiary)
        }
        .contentShape(Rectangle())
    }

    private func sources(_ entry: API.Entry) -> some View {
        PeekSection(title: "来源") {
            VStack(alignment: .leading, spacing: Web.space3) {
                ForEach(entry.sources, id: \.self) { source in
                    VStack(alignment: .leading, spacing: Web.space1) {
                        Text(highlighted(source)).font(Web.body).lineSpacing(Web.bodyLineSpacing)
                            .padding(.leading, Web.space3)
                            .overlay(alignment: .leading) { Rectangle().fill(Web.lineStrong).frame(width: 1) }
                        Text(caption(source)).font(Web.caption).foregroundStyle(Web.fgTertiary)
                    }
                }
                Button("在对话里查看") {
                    dismiss()
                    model.chatOpen = true
                }
                .font(Web.bodyMedium).foregroundStyle(Web.accent).buttonStyle(.plain)
                .frame(minHeight: Web.touch)
            }
        }
    }

    /// 原话，对应的那一段黄底
    private func highlighted(_ source: API.Source) -> AttributedString {
        var text = AttributedString(Show.spaced(source.text))
        text.foregroundColor = Web.fgSecondary
        let span = Show.spaced(source.span)
        if !span.isEmpty, let range = text.range(of: span) {
            text[range].backgroundColor = Web.tag("yellow").bg
            text[range].foregroundColor = Web.fg
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

    private func color(_ entry: API.Entry) -> Color { Web.tag(Show.meta(entry.category, model.categories).color).solid }
}
