import PourAPI
import PourDesign
import SwiftUI

/// 换个角度看你：两列小卡，一个大字、一句结论、一张一看就懂的小图；钱点进一级页面「钱」
struct MeAngles: View {
    let angles: [API.MeAngle]
    let navigate: (String) -> Void

    private static let targets = [
        "mood": "/about/mood", "people": "/about/people", "money": "/money", "talk": "/about/talk",
    ]

    var body: some View {
        Grid(horizontalSpacing: Web.space3, verticalSpacing: Web.space3) {
            ForEach(Array(stride(from: 0, to: angles.count, by: 2)), id: \.self) { start in
                GridRow(alignment: .top) {
                    card(angles[start])
                    if start + 1 < angles.count { card(angles[start + 1]) } else { Color.clear }
                }
            }
        }
    }

    private func card(_ angle: API.MeAngle) -> some View {
        Button {
            navigate(Self.targets[angle.key] ?? "/about")
        } label: {
            VStack(alignment: .leading, spacing: Web.space1) {
                Text(angle.title).font(Web.caption).foregroundStyle(Web.fgTertiary)
                Text(angle.big).font(Web.title).foregroundStyle(Web.fg).minimumScaleFactor(0.6)
                MeNote(angle.sub)
                Spacer(minLength: 0)
                mini(angle).padding(.top, Web.space3).accessibilityHidden(true)
            }
            .padding(Web.space4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: Web.radiusPanel).fill(Web.bgSubtle))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("angle.\(angle.key)")
    }

    @ViewBuilder private func mini(_ angle: API.MeAngle) -> some View {
        if let pixels = angle.pixels {
            let days = pixels.flatMap(\.days)
            Grid(horizontalSpacing: Web.space1 / 2, verticalSpacing: Web.space1 / 2) {
                ForEach(Array(stride(from: 0, to: days.count, by: 7)), id: \.self) { start in
                    GridRow {
                        ForEach(days[start..<min(start + 7, days.count)], id: \.day) { day in pixel(day) }
                    }
                }
            }
        } else if let week = angle.week {
            let most = max(1, week.max() ?? 1)
            columns(week.map { $0 / most }) { index in index >= 5 ? Web.status("warn") : Web.lineStrong }
        } else if let clock = angle.clock {
            let most = Double(max(1, clock.hours.max() ?? 1))
            columns(clock.hours.map { Double($0) / most }, spacing: Web.space1 / 4) { _ in Web.lineStrong }
        } else if let bars = angle.bars {
            VStack(spacing: Web.space1) {
                ForEach(bars, id: \.name) { bar in
                    HStack(spacing: Web.space2) {
                        Text(bar.name).font(Web.caption).foregroundStyle(Web.fgSecondary).lineLimit(1)
                            .frame(width: Web.space12, alignment: .leading)
                        MeTrack(
                            share: bar.share,
                            color: bar.mood == "better" || bar.mood == "worse" ? MeStyle.tone(bar.mood) : Web.lineStrong
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder private func pixel(_ day: API.MeCalDay) -> some View {
        let shape = RoundedRectangle(cornerRadius: Web.radiusControl)
        switch day.state {
        case "on": shape.fill(MeStyle.moodShade(day.level ?? 3)).frame(height: Web.space2)
        case "off": shape.fill(Web.tag("gray").bg).frame(height: Web.space2)
        case "none": shape.strokeBorder(Web.line, lineWidth: 1).frame(height: Web.space2)
        default: Color.clear.frame(height: Web.space2)
        }
    }

    /// 一排小柱子（一周七天、一天 24 个钟点），按高低
    private func columns(_ shares: [Double], spacing: CGFloat = Web.space1 / 2, color: @escaping (Int) -> Color)
        -> some View
    {
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(Array(shares.enumerated()), id: \.offset) { index, share in
                UnevenRoundedRectangle(topLeadingRadius: Web.radiusControl, topTrailingRadius: Web.radiusControl)
                    .fill(color(index))
                    .frame(height: max(1, Web.space8 * share))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: Web.space8, alignment: .bottom)
    }
}

/// 说的和做的（docs/prd-about-me-2.md 6.3）：你说在意的，和你的时间、钱真正去了哪，摆在一起。只摆事实；
/// 两边都点得开看证据。最可能刺痛人的一块，所以有「不想看这块」：藏了只留一行「恢复」
struct MeCareView: View {
    @Environment(AppModel.self) private var model
    let care: API.MeCare
    let reload: () async -> Void

    var body: some View {
        if care.hidden {
            HStack(spacing: Web.space3) {
                MeNote("「说的和做的」已经藏起来了").frame(maxWidth: .infinity, alignment: .leading)
                hideButton("恢复", hidden: false)
            }
            .padding(.top, Web.space6)
        } else if !care.rows.isEmpty {
            ReviewSection(title: "说的和做的") {
                MeNote("你说在意的，和这 30 天记到的时间、钱摆在一起 · 两边都点得开看是哪几次、哪几天")
                VStack(alignment: .leading, spacing: Web.space4) { ForEach(care.rows, id: \.key) { row($0) } }
                    .padding(.top, Web.space3)
                HStack(spacing: Web.space3) {
                    MeNote("没记 ≠ 没做：这里只算你记过的").frame(maxWidth: .infinity, alignment: .leading)
                    hideButton("不想看这块", hidden: true)
                }
                .padding(.top, Web.space3)
            }
        }
    }

    private func row(_ row: API.CareRow) -> some View {
        let notes = [Self.shareNote(row), Self.weekendNote(row)].filter { !$0.isEmpty }
        let fact = row.text + (notes.isEmpty ? "" : " · \(notes.joined(separator: " · "))")
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Web.space2) {
                Circle().fill(Web.tag(Show.meta(row.key, model.categories).color).solid)
                    .frame(width: Web.space2, height: Web.space2)
                Text(row.name).font(Web.bodySemibold).foregroundStyle(Web.fg)
            }
            MeExpand {
                Text("你说过 \(row.said.count) 次（\(Self.counted(row))）").font(Web.body).foregroundStyle(Web.fg)
            } content: {
                MoneyList { ForEach(Array(row.said.enumerated()), id: \.offset) { _, said in self.said(said) } }
            }
            MeExpand {
                Text(Show.spaced(fact)).font(Web.caption).foregroundStyle(Web.fgSecondary)
            } content: {
                if row.days.isEmpty {
                    MeNote("这 30 天没有记到\(row.name)的话。没记 ≠ 没做")
                } else {
                    DayLinks(days: row.days)
                }
            }
        }
    }

    /// 你说过的那一次：目标点进「目标」，感悟点进那段原话
    private func said(_ said: API.CareRow.Said) -> some View {
        MoneyLinkRow(minHeight: Web.touch, chevron: false) {
            if said.kind == "goal" {
                model.page = .goals
            } else {
                model.open("/library?note=\(said.noteId ?? 0)")
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Web.space2) {
                Text(said.kind == "goal" ? "目标" : "感悟").font(Web.caption).foregroundStyle(Web.fgTertiary)
                Text(Show.spaced(said.text)).font(Web.body).foregroundStyle(Web.fg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(MeStyle.dayLabel(said.day)).font(Web.caption).foregroundStyle(Web.fgTertiary).fixedSize()
            }
        }
    }

    private func hideButton(_ title: String, hidden: Bool) -> some View {
        Button(title) {
            let client = model.client
            Task {
                do {
                    try await client.hideCare(hidden)
                    await reload()
                } catch {
                    model.toast(error.readable)
                }
            }
        }
        .buttonStyle(.plain).font(Web.caption).foregroundStyle(Web.fgTertiary)
        .frame(minHeight: Web.touch).contentShape(Rectangle())
    }

    /// 「目标 2 个、感悟 1 条」：一样都没有的那半边不写
    static func counted(_ row: API.CareRow) -> String {
        let goals = row.said.filter { $0.kind == "goal" }.count
        let insights = row.said.count - goals
        return [goals > 0 ? "目标 \(goals) 个" : "", insights > 0 ? "感悟 \(insights) 条" : ""].filter { !$0.isEmpty }
            .joined(separator: "、")
    }

    /// 占醒着的时间多少（shared shareNote）
    static func shareNote(_ row: API.CareRow) -> String {
        guard let share = row.share else { return "" }
        return "占醒着的时间 \(share < 1 ? "不到 1" : Show.fmtNum(share))%"
    }

    /// 「其中 5 小时在周末」；周末不到两成就不说（shared weekendNote）
    static func weekendNote(_ row: API.CareRow) -> String {
        guard let minutes = row.minutes, minutes > 0, let weekend = row.weekendMinutes else { return "" }
        return weekend / minutes >= 0.2 ? "其中 \(Show.minutes(Int(weekend)))在周末" : ""
    }
}
