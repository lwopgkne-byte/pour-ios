import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 你的一年（docs/prd-about-me-2.md 第 11 节）：记了多少天、每天一格的热力图、说得最多的几件事、
/// 最常提到的人、一年十二个月的心情、第一句和最近一句话。记得还不够多时只有热力图和一句「再记 N 天」
struct AboutYearView: View {
    @Environment(AppModel.self) private var model
    /// 说得最多的那几行左边名字多宽（照原型 64，跟着字号变）
    @ScaledMetric(relativeTo: .body) private var nameWidth = Theme.Size.label
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
        .navigationTitle(Text(verbatim: "你的 \(year)"))
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
            YearHeat(year: $year)
            if !page.enough, let waiting = page.waiting {
                // 没记满小半年：先说还差几天，下面照现在的数给看看到时候是什么样（06 交互细节 10.6）
                VStack(alignment: .leading, spacing: Theme.Space.tight) {
                    Text(Show.spaced("\(waiting)。这一页要记满小半年才看得出一年的样子，现在只有热力图。"))
                        .font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("下面先看看到时候是什么样（数是照现在算的）").font(Theme.Typeface.footnote)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Space.regular)
                .background(
                    Theme.Palette.warnFill, in: RoundedRectangle(cornerRadius: Theme.Corner.card, style: .continuous)
                )
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("year.waiting")
            }
            enough(page)
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
            // 照原型：一行一个，名字、它颜色的横条（最多的那个画满）、占几成；点一行到那一页
            let most = Double(max(1, page.tiles.map(\.share).max() ?? 1))
            AboutCardSection(title: "这一年你说得最多的", info: "按说到它的段数算，不看花了多少时间；点一行到那一页。") {
                VStack(spacing: 0) {
                    ForEach(page.tiles, id: \.key) { tile in
                        Button {
                            navigate("/about/domain/\(tile.key)")
                        } label: {
                            HStack(spacing: Theme.Space.medium) {
                                Text(tile.name).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                                    .lineLimit(1).minimumScaleFactor(0.7)
                                    .frame(width: nameWidth, alignment: .leading)
                                MeTrack(share: Double(tile.share) / most, color: Theme.tag(tile.color).solid)
                                Text("\(tile.share)%").font(Theme.Typeface.footnote).monospacedDigit()
                                    .foregroundStyle(Theme.Palette.secondaryLabel)
                                    .frame(minWidth: Theme.Space.section + Theme.Space.tight, alignment: .trailing)
                            }
                            .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel(Text("\(tile.name)，说到的话里占 \(tile.share)%"))
                    }
                }
            }
        }
    }

    @ViewBuilder private func people(_ page: API.MeYear) -> some View {
        if !page.people.isEmpty {
            AboutCardSection(title: "这一年和你在一起最多的") {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(page.people, id: \.name) { person in
                        Button {
                            navigate("/about/people")
                        } label: {
                            HStack {
                                Text(person.name).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                                Spacer(minLength: Theme.Space.small)
                                Text("\(person.days) 天").font(Theme.Typeface.subheadline).monospacedDigit()
                                    .foregroundStyle(Theme.Palette.label)
                            }
                            .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                    }
                    MeNote("有几天说到这个人 · 一天说十次也算一天")
                }
            }
        }
    }

    @ViewBuilder private func months(_ page: API.MeYear) -> some View {
        if !page.months.isEmpty {
            let moods = Dictionary(
                page.months.compactMap { month in Int(month.month.suffix(2)).map { ($0, month) } },
                uniquingKeysWith: { first, _ in first })
            AboutCardSection(title: "一年的心情", info: "一个月一格，颜色越深心情越好；没说过心情的月份不上色。") {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Space.snug), count: 6),
                    spacing: Theme.Space.snug
                ) {
                    ForEach(1...12, id: \.self) { number in
                        monthCell(number, mood: moods[number]?.mood)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text("一年每个月心情的平均"))
            }
        }
    }

    /// 一个月一格（照原型）：这个月心情平均的那一档粉色，月份写在格子里；没说过心情的是浅墨
    private func monthCell(_ number: Int, mood: Double?) -> some View {
        let level = mood.map { Int($0.rounded()) }
        return Text("\(number)月").font(Theme.Typeface.caption)
            .foregroundStyle(level.map { Theme.Mood.ink($0) } ?? Theme.Palette.tertiaryLabel)
            .frame(maxWidth: .infinity).frame(height: Theme.Size.monthCell + Theme.Space.tight)
            .background(level.map { Theme.Mood.fill($0) } ?? Theme.Palette.fill, in: Theme.rounded(Theme.Corner.chip))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                Text(mood.map { "\(number)月 \(Show.between($0, words: Show.moodWords))" } ?? "\(number)月没说过心情"))
    }

    @ViewBuilder private func emotions(_ page: API.MeYear) -> some View {
        if !page.emotions.isEmpty {
            AboutCardSection(title: "这一年你说出过的感受") {
                // 照原型 .tag：小圆角的浅墨底、灰字「开心 15」
                PourFlowLayout(spacing: Theme.Space.snug, lineSpacing: Theme.Space.snug) {
                    ForEach(page.emotions, id: \.word) { emotion in
                        Text("\(emotion.word) \(emotion.times)").font(Theme.Typeface.caption).monospacedDigit()
                            .foregroundStyle(Theme.Palette.secondaryLabel)
                            .padding(.horizontal, Theme.Space.small).frame(minHeight: Theme.Size.badge)
                            .background(Theme.Palette.fillStrong, in: Theme.rounded(Theme.Corner.tail))
                    }
                }
            }
        }
    }

    @ViewBuilder private func firstLast(_ page: API.MeYear) -> some View {
        let said = [page.first, page.last].compactMap { $0 }
        if !said.isEmpty {
            AboutCardSection(title: "这一年的第一句和最近一句") {
                ForEach(said, id: \.noteId) { line in
                    Button {
                        model.open("/library?note=\(line.noteId)")
                    } label: {
                        VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                            Text(Show.spaced(line.text)).font(Theme.Typeface.quote).foregroundStyle(Theme.Palette.label)
                                .lineSpacing(Theme.Leading.body).fixedSize(horizontal: false, vertical: true)
                            Text(Show.monthDay(line.day)).font(Theme.Typeface.footnote).monospacedDigit()
                                .foregroundStyle(Theme.Palette.secondaryLabel)
                        }
                        .padding(.leading, Theme.Space.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(Theme.Palette.quoteRule).frame(width: Theme.Space.hairline)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                }
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
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            HStack(spacing: 0) {
                Text("一年每天一格").font(Theme.Typeface.section).foregroundStyle(Theme.Palette.label)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Theme.Space.small)
                arrow("chevron.left", "前一年", disabled: false) { year -= 1 }
                Text("\(String(year))").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                    .monospacedDigit()
                arrow("chevron.right", "后一年", disabled: year >= Int(model.today.prefix(4)) ?? year) { year += 1 }
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
            Group {
                if let page {
                    YearHeatGrid(year: year, days: page.days, color: tint, mood: coloring == "mood")
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("\(String(year)) 年\(page.label)的热力图"))
                        .accessibilityValue(Text("有 \(page.days.filter { $0.value > 0 }.count) 天"))
                } else {
                    SkeletonBlock(height: (Theme.Space.section * 2) * 2)
                }
            }
            .padding(Theme.Space.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.smallCard))
            .padding(.top, Theme.Space.tight)
            MeNote(foot)
        }
        .task(id: "\(year)-\(coloring)-\(model.dataVersion)") {
            page = try? await model.client.yearHeat(year, coloring: coloring)
        }
    }

    private struct Option {
        let key: String
        let label: String
    }

    /// 卡片下面那一句：这样上色是什么意思
    private var foot: String {
        switch coloring {
        case "count": return "颜色越深，那天说的话越多。"
        case "mood": return "颜色从浅到深：很差 → 很好，是那天几条心情的平均；没有心情的天不上色。"
        default:
            let key = String(coloring.dropFirst("category:".count))
            return "那天说到\(model.categories.first { $0.key == key }?.name ?? "它")的上色。"
        }
    }

    /// 着色：记录量是强调色，某个领域是它自己的颜色（心情另外按五档画）
    private var tint: Color {
        guard coloring.hasPrefix("category:") else { return Theme.Palette.accentFill }
        let key = String(coloring.dropFirst("category:".count))
        return Theme.tag(model.categories.first { $0.key == key }?.color ?? "blue").solid
    }

    private var options: [Option] {
        // 照原型：胶囊上只有字
        [Option(key: "count", label: "记录量"), Option(key: "mood", label: "心情")]
            + model.categories.filter { $0.parent == nil && ($0.count.map { $0 > 0 } ?? true) }.map {
                Option(key: "category:\($0.key)", label: $0.name)
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

/// 一年每天一格（照原型 .hm）：7 行（周一到周日）× 53 列，整年压在一张卡里；有的天上色（越多越深，心情按五档），
/// 没有的是浅墨；下面「1月 4月 7月 10月 12月」
private struct YearHeatGrid: View {
    let year: Int
    let days: [API.ChartDay]
    let color: Color
    let mood: Bool

    private static let gap: CGFloat = 1.5

    var body: some View {
        let values = Dictionary(days.map { ($0.day, $0.value) }, uniquingKeysWith: { first, _ in first })
        let most = max(1, values.values.max() ?? 1)
        VStack(spacing: Theme.Space.snug) {
            Canvas { context, size in
                let cell = (size.width - Self.gap * 52) / 53
                let first = "\(year)-01-01"
                let lead = PourDate.weekdayMon0(first)
                let count = PourDate.isValid("\(year)-02-29") ? 366 : 365
                for offset in 0..<count {
                    let day = PourDate.addDays(first, offset)
                    let slot = offset + lead
                    let rect = CGRect(
                        x: CGFloat(slot / 7) * (cell + Self.gap), y: CGFloat(slot % 7) * (cell + Self.gap),
                        width: cell, height: cell)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: cell * 0.25),
                        with: .color(fill(values[day], most: most)))
                }
            }
            .aspectRatio(53 / 7.4, contentMode: .fit)
            HStack {
                ForEach(["1月", "4月", "7月", "10月", "12月"], id: \.self) { month in
                    Text(month)
                    if month != "12月" { Spacer(minLength: 0) }
                }
            }
            .font(Theme.Typeface.tick).foregroundStyle(Theme.Palette.secondaryLabel)
        }
    }

    private func fill(_ value: Double?, most: Double) -> Color {
        guard let value, value > 0 else { return Theme.Palette.fill }
        if mood { return Theme.Mood.fill(Int(value.rounded())) }
        return color.opacity(0.25 + 0.75 * value / most)
    }
}
