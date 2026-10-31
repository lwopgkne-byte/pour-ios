import PourAPI
import PourDesign
import SwiftUI

/// 心情那一页（docs/prd-about-me-2.md 5.4）：心情像素（每天一格）、一周七天、
/// 一天里什么时候、好时刻多在做什么、你说出过的感受、发现、变化。心情只用说法不用分数：图上只画高低、深浅
struct AboutMoodView: View {
    @Environment(AppModel.self) private var model
    let navigate: (String) -> Void
    @State private var page: API.MeMoodPage?
    @State private var problem: String?

    var body: some View {
        Group {
            if let page {
                content(page)
            } else if let problem {
                WebErrorState(problem) { Task { await load() } }
            } else {
                ReviewSkeleton()
            }
        }
        .moneyPage()
        .task(id: model.dataVersion) { await load() }
    }

    @ViewBuilder private func content(_ page: API.MeMoodPage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MeHead(title: "心情") {
                navigate("/about")
            } sub: {
                EmptyView()
            }
            pixels(page)
            if let week = page.week { MeWeek(week: week) }
            if let when = page.when {
                ReviewSection(title: "一天里什么时候") {
                    MeWhenMoodView(when: when)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(
                            Text("一天里什么时候的好时刻、不好的时刻：\(when.sentence.isEmpty ? "各段差不多" : when.sentence)"))
                    MeNote(
                        (when.sentence.isEmpty ? "" : "\(when.sentence) · ")
                            + "只算你说了几点的那 \(when.timed) 刻"
                            + (when.untimed > 0 ? "（还有 \(when.untimed) 刻没说几点，没算进来）" : ""))
                }
            }
            if let moments = page.moments {
                ReviewSection(title: "好时刻多在做什么") {
                    MeMomentBars(rows: moments.rows)
                    MeNote("\(moments.sentence) · 点一行看那几刻")
                }
            }
            if let feelings = page.feelings {
                ReviewSection(title: "你说出过的感受") {
                    MeFeelingsView(words: feelings.words)
                    MeNote(feelings.sentence)
                }
            }
            // 看板并进来：心情和精力的曲线、心情从哪来
            MoodEnergy()
            MoodFrom()
            if !page.findings.isEmpty { ReviewSection(title: "发现") { MeFindings(findings: page.findings) } }
            if !page.changes.isEmpty {
                ReviewSection(title: "变化") { MeChanges(changes: page.changes, navigate: navigate) }
            }
            MeFoot()
        }
    }

    private func pixels(_ page: API.MeMoodPage) -> some View {
        MePanel {
            if let word = page.word {
                MeNote("\(page.span)你的心情，平均是")
                Text(word).font(Web.title).foregroundStyle(Web.fg)
                MeNote("\(page.moodDays) 天说到了心情 · 每一格是一天，点一格看那天")
            } else {
                MeNote("\(page.span)还没说到心情。说一句「今天挺开心的」，这里就有一格。")
            }
            MeCalendar(
                weeks: page.pixels, kind: "mood", paint: { $0.state == "on" ? MeStyle.moodShade($0.level ?? 3) : nil },
                open: { navigate("/review/\($0)") }
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("\(page.span)每天的心情，颜色从浅到深是很差到很好，灰色是记了没说心情"))
            PourFlowLayout(spacing: Web.space4, lineSpacing: Web.space2) {
                HStack(spacing: Web.space1) {
                    Text("很差")
                    ForEach(1...5, id: \.self) { level in
                        Circle().fill(MeStyle.moodShade(Double(level))).frame(width: Web.space3, height: Web.space3)
                    }
                    Text("很好")
                }
                HStack(spacing: Web.space1) {
                    Circle().fill(Web.tag("gray").bg).frame(width: Web.space3, height: Web.space3)
                    Text("记了，没说心情")
                }
                if page.hasNone {
                    HStack(spacing: Web.space1) {
                        Circle().strokeBorder(Web.lineStrong, lineWidth: 1).frame(width: Web.space3, height: Web.space3)
                        Text("那天没记")
                    }
                }
            }
            .font(Web.caption).foregroundStyle(Web.fgTertiary)
            .padding(.top, Web.space3)
            .accessibilityElement(children: .combine)
        }
    }

    private func load() async {
        do {
            page = try await model.client.meMood()
            problem = nil
        } catch {
            problem = error.readable
        }
    }
}

/// 一周七天：每天一根柱子，只看高低；最低的那天用提醒色（前后两段时间都是它最低才说）
private struct MeWeek: View {
    let week: API.MeWeekMood

    var body: some View {
        ReviewSection(title: "一周七天") {
            HStack(alignment: .bottom, spacing: Web.space2) {
                ForEach(Array(week.bars.enumerated()), id: \.offset) { index, bar in
                    VStack(spacing: Web.space1) {
                        UnevenRoundedRectangle(
                            topLeadingRadius: Web.radiusCard, bottomLeadingRadius: Web.radiusControl,
                            bottomTrailingRadius: Web.radiusControl, topTrailingRadius: Web.radiusCard
                        )
                        .fill(week.low == index ? Web.status("warn") : Web.accent.opacity(0.64))
                        .frame(height: Web.space16 * 1.5 * CGFloat(bar.value.map { ($0 - 1) / 4 } ?? 0) + Web.space1)
                        Text(MeStyle.weekHead[index]).font(Web.caption).foregroundStyle(Web.fgTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(week.sentence.isEmpty ? "一周每天的平均心情" : "一周每天的平均心情：\(week.sentence)"))
            if !week.sentence.isEmpty {
                if let low = week.low, let high = week.high {
                    Text(
                        rich([
                            .bold("周\(MeStyle.weekHead[low])"), .init("最低，周\(MeStyle.weekHead[high])最高 · "),
                            .init(week.check, color: Web.fgTertiary),
                        ])
                    )
                    .font(Web.caption)
                } else {
                    Text(Show.spaced(week.sentence)).font(Web.caption).foregroundStyle(Web.fg)
                }
            }
        }
    }
}

/// 一天里什么时候：四段，好时刻绿、不好的时刻黄，上下两根；点一段看那几天
private struct MeWhenMoodView: View {
    let when: API.MeWhenMood
    @State private var open: String?

    var body: some View {
        let most = Double(max(1, when.parts.map { max($0.good, $0.bad) }.max() ?? 1))
        VStack(alignment: .leading, spacing: Web.space2) {
            HStack(alignment: .bottom, spacing: Web.space3) {
                ForEach(when.parts, id: \.name) { part in
                    Button {
                        withAnimation(Web.fast) { open = open == part.name ? nil : part.name }
                    } label: {
                        VStack(spacing: Web.space2) {
                            HStack(alignment: .bottom, spacing: Web.space1) {
                                bar(Double(part.good) / most, Web.status("good"))
                                bar(Double(part.bad) / most, Web.status("warn"))
                            }
                            .frame(height: Web.space16 + Web.space4, alignment: .bottom)
                            Text(part.name).font(Web.caption).foregroundStyle(Web.fgSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("\(part.name)：好时刻 \(part.good) 个，不好的时刻 \(part.bad) 个"))
                    .accessibilityValue(Text(open == part.name ? "展开了" : "收着"))
                }
            }
            if let name = open, let part = when.parts.first(where: { $0.name == name }) { DayLinks(days: part.days) }
        }
    }

    private func bar(_ share: Double, _ color: Color) -> some View {
        UnevenRoundedRectangle(topLeadingRadius: Web.radiusControl, topTrailingRadius: Web.radiusControl).fill(color)
            .frame(width: Web.space4, height: max(1, (Web.space16 + Web.space4) * share))
    }
}

/// 好时刻多在做什么：每个领域一行（一个领域色的点），横条长短是几个；点一行看那几刻
private struct MeMomentBars: View {
    @Environment(AppModel.self) private var model
    let rows: [API.MeMomentRow]

    var body: some View {
        let most = Double(max(1, rows.map(\.count).max() ?? 1))
        VStack(spacing: 0) {
            ForEach(rows, id: \.key) { row in
                MeExpand {
                    MeBarRow(
                        name: Text(rich([.init("● ", color: Web.tag(row.color).solid), .init(row.name)])),
                        share: Double(row.count) / most, color: Web.tag(row.color).solid, value: "\(row.count)")
                } content: {
                    MoneyList {
                        ForEach(Array(row.moments.enumerated()), id: \.offset) { _, moment in
                            MoneyLinkRow(minHeight: Web.touch, chevron: false) {
                                if let note = moment.noteId {
                                    model.open("/library?note=\(note)")
                                } else {
                                    model.goHome()
                                    model.show(moment.day)
                                }
                            } label: {
                                HStack(spacing: Web.space2) {
                                    Text(Show.spaced(moment.text)).font(Web.body).foregroundStyle(Web.fg)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(MeStyle.dayLabel(moment.day)).font(Web.caption).foregroundStyle(Web.fgTertiary)
                                        .fixedSize()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// 你说出过的感受：说得越多字越大（四档）；好的、不好的用绿、黄，说不清的灰
private struct MeFeelingsView: View {
    let words: [API.MeFeeling]

    private static let colors = ["good": "green", "bad": "yellow"]
    private static let fonts = [Web.caption, Web.body, Web.section, Web.title]

    var body: some View {
        PourFlowLayout(spacing: Web.space2, lineSpacing: Web.space2) {
            ForEach(words, id: \.word) { word in
                let tag = Web.tag(Self.colors[word.group] ?? "gray")
                HStack(alignment: .firstTextBaseline, spacing: Web.space1) {
                    Text(word.word).font(Self.fonts[min(4, max(1, word.size)) - 1])
                    // 数字和字一个颜色：淡一点（不透明度 0.7）在黄底上对比度不够（2026-10-31 审计查出来的）
                    Text("\(word.count)").font(Web.caption)
                }
                .foregroundStyle(tag.fg)
                .padding(.vertical, Web.space2).padding(.horizontal, Web.space3)
                .background(Capsule().fill(tag.bg))
                .accessibilityElement(children: .combine)
            }
        }
    }
}
