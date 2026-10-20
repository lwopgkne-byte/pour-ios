import PourAPI
import PourDesign
import SwiftUI

/// 你的生活由什么组成：方块图（面积是说到它的段数），点一块进那一页；说得少的合成最下面一条「还在攒的」
struct MeComposition: View {
    let composition: API.MeComposition
    let navigate: (String) -> Void
    @State private var open = false

    var body: some View {
        let span = composition.days >= 30 ? "最近 30 天" : "这 \(composition.days) 天"
        let top = Array(composition.tiles.prefix(2))
        let rest = Array(composition.tiles.dropFirst(2))
        ReviewSection(title: "你的生活由什么组成") {
            MeNote("\(span)你说的话里，说到每样事的各占多少 · 点一块看那一页")
            if !composition.tiles.isEmpty {
                VStack(spacing: Web.space1) {
                    GrowRow(weights: top.map { Double(max(1, $0.share)) }) {
                        ForEach(top, id: \.key) { tile($0, big: true) }
                    }
                    .frame(height: Web.space16 * 2 + Web.space8 + Web.space2)
                    if !rest.isEmpty {
                        GrowRow(weights: rest.map { Double(max(1, $0.share)) }) {
                            ForEach(rest, id: \.key) { tile($0, big: false) }
                        }
                        .frame(height: Web.space16 + Web.space6 + Web.space1)
                    }
                }
            }
            if !composition.later.isEmpty { later }
            if !composition.sentence.isEmpty {
                Text(boldWords(composition.sentence, top.map(\.name))).font(Web.body).foregroundStyle(Web.fg)
            }
        }
        // 主页的第一块离标题近一点（网页版 .me > .review-section:first-of-type）
        .padding(.top, -Web.space4)
    }

    private func tile(_ tile: API.MeTile, big: Bool) -> some View {
        let tag = Web.tag(tile.color)
        return Button {
            navigate("/about/domain/\(tile.key)")
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(tile.share)%").font(big ? Web.title : Web.sectionBold).monospacedDigit()
                Text(tile.name).font(big ? Web.bodySemibold : Web.captionMedium)
            }
            .lineLimit(1).fixedSize()
            .foregroundStyle(tag.fg)
            .padding(.horizontal, big ? Web.space4 : Web.space3).padding(.vertical, big ? Web.space3 : Web.space2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .background(RoundedRectangle(cornerRadius: Web.radiusCard).fill(tag.bg))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(tile.name)，说到的话里占 \(tile.share)%"))
    }

    private var later: some View {
        let share = composition.later.reduce(0) { $0 + $1.share }
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(Web.fast) { open.toggle() }
            } label: {
                HStack(spacing: Web.space2) {
                    Text("还在攒的：\(composition.later.map(\.name).joined(separator: " · "))")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(share)%").foregroundStyle(Web.fgTertiary)
                }
                .font(Web.caption).foregroundStyle(Web.fgSecondary)
                .padding(.horizontal, Web.space3).frame(minHeight: Web.touch)
                .background(RoundedRectangle(cornerRadius: Web.radiusCard).fill(Web.bgSubtle))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(Text(open ? "展开了" : "收着"))
            if open {
                MoneyList {
                    ForEach(composition.later, id: \.key) { tile in
                        MoneyLinkRow(minHeight: Web.touch) {
                            navigate("/about/domain/\(tile.key)")
                        } label: {
                            HStack(spacing: Web.space2) {
                                Text(tile.name).font(Web.body).foregroundStyle(Web.fg).frame(
                                    maxWidth: .infinity, alignment: .leading)
                                Text("说到 \(tile.notes) 段，说到 8 段以后单独占一块").font(Web.caption).foregroundStyle(
                                    Web.fgTertiary)
                            }
                        }
                    }
                }
                .padding(.top, Web.space2)
            }
        }
        .padding(.top, Web.space1)
    }
}

/// 时间去向（看板并进来）：说了时长的事按类别占比；一句小字说清它和方块图不是一回事
struct TimeGone: View {
    @Environment(AppModel.self) private var model
    @State private var days = "30"
    @State private var items: [API.TimeItem]?

    private static let ranges = [(key: "7", label: "7 天"), (key: "30", label: "30 天"), (key: "90", label: "90 天")]

    var body: some View {
        Group {
            if items?.isEmpty != true {
                ReviewSection(title: "时间去向") {
                    MeNote("说了时长的事，时间各去了哪 · 这和上面的方块图不是一回事（那个是说到多少）")
                    WebSegmented("范围", options: Self.ranges, selected: days) { days = $0 }
                    if let items { content(items) } else { WebSkeleton(height: Web.space16) }
                }
            }
        }
        .task(id: "\(days)-\(model.dataVersion)") {
            if let fresh = try? await model.client.timeGone(days: Int(days) ?? 30) { items = fresh }
        }
    }

    private func content(_ items: [API.TimeItem]) -> some View {
        VStack(alignment: .leading, spacing: Web.space3) {
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    ForEach(items, id: \.category) { item in
                        Rectangle().fill(Web.tag(item.color).solid).frame(width: proxy.size.width * item.share)
                    }
                }
            }
            .frame(height: Web.space3)
            .clipShape(Capsule())
            .accessibilityHidden(true)
            VStack(spacing: 0) {
                ForEach(items, id: \.category) { item in
                    HStack(spacing: Web.space2) {
                        Text(item.emoji).accessibilityHidden(true)
                        Text(item.name).frame(maxWidth: .infinity, alignment: .leading)
                        Text(hours(item.minutes)).foregroundStyle(Web.fgSecondary).monospacedDigit()
                        Text("\(Int((item.share * 100).rounded()))%").foregroundStyle(Web.fgTertiary).monospacedDigit()
                            .frame(minWidth: Web.space8 + Web.space2, alignment: .trailing)
                    }
                    .font(Web.body).foregroundStyle(Web.fg)
                    .frame(minHeight: Web.space8 + Web.space1)
                    .accessibilityElement(children: .combine)
                }
            }
            MeNote("只统计说了时长的事，没提到的时间不算。")
        }
    }

    private func hours(_ minutes: Double) -> String {
        minutes < 60 ? "\(Int(minutes)) 分钟" : "\(Show.fmtNum(minutes / 60)) 小时"
    }
}

/// 好日子的配方：每样东西两组圆点，好日子 10 个里亮几个（绿）、差日子 10 个里亮几个（黄）；点一行看是哪几天
struct MeRecipeView: View {
    let recipe: API.MeRecipe

    var body: some View {
        VStack(alignment: .leading, spacing: Web.space3) {
            Text("心情最好的 \(recipe.size) 天，和最差的 \(recipe.size) 天，差在哪").font(Web.sectionSemibold)
                .foregroundStyle(Web.fg)
            HStack(spacing: Web.space4) {
                Spacer()
                sample(Web.status("good"), "好的 \(recipe.size) 天")
                sample(Web.status("warn"), "差的 \(recipe.size) 天")
            }
            .font(Web.caption).foregroundStyle(Web.fgTertiary)
            if !recipe.good.isEmpty { group("好日子通常有", recipe.good) }
            if !recipe.bad.isEmpty { group("差日子多半有", recipe.bad) }
            MeNote("\(recipe.size) 个点亮几个，就是那 \(recipe.size) 天里有几天这样。差得多、前后两段时间都成立的才列；只是同时出现，不一定和它有关。")
        }
    }

    private func sample(_ color: Color, _ text: String) -> some View {
        HStack(spacing: Web.space1) {
            Circle().fill(color).frame(width: Web.space2, height: Web.space2)
            Text(text)
        }
    }

    private func group(_ title: String, _ rows: [API.RecipeRow]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MeNote(title)
            ForEach(rows, id: \.name) { row in
                MeExpand(label: "\(row.name)：好日子 \(recipe.size) 天里 \(row.good) 天，差日子 \(recipe.size) 天里 \(row.bad) 天") {
                    HStack(spacing: Web.space4) {
                        Text(Show.spaced(row.name)).font(Web.body).foregroundStyle(Web.fg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        dots(row.good, Web.status("good"))
                        dots(row.bad, Web.status("warn"))
                    }
                    .overlay(alignment: .bottom) { Rectangle().fill(Web.line).frame(height: 1) }
                } content: {
                    DayLinks(days: row.days)
                }
            }
        }
    }

    /// 10 个点排两行
    private func dots(_ lit: Int, _ color: Color) -> some View {
        Grid(horizontalSpacing: Web.space1, verticalSpacing: Web.space1 / 2) {
            ForEach(0..<2, id: \.self) { row in
                GridRow {
                    ForEach(0..<5, id: \.self) { column in
                        let index = row * 5 + column
                        Circle().fill(index < lit ? color : Web.bgHover).frame(width: Web.space2, height: Web.space2)
                            .opacity(index < recipe.size ? 1 : 0)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}
