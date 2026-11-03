import PourAPI
import PourDesign
import SwiftUI

/// 好日子的配方：一行一样（和儿子在一起 · 好的 9 天 · 差的 1 天）；最好的 10 天、最差的 10 天各有几天这样
struct RecipeCard: View {
    let recipe: API.MeRecipe

    var body: some View {
        AboutSection(
            title: "好日子的配方", meta: "最好的 \(recipe.size) 天 / 最差的 \(recipe.size) 天",
            info: "心情最好的 \(recipe.size) 天和最差的 \(recipe.size) 天里，各有几天是这样。差得多、前后两段时间都成立的才列。")
        VStack(spacing: 0) {
            ForEach(Array((recipe.good + recipe.bad).enumerated()), id: \.offset) { index, row in
                if index > 0 { Divider() }
                HStack(spacing: Theme.Space.small) {
                    Text(row.name).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                    Spacer()
                    Text("好的 \(row.good) 天").font(Theme.Typeface.footnoteSemibold).monospacedDigit()
                        .foregroundStyle(Theme.Palette.good)
                    Text("差的 \(row.bad) 天").font(Theme.Typeface.footnoteSemibold).monospacedDigit()
                        .foregroundStyle(Theme.Palette.warn)
                }
                .frame(minHeight: Theme.Size.touch)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, Theme.Space.inset)
        .themeCard(padding: 0)
        Text("只是同时出现，不一定和它有关。").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
    }
}

/// 你没注意到的变化：一张一张小卡，一句话 + 小曲线（两头写起点和终点）+ 怎么算的
struct ChangeCards: View {
    @Environment(AppModel.self) private var model
    let changes: [API.MeChange]

    var body: some View {
        AboutSection(title: "你没注意到的变化")
        ForEach(changes, id: \.key) { change in
            let target =
                change.domain.map { "/about/domain/\($0)" }
                ?? (change.person.map { "/about/person/\($0)" } ?? (change.color == "mood" ? "/about/mood" : nil))
            Button {
                if let target { model.open(target) }
            } label: {
                VStack(alignment: .leading, spacing: Theme.Space.small) {
                    Text(Show.spaced(change.text)).font(Theme.Typeface.bodySemibold).foregroundStyle(
                        Theme.Palette.label
                    )
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: Theme.Space.small) {
                        Text(change.from).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                        ChangeLine(points: change.points, color: Theme.tag(change.color).solid)
                            .frame(height: Theme.Size.curve / 2)
                        Text(change.to).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                    Text(Show.spaced(change.sub)).font(Theme.Typeface.footnote)
                        .foregroundStyle(Theme.Palette.secondaryLabel).multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .themeCard()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(target == nil)
            .accessibilityElement(children: .combine)
        }
    }
}

/// 小曲线：几个点连成一条线（没有坐标轴）
struct ChangeLine: View {
    let points: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let low = points.min() ?? 0
            let span = max((points.max() ?? 1) - low, 0.0001)
            Path { path in
                for (index, value) in points.enumerated() {
                    let x = geo.size.width * Double(index) / Double(max(points.count - 1, 1))
                    let y = geo.size.height * (1 - (value - low) / span)
                    if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}

/// 说的和做的：每个领域你说过几次（点开是哪几句）、这 30 天记到的（点了进领域）；能整块藏起来、能恢复
struct CareCard: View {
    @Environment(AppModel.self) private var model
    let care: API.MeCare
    let reload: () async -> Void
    @State private var open: String?

    var body: some View {
        if care.hidden {
            HStack {
                Text("说的和做的藏起来了").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                Spacer()
                LinkButton("恢复", identifier: "about.care.show") { hide(false) }
            }
        } else if !care.rows.isEmpty {
            HStack {
                AboutSection(
                    title: "说的和做的",
                    info: "你说在意的（目标、感悟），和这 30 天记到的时间、钱摆在一起。没记 ≠ 没做：这里只算你记过的。")
                LinkButton("不想看这块", identifier: "about.care.hide") { hide(true) }
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(care.rows.enumerated()), id: \.element.key) { index, row in
                    if index > 0 { Divider() }
                    rowView(row)
                }
            }
            .padding(.horizontal, Theme.Space.inset)
            .themeCard(padding: 0)
        }
    }

    private func rowView(_ row: API.CareRow) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            HStack(spacing: Theme.Space.small) {
                Circle().fill(Theme.tag(Show.meta(row.key, model.categories).color).solid)
                    .frame(width: Theme.Size.dot, height: Theme.Size.dot)
                Text(row.name).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
            }
            if !row.said.isEmpty {
                let counted = Self.counted(row)
                LinkButton(
                    "你说过 \(row.said.count) 次\(counted.isEmpty ? "" : "（\(counted)）") \(open == row.key ? "⌄" : "›")",
                    font: Theme.Typeface.subheadline, identifier: "about.care.said.\(row.key)"
                ) {
                    withAnimation(Theme.Motion.standard) { open = open == row.key ? nil : row.key }
                }
                if open == row.key { ForEach(Array(row.said.enumerated()), id: \.offset) { _, said in saidRow(said) } }
            }
            LinkButton(Self.line(row) + " ›", font: Theme.Typeface.footnote, identifier: "about.care.days.\(row.key)") {
                model.open("/about/domain/\(row.key)")
            }
        }
        .padding(.vertical, Theme.Space.small)
    }

    private func saidRow(_ said: API.CareRow.Said) -> some View {
        Button {
            model.open(said.kind == "goal" ? "/goals" : "/library?note=\(said.noteId ?? 0)")
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.small) {
                Text(said.kind == "goal" ? "目标" : "感悟").font(Theme.Typeface.caption)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
                Text("「\(said.text)」").font(Theme.Typeface.quote).foregroundStyle(Theme.Palette.label)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text(Show.monthDay(said.day)).font(Theme.Typeface.caption).foregroundStyle(Theme.Palette.secondaryLabel)
            }
            .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private func hide(_ hidden: Bool) {
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

    /// 「这 30 天记到 17 天，一共 13 小时 19 分 · 占醒着的时间 5% · 其中 5 小时 7 分在周末」
    static func line(_ row: API.CareRow) -> String {
        var parts = [Show.spaced(row.text)]
        if let share = row.share { parts.append("占醒着的时间 \(share < 1 ? "不到 1" : Show.fmtNum(share))%") }
        if let minutes = row.minutes, minutes > 0, let weekend = row.weekendMinutes, weekend / minutes >= 0.2 {
            parts.append("其中 \(Show.durationCn(Int(weekend)))在周末")
        }
        return parts.joined(separator: " · ")
    }

    /// 「目标 2 个、感悟 1 条」：一样都没有的那半边不写
    static func counted(_ row: API.CareRow) -> String {
        let goals = row.said.filter { $0.kind == "goal" }.count
        let insights = row.said.count - goals
        return [goals > 0 ? "目标 \(goals) 个" : "", insights > 0 ? "感悟 \(insights) 条" : ""].filter { !$0.isEmpty }
            .joined(separator: "、")
    }
}
