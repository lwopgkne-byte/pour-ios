import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 你的一年（docs/prd-about-me-2.md 第 11 节）：记了多少天、每天一格的热力图、说得最多的几件事、
/// 最常提到的人、一年十二个月的心情、第一句和最近一句话。记得还不够多时只有热力图和一句「再记 N 天」
struct AboutYearView: View {
    @Environment(AppModel.self) private var model
    @State var year: Int
    let navigate: (String) -> Void
    @State private var page: API.MeYear?
    @State private var problem: String?

    init(year: Int, navigate: @escaping (String) -> Void) {
        _year = State(initialValue: year)
        self.navigate = navigate
    }

    var body: some View {
        Group {
            if let page {
                content(page)
            } else if let problem {
                ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: Theme.Size.goalCard)
            }
        }
        .aboutPage()
        .navigationTitle("你的 \(year)")
        .task(id: "\(year)-\(model.dataVersion)") { await load() }
    }

    @ViewBuilder private func content(_ page: API.MeYear) -> some View {
        let notes = [page.streak.map { "连着记了 \($0.days) 天" }, bestMonth(page.bestMonth)].compactMap { $0 }
        VStack(alignment: .leading, spacing: Theme.Space.cardGap) {
            MeHead(title: "你的 \(page.year)") {
                navigate("/about")
            } sub: {
                Text(Show.spaced(page.sentence)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                if !notes.isEmpty { MeNote(notes.joined(separator: " · ")) }
            }
            AboutCardSection(title: "一年每天一格") { YearHeat(year: $year) }
            if !page.enough, let waiting = page.waiting {
                Text(Show.spaced("\(waiting)。这一页要记满小半年才看得出一年的样子，现在只有热力图。")).font(Theme.Typeface.body)
                    .foregroundStyle(Theme.Palette.label).padding(.top, Theme.Space.xLarge)
            }
            if page.enough { enough(page) }
            MeFoot()
        }
    }

    @ViewBuilder private func enough(_ page: API.MeYear) -> some View {
        tiles(page)
        people(page)
        months(page)
        emotions(page)
        firstLast(page)
    }

    @ViewBuilder private func tiles(_ page: API.MeYear) -> some View {
        if !page.tiles.isEmpty {
            AboutCardSection(title: "这一年你说得最多的", info: "按说到它的段数算，不看花了多少时间；点一块到那一页。") {
                PourFlowLayout(spacing: Theme.Space.tight, lineSpacing: Theme.Space.tight) {
                    ForEach(page.tiles, id: \.key) { tile in
                        Button {
                            navigate("/about/domain/\(tile.key)")
                        } label: {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("\(tile.share)%").font(Theme.Typeface.section).monospacedDigit()
                                Text(tile.name).font(Theme.Typeface.footnoteSemibold)
                            }
                            .foregroundStyle(Theme.tag(tile.color).solid)
                            .padding(.horizontal, Theme.Space.medium).padding(.vertical, Theme.Space.small)
                            .frame(
                                minWidth: (Theme.Space.section * 2) + (Theme.Size.touch + Theme.Space.tight),
                                minHeight: (Theme.Space.section * 2), alignment: .bottomLeading
                            )
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Corner.tile).fill(Theme.tag(tile.color).tint))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("\(tile.name)，说到的话里占 \(tile.share)%"))
                    }
                }
            }
        }
    }

    @ViewBuilder private func people(_ page: API.MeYear) -> some View {
        if let first = page.people.first {
            AboutCardSection(title: "这一年和你在一起最多的", info: "有几天说到他：一天说十次也算一天；点一行到「人」那一页。") {
                VStack(spacing: 0) {
                    ForEach(page.people, id: \.name) { person in
                        Button {
                            navigate("/about/people")
                        } label: {
                            MeBarRow(
                                name: Text(person.name), share: Double(person.days) / Double(max(1, first.days)),
                                color: Theme.Palette.separator, value: "\(person.days) 天"
                            )
                            .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    @ViewBuilder private func months(_ page: API.MeYear) -> some View {
        if !page.months.isEmpty {
            AboutCardSection(title: "一年的心情", info: "一个月一格，颜色越深心情越好；没说过心情的月份不上色。") {
                HStack(spacing: Theme.Space.tight) {
                    ForEach(page.months, id: \.month) { month in
                        VStack(spacing: Theme.Space.tight) {
                            RoundedRectangle(cornerRadius: Theme.Corner.tile)
                                .fill(month.mood.map { MeStyle.moodShade($0) } ?? Theme.Palette.fill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Corner.tile).strokeBorder(
                                        Theme.Palette.separator, lineWidth: 1)
                                )
                                .frame(height: Theme.Space.section)
                            Text(month.name).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            Text(
                                month.mood.map { "\(month.name) \(Show.between($0, words: Show.moodWords))" }
                                    ?? "\(month.name)没说过心情"))
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text("一年每个月心情的平均"))
            }
        }
    }

    @ViewBuilder private func emotions(_ page: API.MeYear) -> some View {
        if !page.emotions.isEmpty {
            AboutCardSection(title: "这一年你说出过的感受") {
                PourFlowLayout(spacing: Theme.Space.small, lineSpacing: Theme.Space.small) {
                    ForEach(page.emotions, id: \.word) { emotion in
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.tight) {
                            Text(emotion.word).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                            Text("\(emotion.times)").font(Theme.Typeface.footnote).foregroundStyle(
                                Theme.Palette.secondaryLabel)
                        }
                        .padding(.horizontal, Theme.Space.regular).frame(minHeight: Theme.Size.touch)
                        .background(Capsule().fill(Theme.Palette.fill))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    @ViewBuilder private func firstLast(_ page: API.MeYear) -> some View {
        let said = [page.first, page.last].compactMap { $0 }
        if !said.isEmpty {
            AboutCardSection(title: "这一年的第一句和最近一句") {
                MeQuotes(quotes: said.map { API.MeQuote(text: $0.text, day: $0.day, noteId: $0.noteId) })
            }
        }
    }

    private func bestMonth(_ month: API.MeYearMonth?) -> String? {
        guard let month, let mood = month.mood else { return nil }
        return "心情最好的是 \(month.name)（\(Show.between(mood, words: Show.moodWords))）"
    }

    private func load() async {
        do {
            page = try await model.client.meYear(year)
            problem = nil
        } catch {
            problem = error.readable
        }
    }
}

/// 一年每天一格（看板的年度热力图）：按记录量、心情、某个领域着色；一打开就滚到最近
private struct YearHeat: View {
    @Environment(AppModel.self) private var model
    @Binding var year: Int
    @State private var coloring = "count"
    @State private var page: API.YearHeatPage?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            HStack(spacing: Theme.Space.tight) {
                arrow("chevron.left", "前一年", disabled: false) { year -= 1 }
                Text("\(String(year))").font(Theme.Typeface.bodyMedium).foregroundStyle(Theme.Palette.label)
                    .monospacedDigit()
                arrow("chevron.right", "后一年", disabled: year >= Int(model.today.prefix(4)) ?? year) { year += 1 }
                Spacer()
                if let page {
                    Text("有 \(page.days.filter { $0.value > 0 }.count) 天").font(Theme.Typeface.footnote)
                        .foregroundStyle(
                            Theme.Palette.secondaryLabel)
                }
            }
            ScrollView(.horizontal) {
                HStack(spacing: Theme.Space.small) {
                    ForEach(options, id: \.key) { option in
                        FilterChip(option.label, selected: coloring == option.key) { coloring = option.key }
                    }
                }
                .padding(.vertical, (Theme.Size.touch - Theme.Size.capsule) / 2)
            }
            .scrollIndicators(.hidden)
            .padding(.vertical, -(Theme.Size.touch - Theme.Size.capsule) / 2)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("按什么着色"))
            if let page {
                ChartCard(spec: .heatmap(.init(title: "", unit: page.unit, days: page.days)))
                    .accessibilityLabel(Text("\(String(year)) 年\(page.label)的热力图"))
                if coloring == "mood" {
                    MeNote("颜色从浅到深：很差 → 很好，是那天几条心情的平均；没有心情的天不上色。")
                }
            } else {
                SkeletonBlock(height: (Theme.Space.section * 2) * 2)
            }
        }
        .task(id: "\(year)-\(coloring)-\(model.dataVersion)") {
            page = try? await model.client.yearHeat(year, coloring: coloring)
        }
    }

    private struct Option {
        let key: String
        let label: String
    }

    private var options: [Option] {
        [Option(key: "count", label: "记录量"), Option(key: "mood", label: "💭 心情")]
            + model.categories.filter { $0.parent == nil && ($0.count.map { $0 > 0 } ?? true) }.map {
                Option(key: "category:\($0.key)", label: "\($0.emoji) \($0.name)")
            }
    }

    private func arrow(_ icon: String, _ label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(Theme.Typeface.body).foregroundStyle(
                disabled ? Theme.Palette.separator : Theme.Palette.secondaryLabel
            )
            .frame(width: Theme.Size.touch, height: Theme.Size.touch).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(Text(label))
    }
}
