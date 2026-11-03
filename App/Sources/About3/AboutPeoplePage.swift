import PourAPI
import PourDesign
import SwiftUI

/// 人（docs/3.0/06-交互细节.md 10.6）：一句话；人际星图（「你」在中间，越近越常在一起，越大天数越多；上面家人、右下工作、
/// 左下朋友和其他；绿的那些日子心情好一些、黄的差一些；两根手指放大，点一个人进去）；一人一行；以前常提到的在最后
struct AboutPeoplePage: View {
    @Environment(AppModel.self) private var model
    @State private var page: API.MePeoplePage?
    @State private var problem: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.cardGap) {
                if let page {
                    content(page)
                } else if let problem {
                    ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: Theme.Size.goalCard)
                }
            }
            .padding(.horizontal, Theme.Space.screen)
            .padding(.bottom, Theme.Space.xLarge)
        }
        .navigationTitle("人")
        .refreshable { await load() }
        .task(id: model.dataVersion) { await load() }
    }

    @ViewBuilder private func content(_ page: API.MePeoplePage) -> some View {
        Text(Show.spaced(page.sentence)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
            .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("people.sentence")
        if !page.people.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.medium) {
                PeopleStarMap(people: page.people) { model.open("/about/person/\($0)") }
                PourFlowLayout(spacing: Theme.Space.medium, lineSpacing: Theme.Space.small) {
                    Text("越近越常在一起 · 越大天数越多")
                    legend(Theme.Palette.good, "那些日子心情好一些")
                    legend(Theme.Palette.warn, "差一些")
                    legend(Theme.Palette.tertiaryLabel, "差不多或还太少")
                }
                .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            }
            .themeCard()
            Text("两根手指能放大；点一个人进去。").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            let now = page.people.filter { !$0.former }
            let former = page.people.filter(\.former)
            rows(now)
            if !former.isEmpty {
                AboutSection(title: "以前常提到")
                rows(former)
            }
        }
    }

    private func rows(_ people: [API.MePerson]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(people.enumerated()), id: \.element.name) { index, person in
                if index > 0 { Divider() }
                row(person)
            }
        }
        .padding(.horizontal, Theme.Space.inset)
        .themeCard(padding: 0)
    }

    private func row(_ person: API.MePerson) -> some View {
        Button {
            model.open("/about/person/\(person.name)")
        } label: {
            HStack(spacing: Theme.Space.medium) {
                Text(String(person.name.prefix(1))).font(Theme.Typeface.bodySemibold)
                    .foregroundStyle(Theme.Palette.label)
                    .frame(width: Theme.Size.hubIcon, height: Theme.Size.hubIcon)
                    .background(Theme.Palette.fill, in: Circle())
                VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                    HStack(spacing: Theme.Space.tight) {
                        Text(person.name).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                        Text(person.relation ?? AboutPersonPage.groupName(person.group)).font(Theme.Typeface.footnote)
                            .foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                    Text(person.former ? "以前常提到 · 最近一次 \(Show.monthDay(person.lastDay))" : Self.line(person))
                        .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Theme.Space.small)
                if person.mood == "better" || person.mood == "worse" {
                    Text(person.moodText).font(Theme.Typeface.caption)
                        .foregroundStyle(person.mood == "better" ? Theme.Palette.good : Theme.Palette.warnInk)
                        .padding(.horizontal, Theme.Space.small).padding(.vertical, Theme.Space.hairline)
                        .background(
                            person.mood == "better" ? Theme.Palette.goodFill : Theme.Palette.warnFill, in: Capsule()
                        )
                        .fixedSize()
                }
            }
            .padding(.vertical, Theme.Space.small)
            .frame(minHeight: Theme.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("people.row.\(person.name)")
    }

    /// 「31 天 · 多是接放学、上篮球课、看电影」
    static func line(_ person: API.MePerson) -> String {
        [person.days.isEmpty ? "" : "\(person.days.count) 天", person.doing].filter { !$0.isEmpty }.joined(
            separator: " · ")
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: Theme.Space.tight) {
            Circle().fill(color).frame(width: Theme.Size.dot, height: Theme.Size.dot)
            Text(text)
        }
    }

    private func load() async {
        do {
            page = try await model.client.mePeople()
            problem = nil
        } catch {
            problem = error.readable
        }
    }
}
