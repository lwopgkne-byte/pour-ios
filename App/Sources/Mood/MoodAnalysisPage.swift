import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 心情分析（06 交互细节 10.1；以前「关于我 → 心情」的全部搬来，按卡片排好）：心情和精力、一天里什么时候、
/// 好时刻多在做什么、你说出过的感受、心情从哪来、变化。只说同时出现，不说因为
struct MoodAnalysisPage: View {
    @Environment(AppModel.self) private var model
    @State private var page: API.MeMoodPage?
    @State private var problem: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.cardGap) {
                if let page {
                    content(page)
                } else if let problem {
                    ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: Theme.Size.goalCard)
                }
            }
            .padding(.horizontal, Theme.Space.screen)
            .padding(.bottom, Theme.Space.xLarge)
        }
        .refreshable { await load() }
        .task(id: model.dataVersion) { await load() }
    }

    @ViewBuilder private func content(_ page: API.MeMoodPage) -> some View {
        Text(summary(page)).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
        MoodEnergyCard()
        if let when = page.when { MoodWhenCard(when: when) }
        if let moments = page.moments { MoodDomainsCard(moments: moments) }
        if let feelings = page.feelings { MoodFeelingsCard(feelings: feelings) }
        MoodSourcesCard()
        if !page.changes.isEmpty { MoodChangesCard(changes: page.changes) }
        Text("只是同时出现，不一定是因为它 · 全部在你的电脑上").font(Theme.Typeface.footnote)
            .foregroundStyle(Theme.Palette.secondaryLabel).frame(maxWidth: .infinity)
    }

    private func summary(_ page: API.MeMoodPage) -> String {
        guard let word = page.word else { return "\(page.span)还没说到心情。" }
        return "\(page.span)你的心情，平均是「\(word)」 · \(page.moodDays) 天说到了心情"
    }

    private func load() async {
        if page == nil, let saved: API.MeMoodPage = model.client.cached("/api/about/mood") { page = saved }
        do throws(APIError) {
            page = try await model.client.meMood()
            problem = nil
        } catch {
            if page == nil { problem = error.message }
        }
    }
}

/// 一天里什么时候：早上、中午、下午、晚上四段，每段两根柱子（好时刻绿、不好的时刻黄），下面写「好 5 · 不好 0」；
/// 只算说了几点的几刻
struct MoodWhenCard: View {
    let when: API.MeWhenMood

    var body: some View {
        let most = Double(max(1, when.parts.map { max($0.good, $0.bad) }.max() ?? 1))
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            MoodCardHeader("一天里什么时候")
            HStack(alignment: .bottom, spacing: Theme.Space.regular) {
                ForEach(when.parts, id: \.name) { part in
                    VStack(spacing: Theme.Space.tight) {
                        HStack(alignment: .bottom, spacing: Theme.Space.tight) {
                            bar(Double(part.good) / most, Theme.Palette.good)
                            bar(Double(part.bad) / most, Theme.Palette.warn)
                        }
                        .frame(height: Theme.Size.curve * 1.5, alignment: .bottom)
                        Text(part.name).font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.label)
                        // 上下两行：四段一样宽，放不下一行
                        VStack(spacing: 0) {
                            Text("好 \(part.good)")
                            Text("不好 \(part.bad)")
                        }
                        .font(Theme.Typeface.caption).monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("\(part.name)：好时刻 \(part.good) 个，不好的时刻 \(part.bad) 个"))
                }
            }
            Text(note).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
        }
        .themeCard()
    }

    private var note: String {
        (when.sentence.isEmpty ? "" : "\(when.sentence) · ") + "只算你说了几点的那 \(when.timed) 刻"
            + (when.untimed > 0 ? "（还有 \(when.untimed) 刻没说几点，没算进来）" : "")
    }

    private func bar(_ share: Double, _ color: Color) -> some View {
        UnevenRoundedRectangle(topLeadingRadius: Theme.Space.tight, topTrailingRadius: Theme.Space.tight).fill(color)
            .frame(width: Theme.Space.medium, height: max(Theme.Space.hairline, Theme.Size.curve * 1.5 * share))
    }
}

/// 好时刻多在做什么：一行一个领域写个数和一根条；点一行展开那几刻的原话（点了去笔记库）
struct MoodDomainsCard: View {
    @Environment(AppModel.self) private var model
    let moments: API.MeMoments
    @State private var open: String?

    var body: some View {
        let most = Double(max(1, moments.rows.map(\.count).max() ?? 1))
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            MoodCardHeader("好时刻多在做什么")
            ForEach(moments.rows, id: \.key) { row in
                Button {
                    withAnimation(Theme.Motion.standard) { open = open == row.key ? nil : row.key }
                } label: {
                    HStack(spacing: Theme.Space.small) {
                        Circle().fill(Theme.tag(row.color).solid).frame(width: Theme.Size.dot, height: Theme.Size.dot)
                        Text(row.name).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                            .frame(minWidth: Theme.Size.touch * 1.5, alignment: .leading)
                        GeometryReader { proxy in
                            Capsule().fill(Theme.tag(row.color).solid)
                                .frame(width: max(Theme.Size.bar, proxy.size.width * Double(row.count) / most))
                        }
                        .frame(height: Theme.Size.bar)
                        Text("\(row.count)").font(Theme.Typeface.subheadline).monospacedDigit()
                            .foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                    .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityValue(Text(open == row.key ? "展开了" : "收着"))
                if open == row.key { quotes(row.moments) }
            }
            Text("\(moments.sentence) · 点一行看那几刻").font(Theme.Typeface.footnote)
                .foregroundStyle(Theme.Palette.secondaryLabel)
        }
        .themeCard()
    }

    private func quotes(_ list: [API.MeMomentRow.Moment]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            ForEach(Array(list.enumerated()), id: \.offset) { _, moment in
                Button {
                    if let note = moment.noteId { model.open("/library?note=\(note)") }
                } label: {
                    VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                        Text(moment.text).font(Theme.Typeface.quote).foregroundStyle(Theme.Palette.label)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(Show.monthDay(moment.day))\(moment.noteId == nil ? "" : " · 看原话 ›")")
                            .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(moment.noteId == nil)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.leading, Theme.Space.regular)
        .padding(.bottom, Theme.Space.small)
    }
}

/// 你说出过的感受：胶囊，说得越多字越大；好的绿、不好的黄、说不清的灰
struct MoodFeelingsCard: View {
    let feelings: API.MeFeelings

    private static let fonts = [
        Theme.Typeface.footnote, Theme.Typeface.subheadline, Theme.Typeface.bodySemibold, Theme.Typeface.cardTitle,
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            MoodCardHeader("你说出过的感受")
            PourFlowLayout(spacing: Theme.Space.small, lineSpacing: Theme.Space.small) {
                ForEach(feelings.words, id: \.word) { word in
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Space.tight) {
                        Text(word.word).font(Self.fonts[min(4, max(1, word.size)) - 1])
                        Text("\(word.count)").font(Theme.Typeface.caption).monospacedDigit()
                    }
                    .foregroundStyle(ink(word.group))
                    .padding(.vertical, Theme.Space.snug).padding(.horizontal, Theme.Space.medium)
                    .background(fill(word.group), in: Capsule())
                    .accessibilityElement(children: .combine)
                }
            }
            Text(feelings.sentence).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
        }
        .themeCard()
    }

    private func ink(_ group: String) -> Color {
        switch group {
        case "good": Theme.Palette.good
        case "bad": Theme.Palette.warnInk
        default: Theme.Palette.secondaryLabel
        }
    }

    private func fill(_ group: String) -> Color {
        switch group {
        case "good": Theme.Palette.goodFill
        case "bad": Theme.Palette.warnFill
        default: Theme.Palette.fill
        }
    }
}
