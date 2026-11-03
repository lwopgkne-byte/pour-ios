import PourAPI
import PourDesign
import SwiftUI

/// 你的生活由什么组成：一行一个领域写百分比和条（不用方块图），点一行进那个领域；还在攒的一行；一句话
struct CompositionCard: View {
    @Environment(AppModel.self) private var model
    let composition: API.MeComposition

    var body: some View {
        AboutSection(
            title: "你的生活由什么组成", meta: "最近 \(composition.days) 天 · 点一行进去",
            info: "最近 \(composition.days) 天你说的话里，说到每样事的各占多少（按说到的段数算，不看花了多少时间）。")
        VStack(alignment: .leading, spacing: 0) {
            let most = composition.tiles.map(\.share).max() ?? 1
            ForEach(composition.tiles, id: \.key) { tile in
                DomainShareRow(name: tile.name, color: tile.color, share: tile.share, most: most) {
                    model.open("/about/domain/\(tile.key)")
                }
                .accessibilityIdentifier("about.domain.\(tile.key)")
            }
            if !composition.later.isEmpty {
                let rest = composition.later.reduce(0) { $0 + $1.share }
                Text("还在攒的：\(composition.later.map(\.name).joined(separator: " · "))（一共 \(rest)%）")
                    .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, Theme.Space.small)
            }
            if !composition.sentence.isEmpty {
                Text(Show.spaced(composition.sentence)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, Theme.Space.small)
                    .accessibilityIdentifier("about.composition.sentence")
            }
        }
        .themeCard()
    }
}

/// 时间去向：7 / 30 / 90 天，一条彩条 + 每行几小时、百分比；只算说了时长的事
struct TimeGoneCard: View {
    @Environment(AppModel.self) private var model
    @State private var days = 30
    @State private var items: [API.TimeItem] = []

    var body: some View {
        AboutSection(
            title: "时间去向",
            info: "说了时长的事，时间各去了哪（「跑了 40 分钟」「睡了 7 小时」）。和上面的不是一回事：上面是说到多少。")
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            Picker("范围", selection: $days) {
                Text("7 天").tag(7)
                Text("30 天").tag(30)
                Text("90 天").tag(90)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("about.time.range")
            if items.isEmpty {
                Text("这几天还没有说了时长的事。").font(Theme.Typeface.footnote)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
            } else {
                SegmentBar(items.map { .init(value: $0.minutes, color: Theme.tag($0.color).solid) })
                VStack(spacing: 0) {
                    ForEach(items, id: \.category) { item in row(item) }
                }
            }
        }
        .themeCard()
        Text("只统计说了时长的事，没提到的时间不算。").font(Theme.Typeface.footnote)
            .foregroundStyle(Theme.Palette.secondaryLabel)
            .task(id: "\(days)-\(model.dataVersion)") {
                if let fresh = try? await model.client.timeGone(days: days) { items = fresh }
            }
    }

    private func row(_ item: API.TimeItem) -> some View {
        HStack(spacing: Theme.Space.small) {
            Circle().fill(Theme.tag(item.color).solid).frame(width: Theme.Size.dot, height: Theme.Size.dot)
            Text(item.name).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
            Spacer()
            Text(Self.hours(item.minutes)).font(Theme.Typeface.footnote).monospacedDigit()
                .foregroundStyle(Theme.Palette.secondaryLabel)
            Text("\(Int((item.share * 100).rounded()))%").font(Theme.Typeface.footnoteSemibold).monospacedDigit()
                .foregroundStyle(Theme.Palette.label).frame(minWidth: Theme.Size.touch, alignment: .trailing)
        }
        .frame(minHeight: Theme.Size.dotRow + Theme.Space.small)
        .accessibilityElement(children: .combine)
    }

    /// 「206.4 小时」「30 分钟」
    static func hours(_ minutes: Double) -> String {
        minutes < 60 ? "\(Int(minutes.rounded())) 分钟" : "\(Show.fmtNum((minutes / 6).rounded() / 10)) 小时"
    }
}

/// 这周的新发现：横着滑的发现卡；四个反馈（说中了 · 早知道 · 没意思 · 不对）是一排小胶囊，点过的变实心
struct FindingsStrip: View {
    let findings: [API.FindingView]
    let vote: (String, String?) -> Void

    private static let votes = [("right", "说中了"), ("known", "早知道"), ("boring", "没意思"), ("wrong", "不对")]

    var body: some View {
        AboutSection(title: "这周的新发现", meta: "\(findings.count) 条")
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Theme.Space.cardGap) {
                ForEach(findings, id: \.key) { finding in card(finding) }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, 0)
    }

    private func card(_ finding: API.FindingView) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text("发现").font(Theme.Typeface.caption).foregroundStyle(Theme.Palette.secondaryLabel)
            Text(Show.spaced(finding.sentence)).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(finding.bars, id: \.label) { bar in
                HStack(spacing: Theme.Space.small) {
                    Text(bar.label).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                        .frame(minWidth: Theme.Size.label, alignment: .leading)
                    GeometryReader { geo in
                        Capsule().fill(Theme.Palette.fill).overlay(alignment: .leading) {
                            Capsule().fill(Self.tone(finding.tone, strong: bar.strong))
                                .frame(width: max(Theme.Size.bar, geo.size.width * bar.share))
                        }
                    }
                    .frame(height: Theme.Size.bar)
                    Text(bar.value).font(Theme.Typeface.footnote).monospacedDigit()
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                }
                .accessibilityElement(children: .combine)
            }
            Text(Show.spaced(finding.sub)).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Theme.Space.small) {
                ForEach(Self.votes, id: \.0) { key, title in
                    FilterChip(title, selected: finding.vote == key) {
                        vote(finding.key, finding.vote == key ? nil : key)
                    }
                    .accessibilityIdentifier("about.vote.\(key)")
                }
            }
        }
        .themeCard()
        .containerRelativeFrame(.horizontal) { width, _ in width * 0.86 }
    }

    /// 好一些绿、别的黄（不用红）；别的日子灰
    static func tone(_ tone: String?, strong: Bool) -> Color {
        guard strong else { return Theme.Palette.tertiaryLabel }
        return tone == "good" ? Theme.Palette.good : Theme.Palette.warn
    }
}

/// 换个角度看你：2×2 小卡（钱 · 人 · 心情 · 你说的话），点了进各自那一页
struct AngleGrid: View {
    @Environment(AppModel.self) private var model
    let angles: [API.MeAngle]

    private static let targets = [
        "mood": "/about/mood", "people": "/about/people", "money": "/money", "talk": "/about/talk",
    ]

    var body: some View {
        AboutSection(title: "换个角度看你")
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: Theme.Space.cardGap), GridItem(.flexible())],
            spacing: Theme.Space.cardGap
        ) {
            ForEach(angles, id: \.key) { angle in
                Button {
                    model.open(Self.targets[angle.key] ?? "/about")
                } label: {
                    VStack(alignment: .leading, spacing: Theme.Space.tight) {
                        Text(angle.title).font(Theme.Typeface.caption).foregroundStyle(Theme.Palette.secondaryLabel)
                        Text(angle.big).font(Theme.Typeface.metric).foregroundStyle(Theme.Palette.label)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Text(Show.spaced(angle.sub)).font(Theme.Typeface.footnote)
                            .foregroundStyle(Theme.Palette.secondaryLabel).multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.angleCard, alignment: .topLeading)
                    .themeCard()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("about.angle.\(angle.key)")
            }
        }
    }
}
