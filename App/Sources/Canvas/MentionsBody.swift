import PourAPI
import PourDesign
import SwiftUI

/// 说到的（产品主人 2026-10-21：画布跟着说的话长——人、事、物、话题）：这一天说到的人、东西、地方、话题，
/// 一类一行小胶囊，按说的先后；点一个就搜它（以前哪天也说到过）。两样以上才长出来
struct MentionsBody: View {
    @Environment(AppModel.self) private var model
    let entries: [API.Entry]

    var body: some View {
        let mentions = CanvasPlan.mentions(entries)
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            row("人", mentions.people)
            row("东西", mentions.things)
            row("地方", mentions.places)
            row("话题", mentions.topics, prefix: "#")
        }
    }

    @ViewBuilder private func row(_ title: String, _ items: [String], prefix: String = "") -> some View {
        if !items.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.medium) {
                Text(title).font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.secondaryLabel)
                    .frame(minWidth: Theme.Size.tile, alignment: .leading)
                PourFlowLayout(spacing: Theme.Space.small, lineSpacing: 0) {
                    ForEach(items, id: \.self) { item in chip(item, shown: prefix + item) }
                }
            }
            // 一类一组；组名就是前面那个字（不再给组起名，免得念两遍）
            .accessibilityElement(children: .contain)
        }
    }

    private func chip(_ item: String, shown: String) -> some View {
        Button {
            model.search = item
        } label: {
            Text(Show.spaced(shown)).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.label)
                .padding(.horizontal, Theme.Space.medium).frame(minHeight: Theme.Size.capsule)
                .background(Theme.Palette.fill, in: Capsule())
                .frame(minHeight: Theme.Size.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .accessibilityHint(Text("搜一搜以前也说到的"))
    }
}
