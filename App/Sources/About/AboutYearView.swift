import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 你的一年（网页版 AboutYearPage.tsx，docs/prd-about-me-2.md 第 11 节）：记了多少天、每天一格的热力图、说得最多的几件事、
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
                WebErrorState(problem) { Task { await load() } }
            } else {
                ReviewSkeleton()
            }
        }
        .moneyPage()
        .task(id: "\(year)-\(model.dataVersion)") { await load() }
    }

    @ViewBuilder private func content(_ page: API.MeYear) -> some View {
        let notes = [page.streak.map { "连着记了 \($0.days) 天" }, bestMonth(page.bestMonth)].compactMap { $0 }
        VStack(alignment: .leading, spacing: 0) {
            MeHead(title: "你的 \(page.year)") {
                navigate("/about")
            } sub: {
                Text(Show.spaced(page.sentence)).font(Web.body).foregroundStyle(Web.fg)
                if !notes.isEmpty { MeNote(notes.joined(separator: " · ")) }
            }
            ReviewSection(title: "一年每天一格") { YearHeat(year: $year) }
            if !page.enough, let waiting = page.waiting {
                Text(Show.spaced("\(waiting)。这一页要记满小半年才看得出一年的样子，现在只有热力图。")).font(Web.body)
                    .foregroundStyle(Web.fg).padding(.top, Web.space6)
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
            ReviewSection(title: "这一年你说得最多的") {
                PourFlowLayout(spacing: Web.space1, lineSpacing: Web.space1) {
                    ForEach(page.tiles, id: \.key) { tile in
                        Button {
                            navigate("/about/domain/\(tile.key)")
                        } label: {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("\(tile.share)%").font(Web.sectionBold).monospacedDigit()
                                Text(tile.name).font(Web.captionMedium)
                            }
                            .foregroundStyle(Web.tag(tile.color).fg)
                            .padding(.horizontal, Web.space3).padding(.vertical, Web.space2)
                            .frame(
                                minWidth: Web.space16 + Web.space12, minHeight: Web.space16, alignment: .bottomLeading
                            )
                            .background(RoundedRectangle(cornerRadius: Web.radiusCard).fill(Web.tag(tile.color).bg))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("\(tile.name)，说到的话里占 \(tile.share)%"))
                    }
                }
                MeNote("按说到它的段数算，不看花了多少时间 · 点一块到那一页")
            }
        }
    }

    @ViewBuilder private func people(_ page: API.MeYear) -> some View {
        if let first = page.people.first {
            ReviewSection(title: "这一年和你在一起最多的") {
                VStack(spacing: 0) {
                    ForEach(page.people, id: \.name) { person in
                        Button {
                            navigate("/about/people")
                        } label: {
                            MeBarRow(
                                name: Text(person.name), share: Double(person.days) / Double(max(1, first.days)),
                                color: Web.lineStrong, value: "\(person.days) 天"
                            )
                            .frame(minHeight: Web.touch).contentShape(Rectangle())
                        }
                        .buttonStyle(WebPressStyle(radius: 0))
                        .accessibilityElement(children: .combine)
                    }
                }
                MeNote("有几天说到他 · 一天说十次也算一天 · 点一行到「人」那一页")
            }
        }
    }

    @ViewBuilder private func months(_ page: API.MeYear) -> some View {
        if !page.months.isEmpty {
            ReviewSection(title: "一年的心情") {
                HStack(spacing: Web.space1) {
                    ForEach(page.months, id: \.month) { month in
                        VStack(spacing: Web.space1) {
                            RoundedRectangle(cornerRadius: Web.radiusControl)
                                .fill(month.mood.map { MeStyle.moodShade($0) } ?? Web.bgSubtle)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Web.radiusControl).strokeBorder(
                                        Web.line, lineWidth: 1)
                                )
                                .frame(height: Web.space8)
                            Text(month.name).font(Web.caption).foregroundStyle(Web.fgTertiary).lineLimit(1)
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
                MeNote("一个月一格，颜色越深心情越好；没说过心情的月份不上色")
            }
        }
    }

    @ViewBuilder private func emotions(_ page: API.MeYear) -> some View {
        if !page.emotions.isEmpty {
            ReviewSection(title: "这一年你说出过的感受") {
                PourFlowLayout(spacing: Web.space2, lineSpacing: Web.space2) {
                    ForEach(page.emotions, id: \.word) { emotion in
                        HStack(alignment: .firstTextBaseline, spacing: Web.space1) {
                            Text(emotion.word).font(Web.body).foregroundStyle(Web.fg)
                            Text("\(emotion.times)").font(Web.caption).foregroundStyle(Web.fgTertiary)
                        }
                        .padding(.horizontal, Web.space4).frame(minHeight: Web.touch)
                        .background(Capsule().fill(Web.bgSubtle))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    @ViewBuilder private func firstLast(_ page: API.MeYear) -> some View {
        let said = [page.first, page.last].compactMap { $0 }
        if !said.isEmpty {
            ReviewSection(title: "这一年的第一句和最近一句") {
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
        VStack(alignment: .leading, spacing: Web.space3) {
            HStack(spacing: Web.space1) {
                arrow("chevron.left", "前一年", disabled: false) { year -= 1 }
                Text("\(String(year))").font(Web.bodyMedium).foregroundStyle(Web.fg).monospacedDigit()
                arrow("chevron.right", "后一年", disabled: year >= Int(model.today.prefix(4)) ?? year) { year += 1 }
                Spacer()
                if let page {
                    Text("有 \(page.days.filter { $0.value > 0 }.count) 天").font(Web.caption).foregroundStyle(
                        Web.fgSecondary)
                }
            }
            ScrollView(.horizontal) {
                HStack(spacing: Web.space2) {
                    ForEach(options, id: \.key) { option in
                        WebChip(selected: coloring == option.key) {
                            coloring = option.key
                        } label: {
                            Text(option.label)
                        }
                    }
                }
                .padding(.vertical, (Web.touch - Web.control) / 2)
            }
            .scrollIndicators(.hidden)
            .padding(.vertical, -(Web.touch - Web.control) / 2)
            if let page {
                ChartCard(spec: .heatmap(.init(title: "", unit: page.unit, days: page.days)))
                    .accessibilityLabel(Text("\(String(year)) 年\(page.label)的热力图"))
                if coloring == "mood" {
                    MeNote("颜色从浅到深：很差 → 很好，是那天几条心情的平均；没有心情的天不上色。")
                }
            } else {
                WebSkeleton(height: Web.space16 * 2)
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
            Image(systemName: icon).font(Web.body).foregroundStyle(disabled ? Web.lineStrong : Web.fgSecondary)
                .frame(width: Web.touch, height: Web.touch).contentShape(Rectangle())
        }
        .buttonStyle(WebPressStyle(radius: Web.radiusControl))
        .disabled(disabled)
        .accessibilityLabel(Text(label))
    }
}
