import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 一周里（06 交互细节 4.4）：七根竖条，高度是那个星期几的平均心情，顶上是表情；一句话「周三最低」（前后两段都是才说）
struct MoodWeekCard: View {
    @Environment(AppModel.self) private var model
    let week: API.MeWeekMood

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            MoodCardHeader("一周里", link: "心情分析 ›") { model.open("/mood/analysis") }
            MoodWeekBars(values: week.bars.map(\.value), low: week.low)
            Text(week.sentence).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
        }
        .themeCard()
    }
}

/// 好时刻：最近三个（宋体那一刻 +「10月26日 · 放松」），点一个打开那一条；「全部 15 个 ›」
struct MoodGoodCard: View {
    @Environment(AppModel.self) private var model
    let good: API.MoodPage.Good

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            MoodCardHeader("好时刻", link: "全部 \(good.total) 个 ›") { model.open("/mood/moments") }
            ForEach(good.recent) { moment in
                Button {
                    model.mood.detail = moment
                } label: {
                    MoodGoodRow(moment: moment).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .themeCard()
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
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            MoodCardHeader("变化")
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
        .themeCard()
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

/// 心情分析：什么时候、和谁、在做什么 ›
struct MoodAnalysisLink: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            model.open("/mood/analysis")
        } label: {
            ThemeListRow(
                "心情分析", subtitle: "什么时候、和谁、在做什么、心情从哪来", symbol: "chart.line.uptrend.xyaxis",
                color: Theme.Tile.pink)
        }
        .buttonStyle(PressScale())
        .themeCard(padding: 0)
        .accessibilityIdentifier("mood.analysis")
    }
}
