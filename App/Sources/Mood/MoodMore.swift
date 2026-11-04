import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 一周里（06 交互细节 4.4）：七根竖条，高度是那个星期几的平均心情，顶上是表情；一句话「周三最低」（前后两段都是才说）
struct MoodWeekCard: View {
    @Environment(AppModel.self) private var model
    let week: API.MeWeekMood

    var body: some View {
        PageSection(title: "这周", meta: week.sentence) {
            MoodWeekBars(values: week.bars.map(\.value), low: week.low)
        }
    }
}

/// 好时刻：最近三个（宋体那一刻 +「10月26日 · 放松」），点一个打开那一条；「全部 15 个 ›」
struct MoodGoodCard: View {
    @Environment(AppModel.self) private var model
    let good: API.MoodPage.Good

    var body: some View {
        PageSection(
            title: "好时刻", link: "全部 \(good.total) 个 ›", open: { model.open("/mood/moments") }, content: { rows })
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            ForEach(good.recent) { moment in
                Button {
                    model.mood.detail = moment
                } label: {
                    MoodGoodRow(moment: moment).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 一个好时刻：小表情 + 宋体那一刻；下面「10月26日 · 挺好 · 放松」
struct MoodGoodRow: View {
    let moment: API.MoodMoment

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.small) {
            MoodBadge(level: moment.level, size: Theme.Size.badge)
                .alignmentGuide(.firstTextBaseline) { $0.height * 0.75 }
            VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                Text(moment.moment ?? moment.word).font(Theme.Typeface.quote).foregroundStyle(Theme.Palette.label)
                    .fixedSize(horizontal: false, vertical: true)
                Text(([Show.monthDay(moment.day), moment.word] + moment.emotions).joined(separator: " · "))
                    .font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Theme.Space.tight)
        .accessibilityElement(children: .combine)
    }
}

/// 和心情有关的发现：和「关于我」同一种卡片，四个反馈点了变实心、再点撤销；点开是那几天，再点进那天
struct MoodFindingsCard: View {
    @Environment(AppModel.self) private var model
    let findings: [API.FindingView]
    let reload: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            MoodCardHeader("发现")
            ForEach(findings, id: \.key) { finding in
                FindingCardView(
                    finding: finding, mask: { $0 },
                    openDay: { day in
                        model.goHome()
                        model.show(day)
                    },
                    vote: { vote(finding.key, $0) })
            }
        }
        .themeCard()
    }

    private func vote(_ key: String, _ vote: String?) {
        let client = model.client
        Task {
            do throws(APIError) {
                try await client.vote(about: key, vote)
                await reload()
            } catch {
                model.toast(error.message)
            }
        }
    }
}

/// 变化（心情页最下面）：一句话、从哪到哪、依据
struct MoodChangesCard: View {
    let changes: [API.MeChange]

    var body: some View {
        PageSection(title: "变化") {
            VStack(alignment: .leading, spacing: Theme.Space.small) {
                ForEach(changes, id: \.key) { change in
                    VStack(alignment: .leading, spacing: Theme.Space.tight) {
                        Text(change.text).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                        MoodSpark(points: change.points, from: change.from, to: change.to)
                        Text(change.sub).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                    .padding(.vertical, Theme.Space.tight)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

/// 小曲线：两头写起点和终点
struct MoodSpark: View {
    let points: [Double]
    let from: String
    let to: String

    var body: some View {
        HStack(spacing: Theme.Space.small) {
            Text(from).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            Canvas { context, size in
                guard points.count > 1, let low = points.min(), let high = points.max() else { return }
                let span = max(0.0001, high - low)
                var path = Path()
                for (index, value) in points.enumerated() {
                    let point = CGPoint(
                        x: CGFloat(index) / CGFloat(points.count - 1) * size.width,
                        y: size.height - CGFloat((value - low) / span) * size.height)
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                let style = StrokeStyle(lineWidth: 2, lineJoin: .round)
                context.stroke(path, with: .color(Theme.Mood.fill(5)), style: style)
            }
            .frame(height: Theme.Size.dotRow)
            .accessibilityHidden(true)
            Text(to).font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.label)
        }
    }
}

/// 心情分析（照原型）：一张卡，「心情分析 ›」下面几个粉色小胶囊说里面有什么；点哪里都进心情分析
struct MoodAnalysisLink: View {
    @Environment(AppModel.self) private var model
    static let parts = ["一天里什么时候", "好时刻多在做什么", "你说出过的感受", "心情和精力", "心情从哪来"]

    var body: some View {
        Button {
            model.open("/mood/analysis")
        } label: {
            VStack(alignment: .leading, spacing: Theme.Space.small + Theme.Space.hairline) {
                HStack {
                    Text("心情分析").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                    Spacer()
                    Image(systemName: "chevron.right").font(Theme.Typeface.footnoteSemibold)
                        .foregroundStyle(Theme.Palette.tertiaryLabel)
                }
                PourFlowLayout(spacing: Theme.Space.snug, lineSpacing: Theme.Space.snug) {
                    ForEach(Self.parts, id: \.self) { part in
                        Text(part).font(Theme.Typeface.caption).foregroundStyle(Theme.Mood.ink(2))
                            .padding(.horizontal, Theme.Space.small).frame(minHeight: Theme.Size.badge)
                            .background(Theme.Mood.fill(1).opacity(0.6), in: Theme.rounded(Theme.Corner.tail))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .themeCard(radius: Theme.Corner.smallCard)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .themeCard(padding: 0)
        .accessibilityIdentifier("mood.analysis")
    }
}
